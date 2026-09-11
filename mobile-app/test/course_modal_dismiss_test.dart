import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/entities/course_package.dart';
import 'package:mobile_app/features/courses/presentation/widgets/package_details_modal.dart';

void main() {
  test('AppLocalizations should have close key in English and Persian', () {
    final enLoc = AppLocalizations(const Locale('en'));
    final faLoc = AppLocalizations(const Locale('fa'));

    expect(enLoc.close, 'Close');
    expect(faLoc.close, 'بستن');
  });

  testWidgets('PackageDetailsModal opens and dismisses properly via close button', (tester) async {
    const pkg = CoursePackage(
      id: 'pkg-test',
      title: 'Bundle Test',
      description: 'Test Description',
      price: 50000,
      totalCardCount: 50,
      coursesCount: 1,
      isPurchased: false,
      courses: [
        Course(
          id: 'c1',
          title: 'Course 1',
          price: 25000,
          cardCount: 50,
          version: 1,
          isPurchased: false,
          isDownloaded: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('fa')],
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
                  package: pkg,
                  onPurchase: () {},
                );
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Open Modal'), findsOneWidget);

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    expect(find.byType(PackageDetailsModal), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Tap the close button
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Verify modal is dismissed
    expect(find.byType(PackageDetailsModal), findsNothing);
  });
}
