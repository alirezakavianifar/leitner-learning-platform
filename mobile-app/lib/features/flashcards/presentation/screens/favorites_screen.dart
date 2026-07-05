import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:mobile_app/features/flashcards/presentation/screens/flashcard_study_screen.dart';
import 'package:mobile_app/injection_container.dart' as di;

class FavoritesScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const FavoritesScreen({
    Key? key,
    required this.courseId,
    required this.courseTitle,
  }) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late FlashcardRepository _repository;
  List<Flashcard> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = di.sl<FlashcardRepository>();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repository.getFavoriteCards(widget.courseId);
      setState(() {
        _favorites = list;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _onCardTap(Flashcard card) async {
    await Navigator.push(
      context,
      FlashcardStudyScreen.route(
        courseId: widget.courseId,
        courseTitle: widget.courseTitle,
        initialCardNumber: card.cardNumber,
      ),
    );
    _loadFavorites();
  }

  Color _getBoxColor(int box) {
    switch (box) {
      case 1:
        return AppColors.box1;
      case 2:
        return AppColors.box2;
      case 3:
        return AppColors.box3;
      case 4:
        return AppColors.box4;
      case 5:
        return AppColors.box5;
      case 6:
        return AppColors.finished;
      default:
        return AppColors.primary;
    }
  }

  String _getBoxName(BuildContext context, int box) {
    final loc = AppLocalizations.of(context);
    switch (box) {
      case 1:
        return loc.box1;
      case 2:
        return loc.box2;
      case 3:
        return loc.box3;
      case 4:
        return loc.box4;
      case 5:
        return loc.box5;
      case 6:
        return loc.finished;
      default:
        return '${loc.box1} $box';
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(loc.favoriteCards, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _favorites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_border, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      Text(loc.noFavoritesYet, style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final card = _favorites[index];
                    final boxColor = _getBoxColor(card.progress.currentBox);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: AppColors.surface.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        title: Text(
                          card.questionText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 15),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: boxColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(color: boxColor, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _getBoxName(context, card.progress.currentBox),
                                      style: TextStyle(color: boxColor, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${loc.cardPrefix}${card.cardNumber}',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        trailing: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                        onTap: () => _onCardTap(card),
                      ),
                    );
                  },
                ),
    );
  }
}
