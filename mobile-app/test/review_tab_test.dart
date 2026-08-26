import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/error/failures.dart';
import 'package:mobile_app/core/event_bus/event_bus.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/repositories/courses_repository.dart';
import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:mobile_app/features/flashcards/presentation/widgets/review_tab.dart';
import 'package:mobile_app/injection_container.dart' as di;

class MockCoursesRepository extends Fake implements CoursesRepository {
  List<Course> mockCourses = [];

  @override
  Future<Either<Failure, (List<Course>, bool)>> getCourses() async {
    return Right((mockCourses, false));
  }
}

class MockFlashcardRepository extends Fake implements FlashcardRepository {
  Map<String, List<Flashcard>> mockQueues = {};

  @override
  Future<List<Flashcard>> getReviewQueue(String courseId, {bool isTodayReview = false}) async {
    return mockQueues[courseId] ?? [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCoursesRepository mockCoursesRepo;
  late MockFlashcardRepository mockFlashcardRepo;
  late EventBus eventBus;

  setUp(() async {
    await di.sl.reset();
    mockCoursesRepo = MockCoursesRepository();
    mockFlashcardRepo = MockFlashcardRepository();
    eventBus = EventBus();

    di.sl.registerSingleton<CoursesRepository>(mockCoursesRepo);
    di.sl.registerSingleton<FlashcardRepository>(mockFlashcardRepo);
    di.sl.registerSingleton<EventBus>(eventBus);
  });

  tearDown(() async {
    await di.sl.reset();
  });

  Widget buildTestWidget({VoidCallback? onNavigateToCatalog}) {
    return MaterialApp(
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: ReviewTab(onNavigateToCatalog: onNavigateToCatalog),
      ),
    );
  }

  group('ReviewTab Purchased vs Unpurchased Filtering Tests', () {
    testWidgets('Only purchased courses are displayed in ReviewTab', (tester) async {
      mockCoursesRepo.mockCourses = [
        const Course(
          id: 'course-1100',
          title: 'Words You Need to Know 1100',
          description: '1100 words',
          version: 1,
          cardCount: 1100,
          price: 1000,
          isPurchased: true,
          isDownloaded: true,
        ),
        const Course(
          id: 'course-504',
          title: 'Absolutely Essential Words 504',
          description: '504 words',
          version: 1,
          cardCount: 504,
          price: 5000,
          isPurchased: false,
          isDownloaded: true, // downloaded on disk, but NOT purchased
        ),
      ];

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Only 'Words You Need to Know 1100' should be displayed
      expect(find.text('Words You Need to Know 1100'), findsOneWidget);
      // 'Absolutely Essential Words 504' should NOT be displayed
      expect(find.text('Absolutely Essential Words 504'), findsNothing);
    });

    testWidgets('Empty state is shown when user has no purchased courses', (tester) async {
      bool catalogNavigated = false;
      mockCoursesRepo.mockCourses = [
        const Course(
          id: 'course-unpurchased',
          title: 'Unpurchased Course',
          description: 'Desc',
          version: 1,
          cardCount: 100,
          price: 5000,
          isPurchased: false,
          isDownloaded: true,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(
        onNavigateToCatalog: () {
          catalogNavigated = true;
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('هیچ دوره‌ای برای مرور وجود ندارد'), findsOneWidget);
      expect(find.text('مشاهده کاتالوگ دوره‌ها'), findsOneWidget);

      await tester.tap(find.text('مشاهده کاتالوگ دوره‌ها'));
      await tester.pumpAndSettle();

      expect(catalogNavigated, isTrue);
    });

    testWidgets('Purchased non-downloaded course shows Download button', (tester) async {
      mockCoursesRepo.mockCourses = [
        const Course(
          id: 'course-purchased-not-downloaded',
          title: 'Purchased But Not Downloaded',
          description: 'Desc',
          version: 1,
          cardCount: 200,
          price: 2000,
          isPurchased: true,
          isDownloaded: false,
        ),
      ];

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Purchased But Not Downloaded'), findsOneWidget);
      expect(find.text('دانلود دوره'), findsOneWidget);
      expect(find.text('دانلود جهت مرور'), findsOneWidget);
    });
  });
}
