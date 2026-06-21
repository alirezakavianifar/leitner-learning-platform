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
  final int version;
  
  // Client-side computed state
  final bool isDownloaded;
  final String? localDbPath;

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
    required this.version,
    this.isDownloaded = false,
    this.localDbPath,
  });

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
    int? version,
    bool? isDownloaded,
    String? localDbPath,
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
      version: version ?? this.version,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localDbPath: localDbPath ?? this.localDbPath,
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
        version,
        isDownloaded,
        localDbPath,
      ];
}
