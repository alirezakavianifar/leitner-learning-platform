import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/auth/data/models/user_model.dart';
import 'package:mobile_app/features/courses/data/models/course_model.dart';
import 'package:mobile_app/features/courses/data/models/course_package_model.dart';

import 'package:mobile_app/core/utils/image_url_resolver.dart';

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
      final json = {
        'id': '123',
        'mobile_number': '09123456789',
        'username': 'testuser',
        'interests': 'Tech, AI',
        'educational_field': 'Engineering',
        'educational_level': 'BSc',
        'created_at': '2026-06-21T07:50:37.000Z',
      };

      final result = UserModel.fromJson(json);

      expect(result.id, '123');
      expect(result.mobileNumber, '09123456789');
      expect(result.username, 'testuser');
      expect(result.interests, 'Tech, AI');
      expect(result.educationalField, 'Engineering');
      expect(result.educationalLevel, 'BSc');
      expect(result.createdAt, DateTime.parse('2026-06-21T07:50:37.000Z'));
    });

    test('should parse and serialize profile_picture_url correctly', () {
      final json = {
        'id': 'u-avatar-1',
        'mobile_number': '09123456789',
        'username': 'avatar_user',
        'interests': 'English',
        'educational_field': 'General',
        'educational_level': 'Student',
        'profile_picture_url': '/uploads/avatars/avatar_u-avatar-1_123456.png',
        'created_at': '2026-06-21T07:50:37.000Z',
      };

      final result = UserModel.fromJson(json);
      expect(result.profilePictureUrl, '/uploads/avatars/avatar_u-avatar-1_123456.png');
      expect(result.toJson()['profile_picture_url'], '/uploads/avatars/avatar_u-avatar-1_123456.png');
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
      expect(course.toCacheMap()['image_url'], 'https://example.com/banner.jpg');

      final fromCache = CourseModel.fromCacheMap(course.toCacheMap());
      expect(fromCache.imageUrl, 'https://example.com/banner.jpg');
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
      expect(pkg.toCacheMap()['image_url'], 'https://example.com/package-banner.png');

      final fromCache = CoursePackageModel.fromCacheMap(pkg.toCacheMap());
      expect(fromCache.imageUrl, 'https://example.com/package-banner.png');
    });
  });

  group('ImageUrlResolver Tests', () {
    test('should return null for null, empty or whitespace strings', () {
      expect(resolveImageUrl(null), isNull);
      expect(resolveImageUrl(''), isNull);
      expect(resolveImageUrl('   '), isNull);
    });

    test('should preserve absolute HTTP/HTTPS URLs', () {
      expect(resolveImageUrl('https://cdn.example.com/images/course.png'), 'https://cdn.example.com/images/course.png');
      expect(resolveImageUrl('http://myhost.org/banner.jpg'), 'http://myhost.org/banner.jpg');
    });

    test('should preserve asset, file, and data paths', () {
      expect(resolveImageUrl('assets/images/placeholder.png'), 'assets/images/placeholder.png');
      expect(resolveImageUrl('file:///data/local/img.png'), 'file:///data/local/img.png');
      expect(resolveImageUrl('data:image/png;base64,iVBORw0KGgo='), 'data:image/png;base64,iVBORw0KGgo=');
    });

    test('should resolve relative URLs properly', () {
      final resolved = resolveImageUrl('/uploads/courses/banner1.jpg');
      expect(resolved, isNotNull);
      expect(resolved!.endsWith('/uploads/courses/banner1.jpg'), isTrue);
      expect(resolved.startsWith('http://') || resolved.startsWith('https://'), isTrue);
    });
  });
}
