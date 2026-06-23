import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/database_helper.dart';
import 'core/event_bus/event_bus.dart';
import 'core/network/dio_client.dart';
import 'core/services/storage_service.dart';
import 'core/services/payment_provider.dart';
import 'core/services/backup_service.dart';
import 'features/auth/data/datasources/auth_local_data_source.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/accept_terms.dart';
import 'features/auth/domain/usecases/check_terms_accepted.dart';
import 'features/auth/domain/usecases/get_captcha.dart';
import 'features/auth/domain/usecases/get_profile.dart';
import 'features/auth/domain/usecases/logout.dart';
import 'features/auth/domain/usecases/request_otp.dart';
import 'features/auth/domain/usecases/update_profile.dart';
import 'features/auth/domain/usecases/verify_otp.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

import 'features/courses/data/datasources/courses_local_data_source.dart';
import 'features/courses/data/datasources/courses_remote_data_source.dart';
import 'features/courses/data/repositories/courses_repository_impl.dart';
import 'features/courses/domain/repositories/courses_repository.dart';
import 'features/courses/domain/usecases/download_course.dart';
import 'features/courses/domain/usecases/get_courses.dart';
import 'features/courses/presentation/bloc/courses_bloc.dart';
import 'features/flashcards/data/repositories/flashcard_repository_impl.dart';
import 'features/flashcards/domain/repositories/flashcard_repository.dart';
import 'features/flashcards/presentation/bloc/flashcard_bloc.dart';

import 'features/notifications/data/datasources/notifications_local_data_source.dart';
import 'features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'features/notifications/data/repositories/notifications_repository_impl.dart';
import 'features/notifications/domain/repositories/notifications_repository.dart';

import 'features/config/data/datasources/config_remote_data_source.dart';
import 'features/config/data/repositories/config_repository_impl.dart';
import 'features/config/domain/repositories/config_repository.dart';
import 'features/config/presentation/bloc/config_bloc.dart';

final sl = GetIt.instance;

class AppConfig {
  final String flavor;
  AppConfig({required this.flavor});

  bool get isPremium => flavor == 'premium';
}

Future<void> init({String? apiBaseUrl, String flavor = 'store'}) async {
  sl.registerSingleton<AppConfig>(AppConfig(flavor: flavor));
  
  // 1. Core Services / Singletons
  final sharedPrefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(sharedPrefs);

  const secureStorage = FlutterSecureStorage();
  sl.registerSingleton<FlutterSecureStorage>(secureStorage);

  final storageService = StorageServiceImpl(secureStorage);
  sl.registerSingleton<StorageService>(storageService);

  final databaseHelper = DatabaseHelper(storageService);
  sl.registerSingleton<DatabaseHelper>(databaseHelper);

  final eventBus = EventBus();
  sl.registerSingleton<EventBus>(eventBus);

  // Default development URL (can be customized via Remote Config later)
  final fallbackUrl = apiBaseUrl ?? 'http://10.0.2.2:8080/api/v1';
  final dioInstance = Dio();
  final dioClient = DioClient(
    dio: dioInstance,
    storageService: storageService,
    baseUrl: fallbackUrl,
  );
  sl.registerSingleton<Dio>(dioInstance);
  sl.registerSingleton<DioClient>(dioClient);

  sl.registerLazySingleton<GooglePlayPaymentProvider>(() => GooglePlayPaymentProvider(sl()));
  sl.registerLazySingleton<BazaarPaymentProvider>(() => BazaarPaymentProvider(sl()));
  sl.registerLazySingleton<MyketPaymentProvider>(() => MyketPaymentProvider(sl()));
  sl.registerLazySingleton<DirectPaymentProvider>(() => DirectPaymentProvider(sl()));
  sl.registerLazySingleton<OfflineBackupService>(() => OfflineBackupService(sl()));

  // 2. Feature Data Sources
  // Auth
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(
      storageService: sl(),
      sharedPreferences: sl(),
    ),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: sl()),
  );

  // Courses
  sl.registerLazySingleton<CoursesRemoteDataSource>(
    () => CoursesRemoteDataSourceImpl(dioClient: sl()),
  );
  sl.registerLazySingleton<CoursesLocalDataSource>(
    () => CoursesLocalDataSourceImpl(databaseHelper: sl()),
  );

  // Notifications
  sl.registerLazySingleton<NotificationsRemoteDataSource>(
    () => NotificationsRemoteDataSourceImpl(dioClient: sl()),
  );
  sl.registerLazySingleton<NotificationsLocalDataSource>(
    () => NotificationsLocalDataSourceImpl(databaseHelper: sl()),
  );

  sl.registerLazySingleton<ConfigRemoteDataSource>(
    () => ConfigRemoteDataSourceImpl(dioClient: sl()),
  );

  // 3. Repositories
  // Auth
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );

  // Courses
  sl.registerLazySingleton<CoursesRepository>(
    () => CoursesRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      dio: sl(),
    ),
  );

  // Flashcards (Leitner Engine)
  sl.registerLazySingleton<FlashcardRepository>(
    () => FlashcardRepositoryImpl(
      databaseHelper: sl(),
      dioClient: sl(),
      eventBus: sl(),
    ),
  );

  // Notifications
  sl.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      sharedPreferences: sl(),
    ),
  );

  sl.registerLazySingleton<ConfigRepository>(
    () => ConfigRepositoryImpl(
      remoteDataSource: sl(),
      sharedPreferences: sl(),
      dioClient: sl(),
    ),
  );

  // 4. Use Cases
  // Auth
  sl.registerLazySingleton(() => GetCaptcha(sl()));
  sl.registerLazySingleton(() => RequestOtp(sl()));
  sl.registerLazySingleton(() => VerifyOtp(sl()));
  sl.registerLazySingleton(() => GetProfile(sl()));
  sl.registerLazySingleton(() => UpdateProfile(sl()));
  sl.registerLazySingleton(() => AcceptTerms(sl()));
  sl.registerLazySingleton(() => CheckTermsAccepted(sl()));
  sl.registerLazySingleton(() => Logout(sl()));

  // Courses
  sl.registerLazySingleton(() => GetCourses(sl()));
  sl.registerLazySingleton(() => DownloadCourse(sl()));

  // 5. BLoC / State Management (registered as factory)
  // Auth
  sl.registerFactory(
    () => AuthBloc(
      getCaptchaUseCase: sl(),
      requestOtpUseCase: sl(),
      verifyOtpUseCase: sl(),
      getProfileUseCase: sl(),
      updateProfileUseCase: sl(),
      acceptTermsUseCase: sl(),
      checkTermsAcceptedUseCase: sl(),
      logoutUseCase: sl(),
    ),
  );

  // Courses
  sl.registerFactory(
    () => CoursesBloc(
      getCoursesUseCase: sl(),
      downloadCourseUseCase: sl(),
    ),
  );

  // Flashcards
  sl.registerFactory(
    () => FlashcardBloc(
      flashcardRepository: sl(),
    ),
  );

  sl.registerFactory(
    () => ConfigBloc(
      configRepository: sl(),
    ),
  );
}
