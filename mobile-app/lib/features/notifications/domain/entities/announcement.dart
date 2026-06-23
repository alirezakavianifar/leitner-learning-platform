import 'package:equatable/equatable.dart';

class Announcement extends Equatable {
  final String id;
  final String title;
  final String content;
  final DateTime publishedAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.publishedAt,
  });

  @override
  List<Object?> get props => [id, title, content, publishedAt];
}
