import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';
import 'package:mobile_app/features/flashcards/presentation/bloc/flashcard_bloc.dart';
import 'package:mobile_app/features/flashcards/presentation/bloc/flashcard_event.dart';
import 'package:mobile_app/features/flashcards/presentation/bloc/flashcard_state.dart';
import 'package:mobile_app/injection_container.dart' as di;

class FlashcardStudyScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final int? initialCardNumber;

  const FlashcardStudyScreen({
    Key? key,
    required this.courseId,
    required this.courseTitle,
    this.initialCardNumber,
  }) : super(key: key);

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late AudioPlayer _audioPlayer;
  String? _documentsPath;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _audioPlayer = AudioPlayer();
    _loadDocumentsPath();
  }

  Future<void> _loadDocumentsPath() async {
    final dir = await getApplicationDocumentsDirectory();
    setState(() {
      _documentsPath = dir.path;
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String filename) async {
    if (_documentsPath == null) return;
    final audioFilePath = p.join(_documentsPath!, 'courses', widget.courseId, 'audio', filename);
    if (File(audioFilePath).existsSync()) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(audioFilePath));
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to play card audio file.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showJumpDialog(BuildContext context, FlashcardBloc bloc) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        title: const Text('Direct Card Jump', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter card number (e.g. 15)',
          ),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final number = int.tryParse(controller.text);
              if (number != null && number > 0) {
                Navigator.pop(dialogCtx);
                bloc.add(JumpToCardNumber(number));
              }
            },
            child: const Text('Jump', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, FlashcardBloc bloc) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        title: const Text('Submit Content Report', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Describe card typos, errors, or feedback here...',
          ),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogCtx);
                bloc.add(SubmitReport(controller.text.trim()));
              }
            },
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showJumpWarningDialog(BuildContext context, FlashcardBloc bloc, int cardNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.box1),
            SizedBox(width: 8),
            Text('Warning', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Card #$cardNumber is currently in an active Leitner Box (Boxes 2–5). Viewing it directly will reset its learning progress back to Box 1.\n\nDo you want to proceed?',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              // Discard jump request
              bloc.add(LoadFlashcardQueue(widget.courseId));
            },
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              bloc.add(JumpToCardNumber(cardNumber, forceReset: true));
            },
            child: const Text('Reset & Jump', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

  String _getBoxName(int box) {
    if (box == 6) return 'Finished';
    return 'Box $box';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FlashcardBloc>(
      create: (_) {
        final bloc = di.sl<FlashcardBloc>()..add(LoadFlashcardQueue(widget.courseId));
        if (widget.initialCardNumber != null) {
          bloc.add(JumpToCardNumber(widget.initialCardNumber!, forceReset: true));
        }
        return bloc;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.courseTitle,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
        ),
        body: BlocConsumer<FlashcardBloc, FlashcardState>(
          listener: (context, state) {
            if (state is FlashcardQueueLoaded) {
              if (state.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.error!), backgroundColor: AppColors.error),
                );
              }
              if (state.reportMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.reportMessage!), backgroundColor: AppColors.primary),
                );
              }
              if (state.jumpWarningCardNumber != null) {
                _showJumpWarningDialog(context, context.read<FlashcardBloc>(), state.jumpWarningCardNumber!);
              }

              // Update flip animation controller based on state
              if (state.isFlipped) {
                _flipController.forward();
              } else {
                _flipController.reverse();
              }
            }
          },
          builder: (context, state) {
            if (state is FlashcardLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            if (state is FlashcardFinished) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emoji_events, color: AppColors.secondary, size: 64),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Study Loop Complete!',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'You have reviewed all currently due cards in this course. Come back later for your next spaced review session!',
                        style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back to Courses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is FlashcardQueueLoaded) {
              final card = state.currentCard;
              if (card == null) return const SizedBox.shrink();

              final currentBox = card.progress.currentBox;
              final boxColor = _getBoxColor(currentBox);

              return Column(
                children: [
                  // 1. Fixed Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Review Queue',
                          style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: boxColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: boxColor.withOpacity(0.4), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: boxColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getBoxName(currentBox),
                                style: TextStyle(color: boxColor, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Rotating Center Card
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          context.read<FlashcardBloc>().add(FlipFlashcard());
                        },
                        child: AnimatedBuilder(
                          animation: _flipController,
                          builder: (context, child) {
                            final angle = _flipController.value * pi;
                            final isBack = angle > pi / 2;

                            return Transform(
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(angle),
                              alignment: Alignment.center,
                              child: isBack
                                  ? Transform(
                                      transform: Matrix4.identity()..rotateY(pi),
                                      alignment: Alignment.center,
                                      child: _buildCardFace(card, isFront: false),
                                    )
                                  : _buildCardFace(card, isFront: true),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // 3. Back Action buttons (Know / Don't Know) - Rendered only when card is flipped/revealed
                  if (state.isFlipped)
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12, top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                context.read<FlashcardBloc>().add(const SubmitReview(isCorrect: false));
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.close, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text("Don't Know", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.courseDownloaded,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                context.read<FlashcardBloc>().add(const SubmitReview(isCorrect: true));
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text("I Know It", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 4. Fixed Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.5),
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Previous arrow
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, size: 20),
                            color: state.currentIndex > 0 ? AppColors.textPrimary : AppColors.textSecondary.withOpacity(0.3),
                            onPressed: state.currentIndex > 0
                                ? () => context.read<FlashcardBloc>().add(PrevCard())
                                : null,
                          ),
                          // Card metadata and direct jump trigger
                          GestureDetector(
                            onTap: () => _showJumpDialog(context, context.read<FlashcardBloc>()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.background.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Card #${card.cardNumber}',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${state.currentIndex + 1}/${state.queue.length})',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Favorites toggle & reports button
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  state.isFavorited ? Icons.star : Icons.star_border,
                                  color: state.isFavorited ? AppColors.box2 : AppColors.textSecondary,
                                ),
                                onPressed: () => context.read<FlashcardBloc>().add(ToggleFavorite()),
                              ),
                              IconButton(
                                icon: const Icon(Icons.flag_outlined, color: AppColors.textSecondary),
                                onPressed: () => _showReportDialog(context, context.read<FlashcardBloc>()),
                              ),
                            ],
                          ),
                          // Next arrow
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 20),
                            color: state.currentIndex < state.queue.length - 1
                                ? AppColors.textPrimary
                                : AppColors.textSecondary.withOpacity(0.3),
                            onPressed: state.currentIndex < state.queue.length - 1
                                ? () => context.read<FlashcardBloc>().add(NextCard())
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildCardFace(Flashcard card, {required bool isFront}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Section header indicating front/back
          Text(
            isFront ? 'QUESTION' : 'ANSWER',
            style: TextStyle(
              color: isFront ? AppColors.primary : AppColors.secondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          // Conditional image rendering (Front only, or both if needed)
          if (isFront && card.imageUrl != null && card.imageUrl!.trim().isNotEmpty && _documentsPath != null) ...[
            FutureBuilder<String>(
              future: Future.value(p.join(_documentsPath!, 'courses', widget.courseId, 'images', card.imageUrl!)),
              builder: (context, snapshot) {
                if (snapshot.hasData && File(snapshot.data!).existsSync()) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(snapshot.data!),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
          // Main text
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  isFront ? card.questionText : card.answerText,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Conditional audio player rendering (Front only)
          if (isFront && card.audioUrl != null && card.audioUrl!.trim().isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.volume_up, color: AppColors.primary, size: 28),
                onPressed: () => _playAudio(card.audioUrl!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
