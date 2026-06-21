import 'package:flutter/material.dart';
import 'package:mobile_app/app/theme.dart';
import 'package:mobile_app/core/database/database_helper.dart';
import 'package:mobile_app/injection_container.dart' as di;
import 'create_custom_card_screen.dart';

class CustomCardsScreen extends StatefulWidget {
  const CustomCardsScreen({Key? key}) : super(key: key);

  @override
  State<CustomCardsScreen> createState() => _CustomCardsScreenState();
}

class _CustomCardsScreenState extends State<CustomCardsScreen> with SingleTickerProviderStateMixin {
  late DatabaseHelper _databaseHelper;
  List<Map<String, dynamic>> _customCards = [];
  bool _isLoading = true;

  // Study Mode fields
  int _studyIndex = 0;
  bool _showAnswer = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _databaseHelper = di.sl<DatabaseHelper>();
    _tabController = TabController(length: 2, vsync: this);
    _loadCustomCards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomCards() async {
    setState(() => _isLoading = true);
    try {
      final db = await _databaseHelper.localDatabase;
      final results = await db.query('user_created_cards', orderBy: 'id DESC');
      setState(() {
        _customCards = results;
        _isLoading = false;
        _showAnswer = false;
        if (_studyIndex >= results.length) {
          _studyIndex = 0;
        }
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCard(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Custom Card', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to delete this card? This action cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = await _databaseHelper.localDatabase;
      await db.delete('user_created_cards', where: 'id = ?', whereArgs: [id]);
      _loadCustomCards();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card deleted.'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Custom Cards',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () async {
              final created = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateCustomCardScreen()),
              );
              if (created == true) {
                _loadCustomCards();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'All Cards'),
            Tab(icon: Icon(Icons.play_circle_outline), text: 'Study Mode'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_card, size: 64, color: AppColors.secondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No Custom Cards Found',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your own custom cards and study them locally. Privacy locked on your device.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateCustomCardScreen()),
                );
                if (created == true) {
                  _loadCustomCards();
                }
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create First Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardsListTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _customCards.length,
      itemBuilder: (context, index) {
        final card = _customCards[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: AppColors.surface.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
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
                        style: const TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      onPressed: () => _deleteCard(card['id'] as int),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('QUESTION', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(card['question_text'] as String, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF333E56), height: 1),
                const SizedBox(height: 12),
                const Text('ANSWER', style: TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(card['answer_text'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudyModeTab() {
    final card = _customCards[_studyIndex];
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                card['course_title'] as String? ?? 'Custom Card',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                'Card ${_studyIndex + 1}/${_customCards.length}',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
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
                        color: _showAnswer ? AppColors.secondary : AppColors.primary,
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
                            _showAnswer ? 'ANSWER' : 'QUESTION',
                            style: TextStyle(
                              color: _showAnswer ? AppColors.secondary : AppColors.primary,
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
                                      ? card['answer_text'] as String
                                      : card['question_text'] as String,
                                  style: const TextStyle(
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
                          const Icon(Icons.touch_app, size: 16, color: AppColors.textSecondary),
                          const SizedBox(height: 4),
                          const Text('Tap card to flip', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
                onPressed: () {
                  setState(() {
                    _showAnswer = false;
                    _studyIndex = (_studyIndex - 1 + _customCards.length) % _customCards.length;
                  });
                },
              ),
              const Text('Tap card to show answer', style: TextStyle(color: AppColors.textSecondary)),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: AppColors.primary),
                onPressed: () {
                  setState(() {
                    _showAnswer = false;
                    _studyIndex = (_studyIndex + 1) % _customCards.length;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
