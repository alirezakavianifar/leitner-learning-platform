import 'package:mobile_app/features/courses/domain/entities/course.dart';

class CourseModel extends Course {
  const CourseModel({
    required String id,
    required String title,
    String? description,
    String? category,
    String? difficulty,
    required double price,
    required int cardCount,
    required bool isPurchased,
    String? downloadUrl,
    required int version,
    bool isDownloaded = false,
    String? localDbPath,
  }) : super(
          id: id,
          title: title,
          description: description,
          category: category,
          difficulty: difficulty,
          price: price,
          cardCount: cardCount,
          isPurchased: isPurchased,
          downloadUrl: downloadUrl,
          version: version,
          isDownloaded: isDownloaded,
          localDbPath: localDbPath,
        );

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      difficulty: json['difficulty'] as String?,
      price: (json['price'] as num).toDouble(),
      cardCount: json['card_count'] as int,
      isPurchased: json['is_purchased'] as bool,
      downloadUrl: json['download_url'] as String?,
      version: json['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'difficulty': difficulty,
      'price': price,
      'card_count': cardCount,
      'is_purchased': isPurchased,
      'download_url': downloadUrl,
      'version': version,
    };
  }

  factory CourseModel.fromCacheMap(Map<String, dynamic> map, {bool isDownloaded = false, String? localDbPath}) {
    return CourseModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      category: map['category'] as String?,
      difficulty: map['difficulty'] as String?,
      price: (map['price'] as num).toDouble(),
      cardCount: map['card_count'] as int,
      isPurchased: (map['is_purchased'] as int) == 1,
      downloadUrl: map['download_url'] as String?,
      version: map['version'] as int? ?? 1,
      isDownloaded: isDownloaded,
      localDbPath: localDbPath,
    );
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'difficulty': difficulty,
      'price': price,
      'card_count': cardCount,
      'is_purchased': isPurchased ? 1 : 0,
      'download_url': downloadUrl,
      'version': version,
    };
  }
}
