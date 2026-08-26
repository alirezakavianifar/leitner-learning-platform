import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:mobile_app/core/error/error_formatter.dart';
import 'package:mobile_app/core/constants/app_nav_icons.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_bloc.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_event.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_state.dart';
import 'package:mobile_app/features/config/domain/entities/remote_config.dart';
import 'package:mobile_app/injection_container.dart' as di;

class FlashcardStudyScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final int? initialCardNumber;
  final bool isTodayReview;
  final bool isFromFavorites;

  const FlashcardStudyScreen({
    Key? key,
    required this.courseId,
    required this.courseTitle,
    this.initialCardNumber,
    this.isTodayReview = false,
    this.isFromFavorites = false,
  }) : super(key: key);

  static Route route({
    required String courseId,
    required String courseTitle,
    bool isTodayReview = false,
    int? initialCardNumber,
    bool isFromFavorites = false,
  }) {
    return PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FlashcardStudyScreen(
          courseId: courseId,
          courseTitle: courseTitle,
          isTodayReview: isTodayReview,
          initialCardNumber: initialCardNumber,
          isFromFavorites: isFromFavorites,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  static Future<T?> open<T>(
    BuildContext context, {
    required String courseId,
    required String courseTitle,
    bool isTodayReview = false,
    int? initialCardNumber,
    bool isFromFavorites = false,
  }) {
    return Navigator.of(context, rootNavigator: true).push<T>(
      route(
        courseId: courseId,
        courseTitle: courseTitle,
        isTodayReview: isTodayReview,
        initialCardNumber: initialCardNumber,
        isFromFavorites: isFromFavorites,
      ) as Route<T>,
    );
  }


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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _applySecureMode();
        context.read<ConfigBloc>().add(LoadConfigEvent());
      }
    });
  }

  Future<void> _applySecureMode([RemoteConfig? config]) async {
    if (!kIsWeb) {
      final activeConfig = config ?? context.read<ConfigBloc>().state.config;
      final bool isProtected = activeConfig?.enableScreenshotProtection ?? true;
      if (isProtected) {
        await NoScreenshot.instance.screenshotOff();
      } else {
        await NoScreenshot.instance.screenshotOn();
      }
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
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.translate('play_audio_failed')),
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
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
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
          loc.translate('reset_progress_desc').replaceAll('{box}', card.progress.currentBox.toString()),
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              if (_lastCardNumber == null) {
                Navigator.pop(context);
              } else {
                context.read<FlashcardBloc>().add(ClearJumpWarning());
              }
            },
            child: Text(loc.translate('no_label')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<FlashcardBloc>().add(ResetCardProgressEvent(
                card.cardNumber,
                reason: widget.isFromFavorites ? 'FAVORITES' : 'JUMP',
              ));
            },
            child: Text(loc.translate('yes_label'), style: const TextStyle(color: Colors.white)),
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
      case 7:
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
      case 7:
        return loc.finished;
      default:
        return '${loc.box1} $box';
    }
  }

  Widget _buildWarningView(BuildContext context, Flashcard card) {
    final loc = AppLocalizations.of(context);
    return Container(
      color: Colors.black.withOpacity(0.55),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.box1.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: AppColors.box1, size: 48),
                ),
                const SizedBox(height: 20),
                Text(
                  loc.translate('warning'),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  loc.translate('reset_progress_desc').replaceAll('{box}', card.progress.currentBox.toString()),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (_lastCardNumber == null) {
                            Navigator.pop(context);
                          } else {
                            context.read<FlashcardBloc>().add(ClearJumpWarning());
                          }
                        },
                        child: Text(loc.translate('no_label'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          context.read<FlashcardBloc>().add(ResetCardProgressEvent(
                            card.cardNumber,
                            reason: widget.isFromFavorites ? 'FAVORITES' : 'JUMP',
                          ));
                        },
                        child: Text(loc.translate('yes_label'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FlashcardBloc>(
      create: (_) {
        final bloc = di.sl<FlashcardBloc>()
          ..add(LoadFlashcardQueue(
            widget.courseId,
            isTodayReview: widget.isTodayReview,
            initialCardNumber: widget.initialCardNumber,
            isFromFavorites: widget.isFromFavorites,
          ));
        return bloc;
      },
      child: BlocListener<ConfigBloc, ConfigState>(
        listener: (context, state) {
          if (state.config != null) {
            _applySecureMode(state.config);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: BlocConsumer<FlashcardBloc, FlashcardState>(
          listener: (context, state) {
            if (state is FlashcardQueueLoaded) {
              if (state.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppErrorFormatter.formatError(state.error!, context: context)),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
              if (state.reportMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).translate(state.reportMessage!)),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }

              final card = state.currentCard;
              if (card != null && state.jumpWarningCardNumber == null) {
                if (_lastCardNumber != card.cardNumber) {
                  _lastCardNumber = card.cardNumber;
                  _selectedOptionIndex = null;
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
              return Container(
                color: Colors.black.withOpacity(0.55),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              );
            }

            if (state is FlashcardFinished) {
              return Container(
                color: Colors.black.withOpacity(0.55),
                child: Center(
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loc.studyLoopCompleteDesc,
                          style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
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
                ),
              );
            }

            if (state is FlashcardError) {
              return Container(
                color: Colors.black.withOpacity(0.55),
                child: Center(
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppErrorFormatter.formatError(state.message, context: context),
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text(loc.backToCourses, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (state is FlashcardQueueLoaded) {
              if (state.jumpWarningCardNumber != null && state.jumpTargetCard != null) {
                return _buildWarningView(context, state.jumpTargetCard!);
              }

              final configState = context.watch<ConfigBloc>().state;
              final iconStyle = configState is ConfigLoaded
                  ? configState.config.cardNavIconStyle
                  : (configState is ConfigMaintenance ? configState.config.cardNavIconStyle : 'chevron');
              final iconSize = configState is ConfigLoaded
                  ? configState.config.cardNavIconSize
                  : (configState is ConfigMaintenance ? configState.config.cardNavIconSize : 20.0);
              final buttonDiameter = (iconSize + 12.0).clamp(32.0, 48.0);
              final tapZoneWidth = (buttonDiameter + 12.0).clamp(44.0, 60.0);

              final card = state.currentCard;
              if (card == null) return const SizedBox.shrink();

              final currentBox = card.progress.currentBox;
              final boxColor = _getBoxColor(currentBox);

              return Stack(
                children: [
                  // Dismissible backdrop detector
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: 8.0,
                          right: 8.0,
                          top: 16.0,
                          bottom: 24.0 + MediaQuery.of(context).padding.bottom,
                        ),
                        child: Center(
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 650),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Header (Inside the Card)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.courseTitle,
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
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
                                const SizedBox(height: 8),
                                const Divider(height: 1, thickness: 1),

                                // 2. Rotating Center Card Content with Isolated Nav Side Tap Zones
                                Container(
                                  height: 450,
                                  child: Stack(
                                    children: [
                                      // Flip animation container (Center tap area)
                                      GestureDetector(
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

                                      // Left Navigation Overlay Tap Zone (Next Card)
                                      Positioned(
                                        left: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: tapZoneWidth,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: state.currentIndex < state.queue.length - 1
                                              ? () => context.read<FlashcardBloc>().add(NextCard())
                                              : null,
                                          child: Container(
                                            color: Colors.transparent,
                                            child: Center(
                                              child: Container(
                                                width: buttonDiameter,
                                                height: buttonDiameter,
                                                decoration: BoxDecoration(
                                                  color: (state.currentIndex < state.queue.length - 1
                                                          ? AppColors.primary
                                                          : Colors.grey)
                                                      .withOpacity(0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Directionality(
                                                  textDirection: TextDirection.ltr,
                                                  child: Icon(
                                                    AppNavIcons.getLeftIcon(iconStyle),
                                                    size: iconSize,
                                                    color: state.currentIndex < state.queue.length - 1
                                                        ? AppColors.primary
                                                        : AppColors.textSecondary.withOpacity(0.3),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Right Navigation Overlay Tap Zone (Previous Card)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: tapZoneWidth,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: state.currentIndex > 0
                                              ? () => context.read<FlashcardBloc>().add(PrevCard())
                                              : null,
                                          child: Container(
                                            color: Colors.transparent,
                                            child: Center(
                                              child: Container(
                                                width: buttonDiameter,
                                                height: buttonDiameter,
                                                decoration: BoxDecoration(
                                                  color: (state.currentIndex > 0
                                                          ? AppColors.primary
                                                          : Colors.grey)
                                                      .withOpacity(0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Directionality(
                                                  textDirection: TextDirection.ltr,
                                                  child: Icon(
                                                    AppNavIcons.getRightIcon(iconStyle),
                                                    size: iconSize,
                                                    color: state.currentIndex > 0
                                                        ? AppColors.primary
                                                        : AppColors.textSecondary.withOpacity(0.3),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Divider(height: 1, thickness: 1),
                                const SizedBox(height: 12),

                                // 3. Persistent Action buttons inside the Card
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.error,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: () {
                                              context.read<FlashcardBloc>().add(const SubmitReview(isCorrect: false));
                                            },
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.close, color: Colors.white, size: 18),
                                                const SizedBox(width: 6),
                                                Text(loc.dontKnow, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.courseDownloaded,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: () {
                                              context.read<FlashcardBloc>().add(const SubmitReview(isCorrect: true));
                                            },
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.check, color: Colors.white, size: 18),
                                                const SizedBox(width: 6),
                                                Text(loc.iKnowIt, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      ),
                                      onPressed: () => _showReportDialog(context, context.read<FlashcardBloc>(), card),
                                      icon: const Icon(Icons.flag_outlined, size: 14),
                                      label: Text(loc.submitReport, style: const TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withOpacity(0.6), width: 1),
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
              const SizedBox(height: 16),
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
                        // Conditional image rendering (Front only, or both if needed)
                        if (isFront && card.imageUrl != null && card.imageUrl!.trim().isNotEmpty && _documentsPath != null) ...[
                          const SizedBox(height: 16),
                          FutureBuilder<String>(
                            future: Future.value(p.join(_documentsPath!, 'courses', widget.courseId, 'images', card.imageUrl!)),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && File(snapshot.data!).existsSync()) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      File(snapshot.data!),
                                      height: 160,
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
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
