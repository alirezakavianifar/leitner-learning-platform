import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/entities/course_package.dart';
import 'package:mobile_app/features/courses/presentation/widgets/package_card.dart';
import 'package:mobile_app/features/courses/presentation/widgets/package_details_modal.dart';

void main() {
  group('Course Description Localization Tests', () {
    test('AppLocalizations has clean viewDetails without misleading (Long Press) text', () {
      final enLoc = AppLocalizations(const Locale('en'));
      final faLoc = AppLocalizations(const Locale('fa'));

      expect(enLoc.viewDetails, 'View Details');
      expect(faLoc.viewDetails, 'مشاهده جزئیات');

      // Ensure 'more_info_hint' no longer contains "(Long Press)" or "(لمس طولانی)"
      expect(enLoc.translate('more_info_hint'), isNot(contains('Long Press')));
      expect(faLoc.translate('more_info_hint'), isNot(contains('لمس طولانی')));
      expect(faLoc.translate('more_info_hint'), 'مشاهده جزئیات');

      // Ensure fallback string is available
      expect(enLoc.noDescriptionAvailable, 'No description available for this course.');
      expect(faLoc.noDescriptionAvailable, 'توضیحاتی برای این دوره ثبت نشده است.');

      // Ensure empty bundle fallback is available
      expect(enLoc.emptyBundleCourses, 'No courses are currently included in this bundle.');
      expect(faLoc.emptyBundleCourses, 'در حال حاضر دوره‌ای در این پکیج قرار ندارد.');
    });
  });

  group('PackageCard Description & View Details Tests', () {
    testWidgets('PackageCard displays description snippet and viewDetails without long press text', (tester) async {
      const package = CoursePackage(
        id: 'pkg-1',
        title: 'Interchange intro (yellow book)',
        description: 'پکیج جامع آموزش زبان انگلیسی اینترچنج کتاب اینترو',
        price: 0,
        totalCardCount: 483,
        coursesCount: 1,
        isPurchased: true,
        courses: [
          Course(
            id: 'c1',
            title: 'grammar.intro',
            description: 'آموزش کامل گرامر اینترو',
            price: 0,
            cardCount: 483,
            version: 1,
            isPurchased: true,
            isDownloaded: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: PackageCard(
              package: package,
              onTap: () {},
              onPurchase: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Description snippet is displayed
      expect(find.text('پکیج جامع آموزش زبان انگلیسی اینترچنج کتاب اینترو'), findsOneWidget);

      // 'مشاهده جزئیات' is displayed
      expect(find.text('مشاهده جزئیات'), findsOneWidget);

      // Misleading 'توضیحات (لمس طولانی)' is NOT present
      expect(find.textContaining('لمس طولانی'), findsNothing);
    });
  });

  group('PackageDetailsModal Description & Empty State Tests', () {
    testWidgets('PackageDetailsModal displays description and fallback when 0 courses included', (tester) async {
      const emptyPackage = CoursePackage(
        id: 'pkg-empty',
        title: 'Interchange level intro',
        description: 'توضیحات پکیج زبان انگلیسی',
        category: 'زبان های خارجی',
        price: 0,
        totalCardCount: 0,
        coursesCount: 0,
        isPurchased: false,
        courses: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  PackageDetailsModal.show(
                    ctx,
                    package: emptyPackage,
                    onPurchase: () {},
                  );
                },
                child: const Text('Open Package Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Package Modal'));
      await tester.pumpAndSettle();

      // Verify description is rendered
      expect(find.text('توضیحات پکیج زبان انگلیسی'), findsOneWidget);

      // Verify empty bundle fallback message is shown instead of blank space
      expect(find.text('در حال حاضر دوره‌ای در این پکیج قرار ندارد.'), findsOneWidget);

      // Dismiss modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(PackageDetailsModal), findsNothing);
    });
  });
}
