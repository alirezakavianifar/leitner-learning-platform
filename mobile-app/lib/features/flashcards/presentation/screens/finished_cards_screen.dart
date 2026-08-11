import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';
import 'package:mobile_app/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:mobile_app/injection_container.dart' as di;

class FinishedCardsScreen extends StatefulWidget {
  const FinishedCardsScreen({Key? key}) : super(key: key);

  @override
  State<FinishedCardsScreen> createState() => _FinishedCardsScreenState();
}

class _FinishedCardsScreenState extends State<FinishedCardsScreen> {
  late FlashcardRepository _flashcardRepository;
  List<Flashcard> _finishedCards = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _showAnswer = false;

  @override
  void initState() {
    super.initState();
    _flashcardRepository = di.sl<FlashcardRepository>();
    _loadFinishedCards();
  }

  Future<void> _loadFinishedCards() async {
    setState(() => _isLoading = true);
    final cards = await _flashcardRepository.getFinishedCards();
    setState(() {
      _finishedCards = cards;
      _isLoading = false;
      _currentIndex = 0;
      _showAnswer = false;
    });
  }

  void _handleKnowIt() {
    final loc = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.cardRetainedMsg),
        duration: const Duration(milliseconds: 1200),
        backgroundColor: AppColors.finished,
      ),
    );
    _nextCard();
  }

  void _handleDontKnow() async {
    final loc = AppLocalizations.of(context);
    final card = _finishedCards[_currentIndex];
    await _flashcardRepository.submitReview(
      courseId: card.courseId,
      cardNumber: card.cardNumber,
      isCorrect: false,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.cardResetMsg),
        duration: const Duration(milliseconds: 1200),
        backgroundColor: AppColors.error,
      ),
    );

    setState(() {
      _finishedCards.removeAt(_currentIndex);
      _showAnswer = false;
      if (_currentIndex >= _finishedCards.length) {
        _currentIndex = 0;
      }
    });
  }

  void _nextCard() {
    if (_finishedCards.isEmpty) return;
    setState(() {
      _showAnswer = false;
      _currentIndex = (_currentIndex + 1) % _finishedCards.length;
    });
  }

  void _prevCard() {
    if (_finishedCards.isEmpty) return;
    setState(() {
      _showAnswer = false;
      _currentIndex = (_currentIndex - 1 + _finishedCards.length) % _finishedCards.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.finishedCards,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadFinishedCards,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _finishedCards.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified,
                          size: 64,
                          color: AppColors.finished.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.noFinishedCardsTitle,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.noFinishedCardsDesc,
                          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 80.0),
                    child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loc.reviewingMasteredCards,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.finished.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.finished),
                            ),
                            child: Text(
                              '${loc.cardPrefix}${_currentIndex + 1}/${_finishedCards.length}',
                              style: TextStyle(
                                color: AppColors.finished,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showAnswer = !_showAnswer;
                              });
                            },
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: _showAnswer ? AppColors.primary : AppColors.finished,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _showAnswer ? loc.answerLabel : loc.questionLabel,
                                        style: TextStyle(
                                          color: _showAnswer ? AppColors.primary : AppColors.finished,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Expanded(
                                        child: Center(
                                          child: SingleChildScrollView(
                                            child: Text(
                                              _showAnswer
                                                  ? _finishedCards[_currentIndex].answerText
                                                  : _finishedCards[_currentIndex].questionText,
                                              style: TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 20,
                                                height: 1.5,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Icon(
                                        Icons.touch_app,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        loc.tapCardToFlip,
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_showAnswer)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _handleDontKnow,
                              icon: const Icon(Icons.close, color: Colors.white),
                              label: Text(
                                loc.dontKnow,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.finished,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _handleKnowIt,
                              icon: const Icon(Icons.check, color: Colors.black),
                              label: Text(
                                loc.know,
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.arrow_forward_ios : Icons.arrow_back_ios, color: AppColors.primary),
                              onPressed: _prevCard,
                            ),
                            Text(
                              loc.tapCardToShowAnswer,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            IconButton(
                              icon: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.arrow_back_ios : Icons.arrow_forward_ios, color: AppColors.primary),
                              onPressed: _nextCard,
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
    );
  }
}
