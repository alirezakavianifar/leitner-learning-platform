import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/utils/scroll_physics.dart';

void main() {
  group('ScrollOnlyWhenNeededPhysics Tests', () {
    test('shouldAcceptUserOffset should return false when maxScrollExtent is 0 (content fits)', () {
      const physics = ScrollOnlyWhenNeededPhysics();
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0.0,
        maxScrollExtent: 0.0,
        pixels: 0.0,
        viewportDimension: 600.0,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
      expect(physics.shouldAcceptUserOffset(metrics), false);
    });

    test('shouldAcceptUserOffset should return true when maxScrollExtent > 0 (content exceeds)', () {
      const physics = ScrollOnlyWhenNeededPhysics();
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0.0,
        maxScrollExtent: 100.0,
        pixels: 0.0,
        viewportDimension: 600.0,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
      expect(physics.shouldAcceptUserOffset(metrics), true);
    });

    test('applyTo should chain physics correctly', () {
      const physics = ScrollOnlyWhenNeededPhysics();
      const parent = BouncingScrollPhysics();
      final applied = physics.applyTo(parent);
      expect(applied.parent, parent);
    });
  });
}
