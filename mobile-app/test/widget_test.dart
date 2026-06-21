import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/usecase/usecase.dart';
import 'package:mobile_app/features/auth/data/models/user_model.dart';

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
}
