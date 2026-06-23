import 'package:equatable/equatable.dart';

class Banner extends Equatable {
  final String id;
  final String imageUrl;
  final String? linkUrl;
  final int displayOrder;
  final bool isActive;

  const Banner({
    required this.id,
    required this.imageUrl,
    this.linkUrl,
    required this.displayOrder,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [id, imageUrl, linkUrl, displayOrder, isActive];
}
