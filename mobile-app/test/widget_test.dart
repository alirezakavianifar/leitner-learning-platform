import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/auth/data/models/user_model.dart';
import 'package:mobile_app/features/courses/data/models/course_model.dart';
import 'package:mobile_app/features/courses/data/models/course_package_model.dart';

void main() {
  group('Either Utility Tests', () {
    test('Right should return the right value when folded', () {
      const Either<String, int> either = Right(42);
      final result = either.fold(
        (left) => 0,
        (right) => right,
      );
      expect(result, 42);
      expect(either.isRight, true);
      expect(either.isLeft, false);
    });

    test('Left should return the left value when folded', () {
      const Either<String, int> either = Left('error');
      final result = either.fold(
        (left) => left,
        (right) => 'success',
      );
      expect(result, 'error');
      expect(either.isLeft, true);
      expect(either.isRight, false);
    });
  });

  group('UserModel Parsing Tests', () {
    test('should parse user model from json correctly', () {
      final jsonMap = {
        'id': 'test-uuid-12345',
        'username': 'student_test',
        'mobile_number': '+989123456789',
        'interests': 'computer science',
        'educational_field': 'Engineering',
        'educational_level': 'BSc',
        'created_at': '2026-06-21T07:50:37.000Z',
      };

      final result = UserModel.fromJson(jsonMap);

      expect(result.id, 'test-uuid-12345');
      expect(result.username, 'student_test');
      expect(result.mobileNumber, '+989123456789');
      expect(result.interests, 'computer science');
      expect(result.educationalField, 'Engineering');
      expect(result.educationalLevel, 'BSc');
      expect(result.createdAt, DateTime.parse('2026-06-21T07:50:37.000Z'));
    });
  });

  group('Course and Package ImageUrl Parsing Tests', () {
    test('CourseModel should parse image_url from json correctly', () {
      final json = {
        'id': 'c-101',
        'title': 'Test Course with Banner',
        'price': 50000,
        'card_count': 100,
        'is_purchased': false,
        'image_url': 'https://example.com/banner.jpg',
        'version': 1,
      };

      final course = CourseModel.fromJson(json);
      expect(course.id, 'c-101');
      expect(course.title, 'Test Course with Banner');
      expect(course.imageUrl, 'https://example.com/banner.jpg');
      expect(course.toJson()['image_url'], 'https://example.com/banner.jpg');
    });

    test('CoursePackageModel should parse image_url from json correctly', () {
      final json = {
        'id': 'pkg-202',
        'title': 'Gold 3-in-1 English Bundle',
        'price': 150000,
        'original_price': 200000,
        'image_url': 'https://example.com/package-banner.png',
        'total_card_count': 300,
        'is_purchased': false,
        'courses': [
          {
            'id': 'c-1',
            'title': 'Course 1',
            'price': 50000,
            'card_count': 100,
            'is_purchased': false,
            'image_url': 'https://example.com/c1.jpg',
            'version': 1,
          }
        ]
      };

      final pkg = CoursePackageModel.fromJson(json);
      expect(pkg.id, 'pkg-202');
      expect(pkg.title, 'Gold 3-in-1 English Bundle');
      expect(pkg.imageUrl, 'https://example.com/package-banner.png');
      expect(pkg.courses.length, 1);
      expect(pkg.courses.first.imageUrl, 'https://example.com/c1.jpg');
      expect(pkg.toJson()['image_url'], 'https://example.com/package-banner.png');
    });
  });
}
