import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/features/auth/domain/entities/user.dart';
import 'package:mobile_app/features/auth/data/datasources/auth_local_data_source.dart';
import '../../domain/usecases/get_captcha.dart';
import '../../domain/usecases/request_otp.dart';
import '../../domain/usecases/verify_otp.dart';
import '../../domain/usecases/get_profile.dart';
import '../../domain/usecases/update_profile.dart';
import '../../domain/usecases/accept_terms.dart';
import '../../domain/usecases/check_terms_accepted.dart';
import '../../domain/usecases/logout.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final GetCaptcha getCaptchaUseCase;
  final RequestOtp requestOtpUseCase;
  final VerifyOtp verifyOtpUseCase;
  final GetProfile getProfileUseCase;
  final UpdateProfile updateProfileUseCase;
  final AcceptTerms acceptTermsUseCase;
  final CheckTermsAccepted checkTermsAcceptedUseCase;
  final Logout logoutUseCase;
  final AuthLocalDataSource localDataSource;

  AuthBloc({
    required this.getCaptchaUseCase,
    required this.requestOtpUseCase,
    required this.verifyOtpUseCase,
    required this.getProfileUseCase,
    required this.updateProfileUseCase,
    required this.acceptTermsUseCase,
    required this.checkTermsAcceptedUseCase,
    required this.logoutUseCase,
    required this.localDataSource,
  }) : super(AuthInitialState()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<LoadCaptchaEvent>(_onLoadCaptcha);
    on<RequestOtpEvent>(_onRequestOtp);
    on<VerifyOtpEvent>(_onVerifyOtp);
    on<AcceptTermsEvent>(_onAcceptTerms);
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<LogoutEvent>(_onLogout);
  }

  Future<void> _onCheckAuthStatus(CheckAuthStatusEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    
    // Check if terms accepted
    final termsRes = await checkTermsAcceptedUseCase(NoParams());
    final bool termsAccepted = termsRes.fold((_) => false, (accepted) => accepted);

    // Read cached token and user profile
    final token = await localDataSource.getCachedToken();
    final cachedUser = await localDataSource.getCachedUser();

    if (token != null && token.isNotEmpty && cachedUser != null) {
      if (!termsAccepted) {
        emit(TermsPendingState(mobileNumber: cachedUser.mobileNumber, token: token, refreshToken: ''));
      } else if (_isProfileIncomplete(cachedUser)) {
        emit(ProfilePendingState(mobileNumber: cachedUser.mobileNumber, token: token, refreshToken: ''));
      } else {
        emit(AuthenticatedState(user: cachedUser, token: token));
      }

      // Verify/refresh user profile from server in the background
      final profileRes = await getProfileUseCase(NoParams());
      await profileRes.fold(
        (failure) async {
          // Only log out on actual authorization failures (e.g. 401 Unauthorized / Token Expired)
          if (failure is ServerFailure &&
              (failure.errorCode == 'UNAUTHORIZED' ||
               failure.errorCode == 'INVALID_TOKEN' ||
               failure.errorCode == 'SESSION_EXPIRED')) {
            await logoutUseCase(NoParams());
            emit(UnauthenticatedState());
          }
        },
        (user) async {
          // Update state with fresh user profile
          if (!termsAccepted) {
            emit(TermsPendingState(mobileNumber: user.mobileNumber, token: token, refreshToken: ''));
          } else if (_isProfileIncomplete(user)) {
            emit(ProfilePendingState(mobileNumber: user.mobileNumber, token: token, refreshToken: ''));
          } else {
            emit(AuthenticatedState(user: user, token: token));
          }
        },
      );
    } else {
      // If token is missing, they are definitely unauthenticated
      if (token == null || token.isEmpty) {
        await logoutUseCase(NoParams());
        emit(UnauthenticatedState());
        return;
      }

      // If token exists but cached user is missing, fetch from server
      final profileRes = await getProfileUseCase(NoParams());
      await profileRes.fold(
        (failure) async {
          await logoutUseCase(NoParams());
          emit(UnauthenticatedState());
        },
        (user) async {
          if (!termsAccepted) {
            emit(TermsPendingState(mobileNumber: user.mobileNumber, token: token, refreshToken: ''));
          } else if (_isProfileIncomplete(user)) {
            emit(ProfilePendingState(mobileNumber: user.mobileNumber, token: token, refreshToken: ''));
          } else {
            emit(AuthenticatedState(user: user, token: token));
          }
        },
      );
    }
  }

  Future<void> _onLoadCaptcha(LoadCaptchaEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    final result = await getCaptchaUseCase(NoParams());
    result.fold(
      (failure) => emit(AuthErrorState(message: failure.message)),
      (captcha) => emit(CaptchaLoadedState(captchaId: captcha.$1, imageBase64: captcha.$2)),
    );
  }

  Future<void> _onRequestOtp(RequestOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    final result = await requestOtpUseCase(
      RequestOtpParams(
        mobileNumber: event.mobileNumber,
        captchaId: event.captchaId,
        captchaAnswer: event.captchaAnswer,
      ),
    );
    result.fold(
      (failure) => emit(AuthErrorState(message: failure.message, errorCode: (failure is ServerFailure) ? failure.errorCode : null)),
      (success) => emit(OtpSentState(mobileNumber: event.mobileNumber)),
    );
  }

  Future<void> _onVerifyOtp(VerifyOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    final result = await verifyOtpUseCase(
      VerifyOtpParams(
        mobileNumber: event.mobileNumber,
        otpCode: event.otpCode,
      ),
    );

    await result.fold(
      (failure) async => emit(AuthErrorState(message: failure.message, errorCode: (failure is ServerFailure) ? failure.errorCode : null)),
      (authData) async {
        final token = authData.$1;
        final refreshToken = authData.$2;
        final userStatus = authData.$3;

        // Check if terms are accepted locally
        final termsRes = await checkTermsAcceptedUseCase(NoParams());
        final bool termsAccepted = termsRes.fold((_) => false, (accepted) => accepted);

        if (!termsAccepted) {
          emit(TermsPendingState(mobileNumber: event.mobileNumber, token: token, refreshToken: refreshToken));
        } else {
          // Fetch complete profile to check if it's incomplete
          final profileRes = await getProfileUseCase(NoParams());
          await profileRes.fold(
            (failure) async => emit(AuthErrorState(message: failure.message)),
            (user) async {
              if (userStatus == 'NEW_USER' || userStatus == 'PROFILE_PENDING' || _isProfileIncomplete(user)) {
                emit(ProfilePendingState(mobileNumber: event.mobileNumber, token: token, refreshToken: refreshToken));
              } else {
                emit(AuthenticatedState(user: user, token: token));
              }
            },
          );
        }
      },
    );
  }

  Future<void> _onAcceptTerms(AcceptTermsEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    final result = await acceptTermsUseCase(NoParams());
    
    await result.fold(
      (failure) async => emit(AuthErrorState(message: failure.message)),
      (success) async {
        // Fetch user profile to check profile completion status
        final profileRes = await getProfileUseCase(NoParams());
        profileRes.fold(
          (failure) => emit(AuthErrorState(message: failure.message)),
          (user) {
            if (_isProfileIncomplete(user)) {
              emit(ProfilePendingState(mobileNumber: user.mobileNumber, token: event.token, refreshToken: event.refreshToken));
            } else {
              emit(AuthenticatedState(user: user, token: event.token));
            }
          },
        );
      },
    );
  }

  Future<void> _onUpdateProfile(UpdateProfileEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    final result = await updateProfileUseCase(
      UpdateProfileParams(
        username: event.username,
        interests: event.interests,
        educationalField: event.educationalField,
        educationalLevel: event.educationalLevel,
        profilePicture: event.profilePicture,
      ),
    );

    await result.fold(
      (failure) async => emit(AuthErrorState(message: failure.message)),
      (user) async {
        // Preserve the existing cached JWT token — do NOT wipe it
        final cachedToken = await localDataSource.getCachedToken() ?? '';
        emit(AuthenticatedState(user: user, token: cachedToken));
      },
    );
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    await logoutUseCase(NoParams());
    emit(UnauthenticatedState());
  }

  bool _isProfileIncomplete(User user) {
    return user.username.startsWith('User_') ||
           user.interests == null || user.interests!.isEmpty ||
           user.educationalField == null || user.educationalField!.isEmpty ||
           user.educationalLevel == null || user.educationalLevel!.isEmpty;
  }
}
