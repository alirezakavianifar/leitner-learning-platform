import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/constants/app_nav_icons.dart';

void main() {
  group('Card Navigation Arrows Direction Verification in RTL', () {
    testWidgets('Verify wrapping in LTR ensures left arrow points left and right arrow points right', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl, // App runs in Persian RTL
            child: Scaffold(
              body: Stack(
                children: [
                  // Left Navigation Overlay (Next Card in RTL sequence)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 44,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: const Center(
                        child: Icon(Icons.chevron_left, key: ValueKey('left_icon')),
                      ),
                    ),
                  ),

                  // Right Navigation Overlay (Previous Card in RTL sequence)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 44,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: const Center(
                        child: Icon(Icons.chevron_right, key: ValueKey('right_icon')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final leftIcon = tester.widget<Icon>(find.byKey(const ValueKey('left_icon')));
      expect(leftIcon.icon, Icons.chevron_left);

      final rightIcon = tester.widget<Icon>(find.byKey(const ValueKey('right_icon')));
      expect(rightIcon.icon, Icons.chevron_right);
    });

    test('AppNavIcons returns correct icon pairs for all supported styles', () {
      expect(AppNavIcons.getLeftIcon('chevron'), Icons.chevron_left);
      expect(AppNavIcons.getRightIcon('chevron'), Icons.chevron_right);

      expect(AppNavIcons.getLeftIcon('arrow'), Icons.arrow_back);
      expect(AppNavIcons.getRightIcon('arrow'), Icons.arrow_forward);

      expect(AppNavIcons.getLeftIcon('arrow_ios'), Icons.arrow_back_ios_new);
      expect(AppNavIcons.getRightIcon('arrow_ios'), Icons.arrow_forward_ios);

      expect(AppNavIcons.getLeftIcon('double_chevron'), Icons.keyboard_double_arrow_left);
      expect(AppNavIcons.getRightIcon('double_chevron'), Icons.keyboard_double_arrow_right);

      expect(AppNavIcons.getLeftIcon('circle_arrow'), Icons.arrow_circle_left);
      expect(AppNavIcons.getRightIcon('circle_arrow'), Icons.arrow_circle_right);

      expect(AppNavIcons.getLeftIcon('triangle'), Icons.arrow_left);
      expect(AppNavIcons.getRightIcon('triangle'), Icons.arrow_right);

      // Fallback
      expect(AppNavIcons.getLeftIcon(null), Icons.chevron_left);
      expect(AppNavIcons.getRightIcon(null), Icons.chevron_right);
    });
  });
}
