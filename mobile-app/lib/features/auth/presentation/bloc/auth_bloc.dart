import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/core/error/failures.dart';
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

  AuthBloc({
    required this.getCaptchaUseCase,
    required this.requestOtpUseCase,
    required this.verifyOtpUseCase,
    required this.getProfileUseCase,
    required this.updateProfileUseCase,
    required this.acceptTermsUseCase,
    required this.checkTermsAcceptedUseCase,
    required this.logoutUseCase,
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

    // Fetch profile (which verifies if token exists and is valid)
    final profileRes = await getProfileUseCase(NoParams());
    
    await profileRes.fold(
      (failure) async {
        // Clear cached credentials on auth error/invalid token
        await logoutUseCase(NoParams());
        emit(UnauthenticatedState());
      },
      (user) async {
        if (!termsAccepted) {
          emit(TermsPendingState(mobileNumber: user.mobileNumber, token: '', refreshToken: ''));
        } else if (user.username.startsWith('User_')) {
          emit(ProfilePendingState(mobileNumber: user.mobileNumber, token: '', refreshToken: ''));
        } else {
          emit(AuthenticatedState(user: user, token: ''));
        }
      },
    );
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
        } else if (userStatus == 'NEW_USER' || userStatus == 'PROFILE_PENDING') {
          emit(ProfilePendingState(mobileNumber: event.mobileNumber, token: token, refreshToken: refreshToken));
        } else {
          // Fetch complete profile and authenticate
          final profileRes = await getProfileUseCase(NoParams());
          profileRes.fold(
            (failure) => emit(AuthErrorState(message: failure.message)),
            (user) => emit(AuthenticatedState(user: user, token: token)),
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
            if (user.username.startsWith('User_')) {
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
      ),
    );

    result.fold(
      (failure) => emit(AuthErrorState(message: failure.message)),
      (user) => emit(AuthenticatedState(user: user, token: '')),
    );
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    await logoutUseCase(NoParams());
    emit(UnauthenticatedState());
  }
}
