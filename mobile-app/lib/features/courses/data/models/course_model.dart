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
    bool isArchived = false,
    bool isCriticalUpdate = false,
    DateTime? updatedAt,
    bool isDownloaded = false,
    String? localDbPath,
    int? downloadedVersion,
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
          isArchived: isArchived,
          isCriticalUpdate: isCriticalUpdate,
          updatedAt: updatedAt,
          isDownloaded: isDownloaded,
          localDbPath: localDbPath,
          downloadedVersion: downloadedVersion,
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
      isArchived: json['is_archived'] as bool? ?? false,
      isCriticalUpdate: json['is_critical_update'] as bool? ?? false,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
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
      'is_archived': isArchived,
      'is_critical_update': isCriticalUpdate,
      'updated_at': updatedAt?.toIso8601String(),
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
      isArchived: (map['is_archived'] as int?) == 1,
      isCriticalUpdate: (map['is_critical_update'] as int?) == 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'] as String) : null,
      isDownloaded: isDownloaded,
      localDbPath: localDbPath,
      downloadedVersion: map['downloaded_version'] as int?,
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
      'is_archived': isArchived ? 1 : 0,
      'is_critical_update': isCriticalUpdate ? 1 : 0,
      'updated_at': updatedAt?.toIso8601String(),
      // downloaded_version is intentionally omitted: it is client-owned state
      // and must be preserved across re-caches, not overwritten from the server.
    };
  }
}
