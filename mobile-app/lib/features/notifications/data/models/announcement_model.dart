import 'package:mobile_app/features/notifications/domain/entities/announcement.dart' as entity;

class AnnouncementModel extends entity.Announcement {
  const AnnouncementModel({
    required super.id,
    required super.title,
    required super.content,
    required super.publishedAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      publishedAt: DateTime.parse(json['published_at'] as String),
    );
  }

  factory AnnouncementModel.fromDbMap(Map<String, dynamic> map) {
    return AnnouncementModel(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      publishedAt: DateTime.parse(map['published_at'] as String),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'published_at': publishedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'published_at': publishedAt.toUtc().toIso8601String(),
    };
  }
}
