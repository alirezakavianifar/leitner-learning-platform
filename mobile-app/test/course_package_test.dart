import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/courses/data/models/course_package_model.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/entities/course_package.dart';

void main() {
  group('CoursePackage and CoursePackageModel', () {
    final sampleJson = {
      'id': 'pkg-123',
      'title': 'Master English 3-in-1',
      'description': 'Comprehensive pack of English courses',
      'category': 'Languages',
      'price': 200000.0,
      'original_price': 300000.0,
      'discount_percentage': 33,
      'total_card_count': 650,
      'is_published': true,
      'is_archived': false,
      'is_purchased': false,
      'display_order': 1,
      'courses_count': 3,
      'courses': [
        {
          'id': 'c1',
          'title': 'Course 1',
          'category': 'Languages',
          'difficulty': 'Beginner',
          'price': 100000.0,
          'card_count': 200,
          'version': 1,
          'is_purchased': true,
          'is_downloaded': true,
          'is_archived': false,
          'update_available': false,
          'is_critical_update': false,
        },
        {
          'id': 'c2',
          'title': 'Course 2',
          'category': 'Languages',
          'difficulty': 'Intermediate',
          'price': 100000.0,
          'card_count': 250,
          'version': 1,
          'is_purchased': false,
          'is_downloaded': false,
          'is_archived': false,
          'update_available': false,
          'is_critical_update': false,
        },
        {
          'id': 'c3',
          'title': 'Course 3',
          'category': 'Languages',
          'difficulty': 'Advanced',
          'price': 100000.0,
          'card_count': 200,
          'version': 1,
          'is_purchased': false,
          'is_downloaded': false,
          'is_archived': false,
          'update_available': false,
          'is_critical_update': false,
        }
      ]
    };

    test('should correctly deserialize JSON into CoursePackageModel', () {
      final model = CoursePackageModel.fromJson(sampleJson);

      expect(model.id, 'pkg-123');
      expect(model.title, 'Master English 3-in-1');
      expect(model.price, 200000.0);
      expect(model.originalPrice, 300000.0);
      expect(model.discountPercentage, 33);
      expect(model.totalCardCount, 650);
      expect(model.isPurchased, false);
      expect(model.courses.length, 3);
      expect(model.courses[0].title, 'Course 1');
      expect(model.courses[0].isPurchased, true);
    });

    test('should calculate computed properties accurately', () {
      final package = CoursePackage(
        id: 'pkg-calc',
        title: 'Calc Test',
        price: 150000.0,
        originalPrice: 300000.0,
        discountPercentage: 50,
        totalCardCount: 500,
        isPurchased: true,
        courses: const [
          Course(
            id: 'c1',
            title: 'C1',
            price: 100000.0,
            cardCount: 200,
            version: 1,
            isPurchased: true,
            isDownloaded: true,
          ),
          Course(
            id: 'c2',
            title: 'C2',
            price: 200000.0,
            cardCount: 300,
            version: 1,
            isPurchased: true,
            isDownloaded: false,
          ),
        ],
      );

      expect(package.isPurchased, true);
      expect(package.effectiveCoursesCount, 2);
    });

    test('should convert to and from SQLite map representation', () {
      final model = CoursePackageModel.fromJson(sampleJson);
      final sqliteMap = model.toCacheMap();

      expect(sqliteMap['id'], 'pkg-123');
      expect(sqliteMap['title'], 'Master English 3-in-1');
      expect(sqliteMap['price'], 200000.0);
      expect(sqliteMap['courses_count'], 3);

      final fromSqlite = CoursePackageModel.fromCacheMap(sqliteMap, courses: model.courses);
      expect(fromSqlite.id, model.id);
      expect(fromSqlite.title, model.title);
      expect(fromSqlite.courses.length, 3);
    });
  });
}
