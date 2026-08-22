import 'package:equatable/equatable.dart';
import 'package:mobile_app/features/courses/domain/entities/course.dart';

class CoursePackage extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? category;
  final double price;
  final double? originalPrice;
  final int discountPercentage;
  final int totalCardCount;
  final bool isPurchased;
  final int coursesCount;
  final int ownedCoursesCount;
  final List<Course> courses;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CoursePackage({
    required this.id,
    required this.title,
    this.description,
    this.category,
    required this.price,
    this.originalPrice,
    this.discountPercentage = 0,
    required this.totalCardCount,
    required this.isPurchased,
    this.coursesCount = 0,
    this.ownedCoursesCount = 0,
    this.courses = const [],
    this.createdAt,
    this.updatedAt,
  });

  int get effectiveCoursesCount => courses.isNotEmpty ? courses.length : coursesCount;
  int get effectiveOwnedCoursesCount =>
      courses.isNotEmpty ? courses.where((c) => c.isPurchased).length : ownedCoursesCount;

  /// Returns true if all courses in this package are downloaded locally.
  bool get isAllDownloaded =>
      courses.isNotEmpty && courses.every((c) => c.isDownloaded);

  /// Returns the number of downloaded courses in this package.
  int get downloadedCoursesCount =>
      courses.where((c) => c.isDownloaded).length;

  CoursePackage copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    double? price,
    double? originalPrice,
    int? discountPercentage,
    int? totalCardCount,
    bool? isPurchased,
    int? coursesCount,
    int? ownedCoursesCount,
    List<Course>? courses,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CoursePackage(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      totalCardCount: totalCardCount ?? this.totalCardCount,
      isPurchased: isPurchased ?? this.isPurchased,
      coursesCount: coursesCount ?? this.coursesCount,
      ownedCoursesCount: ownedCoursesCount ?? this.ownedCoursesCount,
      courses: courses ?? this.courses,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        category,
        price,
        originalPrice,
        discountPercentage,
        totalCardCount,
        isPurchased,
        coursesCount,
        ownedCoursesCount,
        courses,
        createdAt,
        updatedAt,
      ];
}
