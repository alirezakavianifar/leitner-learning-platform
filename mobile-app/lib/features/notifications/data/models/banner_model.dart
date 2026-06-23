import 'package:mobile_app/features/notifications/domain/entities/banner.dart' as entity;

class BannerModel extends entity.Banner {
  const BannerModel({
    required super.id,
    required super.imageUrl,
    super.linkUrl,
    required super.displayOrder,
    super.isActive,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String,
      linkUrl: json['link_url'] as String?,
      displayOrder: json['display_order'] as int,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  factory BannerModel.fromDbMap(Map<String, dynamic> map) {
    return BannerModel(
      id: map['id'] as String,
      imageUrl: map['image_url'] as String,
      linkUrl: map['link_url'] as String?,
      displayOrder: map['display_order'] as int,
      isActive: (map['is_active'] as int) == 1,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'image_url': imageUrl,
      'link_url': linkUrl,
      'display_order': displayOrder,
      'is_active': isActive ? 1 : 0,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'link_url': linkUrl,
      'display_order': displayOrder,
      'is_active': isActive,
    };
  }
}
