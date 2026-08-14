import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/constants/app_nav_icons.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_bloc.dart';
import 'package:mobile_app/features/config/presentation/bloc/config_state.dart';
import 'package:mobile_app/injection_container.dart' as di;
import 'create_custom_card_screen.dart';

class CustomCardsScreen extends StatefulWidget {
  final String courseTitle;
  const CustomCardsScreen({Key? key, required this.courseTitle}) : super(key: key);

  @override
  State<CustomCardsScreen> createState() => _CustomCardsScreenState();
}

class _CustomCardsScreenState extends State<CustomCardsScreen> with TickerProviderStateMixin {
  late DatabaseHelper _databaseHelper;
  List<Map<String, dynamic>> _customCards = [];
  bool _isLoading = true;

  // Study Mode fields
  int _studyIndex = 0;
  bool _showAnswer = false;
  late TabController _tabController;
  late AnimationController _flipController;
  
  double _fontScale = 1.0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingCustom = false;

  @override
  void initState() {
    super.initState();
    _databaseHelper = di.sl<DatabaseHelper>();
    _tabController = TabController(length: 2, vsync: this);
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadCustomCards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _flipController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadCustomCards() async {
    setState(() => _isLoading = true);
    try {
      final db = await _databaseHelper.localDatabase;
      final results = await db.query(
        'user_created_cards',
        where: 'course_title = ?',
        whereArgs: [widget.courseTitle],
        orderBy: 'id DESC',
      );
      final prefs = di.sl<SharedPreferences>();
      setState(() {
        _customCards = results;
        _isLoading = false;
        _showAnswer = false;
        _fontScale = prefs.getDouble('flashcard_font_scale') ?? 1.0;
        if (_studyIndex >= results.length) {
          _studyIndex = 0;
        }
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCard(int id) async {
    final loc = AppLocalizations.of(context);
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(loc.translate('delete_custom_card_title'), style: TextStyle(color: AppColors.textPrimary)),
        content: Text(loc.translate('delete_custom_card_confirm'), style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isFa ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = await _databaseHelper.localDatabase;
      // Get paths to delete physical files too
      final card = _customCards.firstWhere((c) => c['id'] == id);
      final imgPath = card['image_path'] as String?;
      final audPath = card['audio_path'] as String?;
      
      if (imgPath != null && File(imgPath).existsSync()) {
        try { File(imgPath).deleteSync(); } catch (_) {}
      }
      if (audPath != null && File(audPath).existsSync()) {
        try { File(audPath).deleteSync(); } catch (_) {}
      }

      await db.delete('user_created_cards', where: 'id = ?', whereArgs: [id]);
      _loadCustomCards();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('card_deleted')), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _editCard(Map<String, dynamic> card) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCustomCardScreen(
          courseTitle: widget.courseTitle,
          cardToEdit: card,
        ),
      ),
    );
    if (updated == true) {
      _loadCustomCards();
    }
  }

  Future<void> _playCustomAudio(String path) async {
    try {
      if (_isPlayingCustom) {
        await _audioPlayer.stop();
        setState(() => _isPlayingCustom = false);
      } else {
        setState(() => _isPlayingCustom = true);
        await _audioPlayer.play(DeviceFileSource(path));
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() => _isPlayingCustom = false);
          }
        });
      }
    } catch (_) {
      setState(() => _isPlayingCustom = false);
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.courseTitle,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppColors.primary),
            onPressed: () async {
              final created = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateCustomCardScreen(courseTitle: widget.courseTitle),
                ),
              );
              if (created == true) {
                _loadCustomCards();
              }
            },
          ),
        ],
        bottom: _customCards.isEmpty
            ? null
            : TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(icon: const Icon(Icons.featured_play_list_rounded, size: 24), text: loc.allCards),
                  Tab(icon: const Icon(Icons.play_circle_fill_rounded, size: 24), text: loc.studyMode),
                ],
              ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _customCards.isEmpty
              ? _buildEmptyState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCardsListTab(),
                    _buildStudyModeTab(),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_card, size: 64, color: AppColors.secondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              loc.noCustomCardsFound,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              loc.createCustomCardsEmptyDesc,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateCustomCardScreen(courseTitle: widget.courseTitle),
                  ),
                );
                if (created == true) {
                  _loadCustomCards();
                }
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(loc.createFirstCard, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardsListTab() {
    final loc = AppLocalizations.of(context);
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _customCards.length,
      itemBuilder: (context, index) {
        final card = _customCards[index];
        final imgPath = card['image_path'] as String?;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: AppColors.surface.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _studyIndex = index;
                _showAnswer = false;
              });
              _tabController.animateTo(1); // Switch to Study Mode tab
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          card['course_title'] as String? ?? 'Custom Card',
                          style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                            onPressed: () => _editCard(card),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                            onPressed: () => _deleteCard(card['id'] as int),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(loc.questionLabel.toUpperCase(), style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (imgPath != null && File(imgPath).existsSync()) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(imgPath),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                  Text(card['question_text'] as String, style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                  const SizedBox(height: 12),
                  Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 12),
                  Text(loc.answerLabel.toUpperCase(), style: TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(card['answer_text'] as String, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardFace(Map<String, dynamic> card, String? imgPath, String? audPath, {required bool isFront}) {
    final loc = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFront ? AppColors.primary : AppColors.secondary,
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
              isFront ? loc.questionLabel.toUpperCase() : loc.answerLabel.toUpperCase(),
              style: TextStyle(
                color: isFront ? AppColors.primary : AppColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            
            // Display attached card image if present
            if (imgPath != null && File(imgPath).existsSync()) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(imgPath),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
            
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isFront
                            ? card['question_text'] as String
                            : card['answer_text'] as String,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20 * _fontScale,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isFront && card['options'] != null && (card['options'] as String).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ..._buildCustomCardOptions(card['options'] as String),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            
            // Audio control buttons
            if (audPath != null && File(audPath).existsSync()) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(_isPlayingCustom ? Icons.pause : Icons.volume_up, color: AppColors.primary, size: 24),
                  onPressed: () => _playCustomAudio(audPath),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            Icon(Icons.touch_app, size: 16, color: AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(loc.tapCardToFlip, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _goToPrevCard() {
    if (_studyIndex > 0) {
      _audioPlayer.stop();
      _flipController.reset();
      setState(() {
        _isPlayingCustom = false;
        _showAnswer = false;
        _studyIndex--;
      });
    }
  }

  void _goToNextCard() {
    if (_studyIndex < _customCards.length - 1) {
      _audioPlayer.stop();
      _flipController.reset();
      setState(() {
        _isPlayingCustom = false;
        _showAnswer = false;
        _studyIndex++;
      });
    }
  }

  Widget _buildStudyModeTab() {
    final loc = AppLocalizations.of(context);
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final configState = context.watch<ConfigBloc>().state;
    final iconStyle = configState is ConfigLoaded
        ? configState.config.cardNavIconStyle
        : (configState is ConfigMaintenance ? configState.config.cardNavIconStyle : 'chevron');
    final card = _customCards[_studyIndex];
    final imgPath = card['image_path'] as String?;
    final audPath = card['audio_path'] as String?;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  card['course_title'] as String? ?? 'Custom Card',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                Text(
                  isFa ? 'کارت ${_studyIndex + 1} از ${_customCards.length}' : 'Card ${_studyIndex + 1}/${_customCards.length}',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_showAnswer) {
                          _flipController.reverse();
                        } else {
                          _flipController.forward();
                        }
                        setState(() {
                          _showAnswer = !_showAnswer;
                        });
                      },
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! < -300) {
                            _goToNextCard();
                          } else if (details.primaryVelocity! > 300) {
                            _goToPrevCard();
                          }
                        }
                      },
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
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
                                      child: _buildCardFace(card, imgPath, audPath, isFront: false),
                                    )
                                  : _buildCardFace(card, imgPath, audPath, isFront: true),
                            );
                          },
                        ),
                      ),
                    ),

                    // Left Navigation Overlay Button (Next Card)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 48,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _studyIndex < _customCards.length - 1 ? _goToNextCard : null,
                        child: Container(
                          color: Colors.transparent,
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (_studyIndex < _customCards.length - 1 ? AppColors.primary : Colors.grey).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Icon(
                                  AppNavIcons.getLeftIcon(iconStyle),
                                  size: 24,
                                  color: _studyIndex < _customCards.length - 1 ? AppColors.primary : AppColors.textSecondary.withOpacity(0.3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Right Navigation Overlay Button (Previous Card)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 48,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _studyIndex > 0 ? _goToPrevCard : null,
                        child: Container(
                          color: Colors.transparent,
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (_studyIndex > 0 ? AppColors.primary : Colors.grey).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Icon(
                                  AppNavIcons.getRightIcon(iconStyle),
                                  size: 24,
                                  color: _studyIndex > 0 ? AppColors.primary : AppColors.textSecondary.withOpacity(0.3),
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
            ),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _studyIndex < _customCards.length - 1 ? AppColors.primary : Colors.grey.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _studyIndex < _customCards.length - 1 ? _goToNextCard : null,
                    icon: Icon(AppNavIcons.getLeftIcon(iconStyle), size: 18),
                    label: Text(isFa ? 'بعدی' : 'Next', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Flexible(
                    child: Text(
                      isFa ? 'برای دیدن پاسخ روی کارت بزنید' : 'Tap card to show answer',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_studyIndex > 0 ? AppColors.primary : Colors.grey).withOpacity(0.15),
                      foregroundColor: _studyIndex > 0 ? AppColors.primary : AppColors.textSecondary.withOpacity(0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _studyIndex > 0 ? _goToPrevCard : null,
                    icon: Icon(AppNavIcons.getRightIcon(iconStyle), size: 18),
                    iconAlignment: IconAlignment.end,
                    label: Text(isFa ? 'قبلی' : 'Previous', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCustomCardOptions(String optionsJson) {
    try {
      final List<dynamic> options = jsonDecode(optionsJson);
      if (options.isEmpty) return [];

      return options.map((opt) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            opt.toString(),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13 * _fontScale),
            textAlign: TextAlign.center,
          ),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
