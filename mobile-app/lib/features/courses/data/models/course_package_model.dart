import 'package:mobile_app/features/courses/data/models/course_model.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';
import 'package:mobile_app/features/courses/domain/entities/course_package.dart';

class CoursePackageModel extends CoursePackage {
  const CoursePackageModel({
    required String id,
    required String title,
    String? description,
    String? category,
    String? imageUrl,
    required double price,
    double? originalPrice,
    int discountPercentage = 0,
    required int totalCardCount,
    required bool isPurchased,
    int coursesCount = 0,
    int ownedCoursesCount = 0,
    List<Course> courses = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super(
          id: id,
          title: title,
          description: description,
          category: category,
          imageUrl: imageUrl,
          price: price,
          originalPrice: originalPrice,
          discountPercentage: discountPercentage,
          totalCardCount: totalCardCount,
          isPurchased: isPurchased,
          coursesCount: coursesCount,
          ownedCoursesCount: ownedCoursesCount,
          courses: courses,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

  factory CoursePackageModel.fromJson(Map<String, dynamic> json) {
    List<Course> coursesList = [];
    if (json['courses'] != null && json['courses'] is List) {
      coursesList = (json['courses'] as List)
          .map((c) => CourseModel.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    return CoursePackageModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      imageUrl: (json['image_url'] ?? json['imageUrl'] ?? json['image']) as String?,
      price: (json['price'] as num).toDouble(),
      originalPrice: json['original_price'] != null
          ? (json['original_price'] as num).toDouble()
          : null,
      discountPercentage: json['discount_percentage'] as int? ?? 0,
      totalCardCount: json['total_card_count'] as int? ?? 0,
      isPurchased: json['is_purchased'] as bool? ?? false,
      coursesCount: json['courses_count'] as int? ?? coursesList.length,
      ownedCoursesCount: json['owned_courses_count'] as int? ?? 0,
      courses: coursesList,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'image_url': imageUrl,
      'price': price,
      'original_price': originalPrice,
      'discount_percentage': discountPercentage,
      'total_card_count': totalCardCount,
      'is_purchased': isPurchased,
      'courses_count': coursesCount,
      'owned_courses_count': ownedCoursesCount,
      'courses': courses.map((c) {
        if (c is CourseModel) return c.toJson();
        return {
          'id': c.id,
          'title': c.title,
          'description': c.description,
          'category': c.category,
          'difficulty': c.difficulty,
          'price': c.price,
          'card_count': c.cardCount,
          'is_purchased': c.isPurchased,
          'version': c.version,
        };
      }).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory CoursePackageModel.fromCacheMap(
    Map<String, dynamic> map, {
    List<Course> courses = const [],
  }) {
    final ownedCount = courses.where((c) => c.isPurchased).length;
    final totalCards = courses.fold<int>(0, (sum, c) => sum + c.cardCount);
    final isPurchasedFlag = (map['is_purchased'] as int?) == 1 ||
        (courses.isNotEmpty && ownedCount == courses.length);

    return CoursePackageModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      category: map['category'] as String?,
      imageUrl: (map['image_url'] ?? map['imageUrl']) as String?,
      price: (map['price'] as num).toDouble(),
      originalPrice: map['original_price'] != null
          ? (map['original_price'] as num).toDouble()
          : null,
      discountPercentage: map['discount_percentage'] as int? ?? 0,
      totalCardCount: totalCards > 0 ? totalCards : (map['total_card_count'] as int? ?? 0),
      isPurchased: isPurchasedFlag,
      coursesCount: courses.isNotEmpty ? courses.length : (map['courses_count'] as int? ?? 0),
      ownedCoursesCount: ownedCount,
      courses: courses,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'image_url': imageUrl,
      'price': price,
      'original_price': originalPrice,
      'discount_percentage': discountPercentage,
      'total_card_count': totalCardCount,
      'is_purchased': isPurchased ? 1 : 0,
      'courses_count': courses.length > 0 ? courses.length : coursesCount,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
