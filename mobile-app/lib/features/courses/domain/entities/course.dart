import 'package:equatable/equatable.dart';

class Course extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? category;
  final String? difficulty;
  final double price;
  final int cardCount;
  final bool isPurchased;
  final String? downloadUrl;
  final String? imageUrl;
  final int version;

  // Server-side content lifecycle metadata
  final bool isArchived;
  final bool isCriticalUpdate;
  final DateTime? updatedAt;

  // Client-side computed state
  final bool isDownloaded;
  final String? localDbPath;
  // The content version that is currently downloaded on this device, if any.
  // Null when the course has never been downloaded.
  final int? downloadedVersion;

  const Course({
    required this.id,
    required this.title,
    this.description,
    this.category,
    this.difficulty,
    required this.price,
    required this.cardCount,
    required this.isPurchased,
    this.downloadUrl,
    this.imageUrl,
    required this.version,
    this.isArchived = false,
    this.isCriticalUpdate = false,
    this.updatedAt,
    this.isDownloaded = false,
    this.localDbPath,
    this.downloadedVersion,
  });

  /// True when the course has been downloaded before but the server now has
  /// a newer content version available (e.g. the author fixed an issue).
  bool get updateAvailable =>
      isDownloaded && downloadedVersion != null && downloadedVersion! < version;

  Course copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? difficulty,
    double? price,
    int? cardCount,
    bool? isPurchased,
    String? downloadUrl,
    String? imageUrl,
    int? version,
    bool? isArchived,
    bool? isCriticalUpdate,
    DateTime? updatedAt,
    bool? isDownloaded,
    String? localDbPath,
    int? downloadedVersion,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      price: price ?? this.price,
      cardCount: cardCount ?? this.cardCount,
      isPurchased: isPurchased ?? this.isPurchased,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      version: version ?? this.version,
      isArchived: isArchived ?? this.isArchived,
      isCriticalUpdate: isCriticalUpdate ?? this.isCriticalUpdate,
      updatedAt: updatedAt ?? this.updatedAt,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localDbPath: localDbPath ?? this.localDbPath,
      downloadedVersion: downloadedVersion ?? this.downloadedVersion,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        category,
        difficulty,
        price,
        cardCount,
        isPurchased,
        downloadUrl,
        imageUrl,
        version,
        isArchived,
        isCriticalUpdate,
        updatedAt,
        isDownloaded,
        localDbPath,
        downloadedVersion,
      ];
}
