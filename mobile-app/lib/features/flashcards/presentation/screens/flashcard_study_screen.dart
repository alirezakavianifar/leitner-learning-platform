import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/flashcards/domain/entities/flashcard.dart';
import 'package:mobile_app/features/flashcards/presentation/bloc/flashcard_bloc.dart';
import 'package:mobile_app/features/flashcards/presentation/bloc/flashcard_event.dart';
import 'package:mobile_app/features/flashcards/presentation/bloc/flashcard_state.dart';
import 'package:mobile_app/injection_container.dart' as di;

class FlashcardStudyScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final int? initialCardNumber;
  final bool isTodayReview;

  const FlashcardStudyScreen({
    Key? key,
    required this.courseId,
    required this.courseTitle,
    this.initialCardNumber,
    this.isTodayReview = false,
  }) : super(key: key);

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late AudioPlayer _audioPlayer;
  String? _documentsPath;
  double _fontScale = 1.0;

  // MCQ and Spaced repetition prompting state tracking
  int? _lastCardNumber;
  int? _selectedOptionIndex;
  int? _lastPromptedCardNumber;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _audioPlayer = AudioPlayer();
    _loadDocumentsPath();
    _enableSecureMode();
  }

  Future<void> _enableSecureMode() async {
    if (!kIsWeb) {
      await NoScreenshot.instance.screenshotOff();
    }
  }

  Future<void> _disableSecureMode() async {
    if (!kIsWeb) {
      await NoScreenshot.instance.screenshotOn();
    }
  }

  Future<void> _loadDocumentsPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final prefs = di.sl<SharedPreferences>();
    setState(() {
      _documentsPath = dir.path;
      _fontScale = prefs.getDouble('flashcard_font_scale') ?? 1.0;
    });
  }

  @override
  void dispose() {
    _disableSecureMode();
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
          SnackBar(
            content: Text('Failed to play card audio file.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showJumpDialog(BuildContext context, FlashcardBloc bloc) {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(loc.directCardJump, style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: loc.enterCardNumberHint,
          ),
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(loc.cancel, style: TextStyle(color: AppColors.textSecondary)),
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
            child: Text(loc.jump, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, FlashcardBloc bloc, Flashcard card) {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(loc.submitReport, style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: loc.reportHint,
          ),
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(loc.cancel, style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final message = controller.text.trim();
              if (message.isNotEmpty) {
                Navigator.pop(dialogCtx);
                final stage = card.progress.currentBox;
                final cardNum = card.cardNumber;
                final fullReportText = "Course: ${widget.courseTitle}\n"
                    "Card Number: $cardNum\n"
                    "Stage: $stage\n\n"
                    "Report Text: $message";
                bloc.add(SubmitReport(fullReportText));
              }
            },
            child: Text(loc.submit, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmDialog(BuildContext context, Flashcard card) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.box1),
            const SizedBox(width: 8),
            Text(loc.warning, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'This card is currently in Spaced Repetition stage ${card.progress.currentBox}. '
          'Do you want to reset its progress to Stage 1?\n\n'
          '• Yes: Reset progress to Stage 1 and show the card.\n'
          '• No: Keep current progress and show the card.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
            },
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<FlashcardBloc>().add(ResetCardProgressEvent(card.cardNumber));
            },
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
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
    return BlocProvider<FlashcardBloc>(
      create: (_) {
        final bloc = di.sl<FlashcardBloc>()
          ..add(LoadFlashcardQueue(widget.courseId, isTodayReview: widget.isTodayReview));
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
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.courseTitle,
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
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

              final card = state.currentCard;
              if (card != null) {
                if (_lastCardNumber != card.cardNumber) {
                  _lastCardNumber = card.cardNumber;
                  _selectedOptionIndex = null;
                }

                final currentBox = card.progress.currentBox;
                if (currentBox >= 2 && currentBox <= 5) {
                  if (_lastPromptedCardNumber != card.cardNumber) {
                    _lastPromptedCardNumber = card.cardNumber;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showResetConfirmDialog(context, card);
                    });
                  }
                }
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
            final loc = AppLocalizations.of(context);

            if (state is FlashcardLoading) {
              return Center(child: CircularProgressIndicator(color: AppColors.primary));
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
                        child: Icon(Icons.emoji_events, color: AppColors.secondary, size: 64),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        loc.studyLoopComplete,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        loc.studyLoopCompleteDesc,
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
                        child: Text(loc.backToCourses, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.courseTitle,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                state.isFavorited ? Icons.star : Icons.star_border,
                                color: state.isFavorited ? AppColors.box2 : AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => context.read<FlashcardBloc>().add(ToggleFavorite()),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: boxColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: boxColor.withOpacity(0.4), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(color: boxColor, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getBoxName(context, currentBox),
                                    style: TextStyle(color: boxColor, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _showJumpDialog(context, context.read<FlashcardBloc>()),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Text(
                                  '${loc.cardPrefix}${card.cardNumber}',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 2. Rotating Center Card flanked by arrows
                  Expanded(
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios, size: 28, color: state.currentIndex > 0 ? AppColors.primary : AppColors.textSecondary.withOpacity(0.2)),
                          onPressed: state.currentIndex > 0
                              ? () => context.read<FlashcardBloc>().add(PrevCard())
                              : null,
                        ),
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                context.read<FlashcardBloc>().add(FlipFlashcard());
                              },
                              onHorizontalDragEnd: (details) {
                                if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 300) {
                                  context.read<FlashcardBloc>().add(FlipFlashcard());
                                }
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
                        IconButton(
                          icon: Icon(Icons.arrow_forward_ios, size: 28, color: state.currentIndex < state.queue.length - 1 ? AppColors.primary : AppColors.textSecondary.withOpacity(0.2)),
                          onPressed: state.currentIndex < state.queue.length - 1
                              ? () => context.read<FlashcardBloc>().add(NextCard())
                              : null,
                        ),
                      ],
                    ),
                  ),

                  // 3. Persistent Action buttons (Know / Don't Know & Report)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12, top: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
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
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.close, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(loc.dontKnow, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(loc.iKnowIt, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          ),
                          onPressed: () => _showReportDialog(context, context.read<FlashcardBloc>(), card),
                          icon: const Icon(Icons.flag_outlined, size: 16),
                          label: Text(loc.submitReport),
                        ),
                      ],
                    ),
                  ),

                  // 4. Fixed Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.5),
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Center(
                        child: Text(
                          '${state.currentIndex + 1} / ${state.queue.length}',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
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
    final loc = AppLocalizations.of(context);
    final prefs = di.sl<SharedPreferences>();
    final username = prefs.getString('user_username') ?? 'User';
    final mobile = prefs.getString('user_mobile_number') ?? '';
    final maskedMobile = mobile.length > 6 
        ? '${mobile.substring(0, mobile.length - 7)}***${mobile.substring(mobile.length - 4)}' 
        : mobile;
    final watermarkText = '$username ($maskedMobile)';

    return Stack(
      children: [
        Container(
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
                isFront ? loc.questionLabel : loc.answerLabel,
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isFront ? card.questionText : card.answerText,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20 * _fontScale,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (isFront && card.options != null && card.options!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () {}, // Intercept taps to prevent flipping the card
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: card.options!.asMap().entries.map((entry) {
                                final index = entry.key;
                                final text = entry.value;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedOptionIndex == index
                                          ? AppColors.primary
                                          : AppColors.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: RadioListTile<int>(
                                    title: Text(
                                      text,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 15 * _fontScale,
                                      ),
                                    ),
                                    value: index,
                                    groupValue: _selectedOptionIndex,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedOptionIndex = val;
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.trailing,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
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
                    icon: Icon(Icons.volume_up, color: AppColors.primary, size: 28),
                    onPressed: () => _playAudio(card.audioUrl!),
                  ),
                ),
              ],
            ],
          ),
        ),
        IgnorePointer(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: Transform.rotate(
                angle: -0.4,
                child: Text(
                  watermarkText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.04),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
