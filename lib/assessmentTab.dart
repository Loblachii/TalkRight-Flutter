import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'progress_manager.dart';
import 'stage1SoundMatch.dart';
import 'stage1BlendBuilder.dart';
import 'stage1BeginEndSound.dart';
import 'stage1VowelListener.dart';
import 'stage2DigraphDetective.dart';
import 'stage2VowelTeamMatch.dart';
import 'stage2SyllableTap.dart';
import 'stage2WordFamilySort.dart';
import 'stage3SentenceListener.dart';
import 'stage3QuestionStatement.dart';
import 'stage3PhraseBuilder.dart';
import 'stage3MeaningMatch.dart';

class AssessmentTab extends StatefulWidget {
  const AssessmentTab({super.key});

  @override
  State<AssessmentTab> createState() => _AssessmentTabState();
}

class _AssessmentTabState extends State<AssessmentTab>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  Map<String, int> _gameAttempts = {};
  Map<String, bool> _gameCompleted = {};
  final AudioPlayer _notificationPlayer = AudioPlayer();
  bool _isNavigating = false;

  // ── Stage unlock: each stage locked by default, unlocks when its course is done ──
  bool _isStageUnlocked(String stageId) {
    final pm = ProgressManager();
    switch (stageId) {
      case 'stage1':
        for (int i = 0; i < 6; i++) {
          if (!pm.isLessonFullyCompleted('course_one', i)) return false;
        }
        return true;
      case 'stage2':
        for (int i = 0; i < 6; i++) {
          if (!pm.isLessonFullyCompleted('course_two', i)) return false;
        }
        return true;
      case 'stage3':
        for (int i = 0; i < 6; i++) {
          if (!pm.isLessonFullyCompleted('course_three', i)) return false;
        }
        return true;
      default:
        return false;
    }
  }

  void _showAssessmentLockedSnackBar(String stageId) {
    final messages = {
      'stage1': 'Complete all Course 1 lessons to unlock Stage 1!',
      'stage2': 'Complete all Course 2 lessons to unlock Stage 2!',
      'stage3': 'Complete all Course 3 lessons to unlock Stage 3!',
    };
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        backgroundColor: _getCurrentStageColor(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.lock, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                messages[stageId] ?? 'Complete the required course first!',
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isGameUnlocked(String gameId) {
    final stageGames = _getStageGameIds(_getStageForGame(gameId));
    final index = stageGames.indexOf(gameId);
    if (index == 0) return true;
    return _gameCompleted[stageGames[index - 1]] == true;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _loadProgress();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _notificationPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (String gameId in _getAllGameIds()) {
        _gameAttempts[gameId] = prefs.getInt('${gameId}_failed') ?? 0;
        _gameCompleted[gameId] = prefs.getBool('${gameId}_completed') ?? false;
      }
    });
  }

  Future<void> _saveProgress(String gameId, {required bool passed}) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyCompleted = _gameCompleted[gameId] ?? false;

    if (passed) {
      if (!alreadyCompleted) {
        await prefs.setBool('${gameId}_completed', true);
        setState(() {
          _gameCompleted[gameId] = true;
        });
      }
    } else {
      if (!alreadyCompleted) {
        int failed = (_gameAttempts[gameId] ?? 0) + 1;
        await prefs.setInt('${gameId}_failed', failed);
        setState(() {
          _gameAttempts[gameId] = failed;
        });
      }
    }
    await _syncStageProgress();
  }

  Future<void> _syncStageProgress() async {
    final pm = ProgressManager();
    final stages = {
      'stage1': [
        'stage1_sound_match',
        'stage1_blend_builder',
        'stage1_begin_end_sound',
        'stage1_vowel_listener',
      ],
      'stage2': [
        'stage2_digraph_detective',
        'stage2_vowel_team_match',
        'stage2_syllable_tap',
        'stage2_word_family_sort',
      ],
      'stage3': [
        'stage3_sentence_listener',
        'stage3_question_statement',
        'stage3_phrase_builder',
        'stage3_meaning_match',
      ],
    };
    for (final entry in stages.entries) {
      int completed = 0;
      for (final id in entry.value) {
        if (_gameCompleted[id] == true) completed++;
      }
      await pm.updateAssessmentStageProgress(entry.key, completed);
    }
  }

  List<String> _getAllGameIds() {
    return [
      'stage1_sound_match',
      'stage1_blend_builder',
      'stage1_begin_end_sound',
      'stage1_vowel_listener',
      'stage2_digraph_detective',
      'stage2_vowel_team_match',
      'stage2_syllable_tap',
      'stage2_word_family_sort',
      'stage3_sentence_listener',
      'stage3_question_statement',
      'stage3_phrase_builder',
      'stage3_meaning_match',
    ];
  }

  void _navigateBack() {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    _animationController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Color _getInterpolatedThemeColor(double offset) {
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFF9C27B0),
    ];
    if (offset <= 0) return colors[0];
    if (offset >= 2) return colors[2];

    int lowerIndex = offset.floor();
    int upperIndex = lowerIndex + 1;
    double t = offset - lowerIndex;

    return Color.lerp(colors[lowerIndex], colors[upperIndex], t)!;
  }

  List<Color> _getInterpolatedGradient(double offset) {
    final gradients = [
      [const Color(0xFFB6E8C1), const Color(0xFFE8F5E9)],
      [const Color(0xFFB6DAE8), const Color(0xFFE3F2FD)],
      [const Color(0xFFE8B6E8), const Color(0xFFFCE4EC)],
    ];

    if (offset <= 0) return gradients[0];
    if (offset >= 2) return gradients[2];

    int lowerIndex = offset.floor();
    int upperIndex = lowerIndex + 1;
    double t = offset - lowerIndex;

    return [
      Color.lerp(gradients[lowerIndex][0], gradients[upperIndex][0], t)!,
      Color.lerp(gradients[lowerIndex][1], gradients[upperIndex][1], t)!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 400).clamp(0.75, 1.3).toDouble();
    final topColor = const Color.fromARGB(255, 255, 189, 142);

    return PopScope(
      canPop: !_isNavigating,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _navigateBack();
        }
      },
      child: SlideTransition(
        position: _slideAnimation,
        child: Scaffold(
          backgroundColor: topColor,
          body: SafeArea(
            bottom: false,
            child: AnimatedBuilder(
              animation: _tabController.animation ?? _tabController,
              builder: (context, child) {
                final double offset =
                    _tabController.animation?.value ??
                    _tabController.index.toDouble();
                final Color activeThemeColor = _getInterpolatedThemeColor(
                  offset,
                );
                final List<Color> activeGradient = _getInterpolatedGradient(
                  offset,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      color: topColor,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _TapAnimatedButton(
                                  onTap: _navigateBack,
                                  child: Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          offset: const Offset(4, 4),
                                          blurRadius: 15,
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                    child: Image.asset(
                                      'assets/images/backButton.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Assessment Games',
                                  style: TextStyle(
                                    color: const Color(0xFF2D2D2D),
                                    fontFamily: 'Fredoka',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 22 * scale,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                if (_isCurrentStageComplete())
                                  _TapAnimatedButton(
                                    onTap: _showCompletionSummary,
                                    child: Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        color: activeThemeColor,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: activeThemeColor.withOpacity(
                                              0.4,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.emoji_events,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(width: 54),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          TabBar(
                            controller: _tabController,
                            indicatorColor: activeThemeColor,
                            indicatorWeight: 4,
                            isScrollable: screenWidth < 340,
                            labelColor: activeThemeColor,
                            unselectedLabelColor: Colors.black54,
                            labelStyle: TextStyle(
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w600,
                              fontSize: 14 * scale,
                              letterSpacing: 0.2,
                            ),
                            unselectedLabelStyle: TextStyle(
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w400,
                              fontSize: 14 * scale,
                              letterSpacing: 0.2,
                            ),
                            tabs: [
                              Tab(
                                icon: Icon(Icons.music_note, size: 22 * scale),
                                text: 'Stage 1',
                              ),
                              Tab(
                                icon: Icon(Icons.text_fields, size: 22 * scale),
                                text: 'Stage 2',
                              ),
                              Tab(
                                icon: Icon(Icons.chat_bubble, size: 22 * scale),
                                text: 'Stage 3',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: activeGradient[0],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(22),
                                topRight: Radius.circular(22),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: activeGradient,
                          ),
                        ),
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).padding.bottom + 8,
                        ),
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildStage1Games(),
                            _buildStage2Games(),
                            _buildStage3Games(),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageLockOverlay(
    String title,
    String message,
    Color color,
    IconData stageIcon,
  ) {
    final scale =
        (MediaQuery.of(context).size.width / 400).clamp(0.75, 1.3).toDouble();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(24 * scale),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    stageIcon,
                    size: 56 * scale,
                    color: color.withOpacity(0.3),
                  ),
                  Icon(Icons.lock, size: 36 * scale, color: color),
                ],
              ),
            ),
            SizedBox(height: 24 * scale),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22 * scale,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12 * scale),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 20 * scale,
                vertical: 14 * scale,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: color, size: 20 * scale),
                  SizedBox(width: 10 * scale),
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14 * scale,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStage1Games() {
    final bool stageUnlocked = _isStageUnlocked('stage1');
    final double pad = MediaQuery.of(context).size.width * 0.05;

    return stageUnlocked
        ? Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 20),
              child: _buildStageHeader(
                'Sound-Level Games',
                'Practice recognizing individual sounds',
                Icons.hearing,
                const Color(0xFF4CAF50),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGameCard(
                      gameId: 'stage1_sound_match',
                      title: 'Sound Match',
                      description:
                          'Listen to a sound and tap the correct letter',
                      icon: Icons.touch_app,
                      color: const Color(0xFF4CAF50),
                      skill: 'Phoneme Recognition',
                      onTap:
                          () => _navigateToGame(
                            const Stage1SoundMatch(),
                            'stage1_sound_match',
                          ),
                    ),
                    _buildGameCard(
                      gameId: 'stage1_blend_builder',
                      title: 'Blend Builder',
                      description:
                          'Listen to a word and drag letters to form it',
                      icon: Icons.extension,
                      color: const Color(0xFF4CAF50),
                      skill: 'Sound Blending',
                      onTap:
                          () => _navigateToGame(
                            const Stage1BlendBuilder(),
                            'stage1_blend_builder',
                          ),
                    ),
                    _buildGameCard(
                      gameId: 'stage1_begin_end_sound',
                      title: 'Beginning vs Ending',
                      description:
                          'Identify if a sound is at the beginning or end',
                      icon: Icons.compare_arrows,
                      color: const Color(0xFF4CAF50),
                      skill: 'Sound Position Awareness',
                      onTap:
                          () => _navigateToGame(
                            const Stage1BeginEndSound(),
                            'stage1_begin_end_sound',
                          ),
                    ),
                    _buildGameCard(
                      gameId: 'stage1_vowel_listener',
                      title: 'Vowel Listener',
                      description: 'Distinguish between short and long vowels',
                      icon: Icons.audiotrack,
                      color: const Color(0xFF4CAF50),
                      skill: 'Vowel Discrimination',
                      onTap:
                          () => _navigateToGame(
                            const Stage1VowelListener(),
                            'stage1_vowel_listener',
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
        : _buildStageLockOverlay(
          'Stage 1 Locked',
          'Complete all lessons in\nCourse 1 (Basic Sound & Blending)\nto unlock!',
          const Color(0xFF4CAF50),
          Icons.hearing,
        );
  }

  Widget _buildStage2Games() {
    final bool stageUnlocked = _isStageUnlocked('stage2');
    final double pad = MediaQuery.of(context).size.width * 0.05;

    return stageUnlocked
        ? Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 20),
              child: _buildStageHeader(
                'Word-Level Games',
                'Practice recognizing word patterns',
                Icons.spellcheck,
                const Color(0xFF2196F3),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGameCard(
                      gameId: 'stage2_digraph_detective',
                      title: 'Digraph Detective',
                      description: 'Listen and identify the digraph in words',
                      icon: Icons.search,
                      color: const Color(0xFF2196F3),
                      skill: 'Digraph Awareness',
                      onTap:
                          () => _navigateToGame(
                            const Stage2DigraphDetective(),
                            'stage2_digraph_detective',
                          ),
                    ),
                    _buildGameCard(
                      gameId: 'stage2_vowel_team_match',
                      title: 'Vowel Team Match',
                      description: 'Match words with their vowel teams',
                      icon: Icons.group,
                      color: const Color(0xFF2196F3),
                      skill: 'Vowel Accuracy',
                      onTap:
                          () => _navigateToGame(
                            const Stage2VowelTeamMatch(),
                            'stage2_vowel_team_match',
                          ),
                    ),
                    _buildGameCard(
                      gameId: 'stage2_syllable_tap',
                      title: 'Syllable Tap',
                      description: 'Tap the stressed syllable in words',
                      icon: Icons.touch_app,
                      color: const Color(0xFF2196F3),
                      skill: 'Stress Awareness',
                      onTap:
                          () => _navigateToGame(
                            const Stage2SyllableTap(),
                            'stage2_syllable_tap',
                          ),
                    ),
                    _buildGameCard(
                      gameId: 'stage2_word_family_sort',
                      title: 'Word Family Sort',
                      description: 'Sort words into rhyming groups',
                      icon: Icons.sort,
                      color: const Color(0xFF2196F3),
                      skill: 'Rhyming Patterns',
                      onTap:
                          () => _navigateToGame(
                            const Stage2WordFamilySort(),
                            'stage2_word_family_sort',
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
        : _buildStageLockOverlay(
          'Stage 2 Locked',
          'Complete all lessons in\nCourse 2 (Word Formation)\nto unlock!',
          const Color(0xFF2196F3),
          Icons.spellcheck,
        );
  }

  Widget _buildStage3Games() {
    final bool stageUnlocked = _isStageUnlocked('stage3');
    final double pad = MediaQuery.of(context).size.width * 0.05;

    return stageUnlocked
        ? Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 20),
              child: _buildStageHeader(
                'Sentence-Level Games',
                'Practice understanding connected speech',
                Icons.record_voice_over,
                const Color(0xFF9C27B0),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGameCard(
                      gameId: 'stage3_sentence_listener',
                      title: 'Sentence Listener',
                      description:
                          'Listen to a sentence and select matching image',
                      icon: Icons.image,
                      color: const Color(0xFF9C27B0),
                      skill: 'Sentence Comprehension',
                      onTap:
                          () => _navigateToGame(
                            const Stage3SentenceListener(),
                            'stage3_sentence_listener',
                          ),
                    ),
                    _buildGameCard(
                      gameId: 'stage3_question_statement',
                      title: 'Question or Statement?',
                      description: 'Identify if spoken text is a question',
                      icon: Icons.help_outline,
                      color: const Color(0xFF9C27B0),
                      skill: 'Intonation Recognition',
                      onTap:
                          () => _navigateToGame(
                            const Stage3QuestionStatement(),
                            'stage3_question_statement',
                          ),
                    ),
                    _buildGameCard(
                      gameId: 'stage3_phrase_builder',
                      title: 'Phrase Builder',
                      description: 'Arrange words to match heard phrases',
                      icon: Icons.view_module,
                      color: const Color(0xFF9C27B0),
                      skill: 'Connected Speech',
                      onTap:
                          () => _navigateToGame(
                            const Stage3PhraseBuilder(),
                            'stage3_phrase_builder',
                          ),
                    ),
                    _buildGameCard(
                      gameId: 'stage3_meaning_match',
                      title: 'Meaning Match',
                      description: 'Listen and choose the correct meaning',
                      icon: Icons.lightbulb,
                      color: const Color(0xFF9C27B0),
                      skill: 'Listening Comprehension',
                      onTap:
                          () => _navigateToGame(
                            const Stage3MeaningMatch(),
                            'stage3_meaning_match',
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
        : _buildStageLockOverlay(
          'Stage 3 Locked',
          'Complete all lessons in\nCourse 3 (Sentence, Phrases & Comprehension)\nto unlock!',
          const Color(0xFF9C27B0),
          Icons.record_voice_over,
        );
  }

  Widget _buildStageHeader(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final scale =
        (MediaQuery.of(context).size.width / 400).clamp(0.75, 1.3).toDouble();
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10 * scale),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28 * scale),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required String gameId,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String skill,
    required VoidCallback onTap,
  }) {
    bool completed = _gameCompleted[gameId] ?? false;
    bool locked = !_isGameUnlocked(gameId);
    final scale =
        (MediaQuery.of(context).size.width / 400).clamp(0.75, 1.3).toDouble();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: locked ? 0.5 : 1.0,
      child: Container(
        margin: EdgeInsets.only(bottom: 14 * scale),
        child: Material(
          borderRadius: BorderRadius.circular(20),
          elevation: locked ? 0 : 4,
          shadowColor: color.withOpacity(0.4),
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.all(16 * scale),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      completed
                          ? Colors.green
                          : locked
                          ? Colors.grey.shade300
                          : color.withOpacity(0.3),
                  width: completed ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52 * scale,
                    height: 52 * scale,
                    decoration: BoxDecoration(
                      color:
                          locked
                              ? Colors.grey.shade200
                              : color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14 * scale),
                    ),
                    child: Icon(
                      locked ? Icons.lock : icon,
                      color: locked ? Colors.grey : color,
                      size: 28 * scale,
                    ),
                  ),
                  SizedBox(width: 12 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 15 * scale,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      locked
                                          ? Colors.grey
                                          : const Color(0xFF2D2D2D),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            if (completed)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Done',
                                      style: TextStyle(
                                        fontFamily: 'Fredoka',
                                        fontSize: 10,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (locked)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock,
                                      color: Colors.grey,
                                      size: 12,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Locked',
                                      style: TextStyle(
                                        fontFamily: 'Fredoka',
                                        fontSize: 10,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          locked
                              ? 'Complete the previous game to unlock'
                              : description,
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[600],
                            height: 1.3,
                            letterSpacing: 0.1,
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        if (!locked)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8 * scale,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              skill,
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 10 * scale,
                                color: color,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Container(
                    padding: EdgeInsets.all(10 * scale),
                    decoration: BoxDecoration(
                      color: locked ? Colors.grey.shade300 : color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      locked ? Icons.lock : Icons.play_arrow,
                      color: Colors.white,
                      size: 22 * scale,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getStageForGame(String gameId) {
    if (gameId.startsWith('stage1_')) return 'stage1';
    if (gameId.startsWith('stage2_')) return 'stage2';
    return 'stage3';
  }

  String _getStageName(String stageId) {
    switch (stageId) {
      case 'stage1':
        return 'Stage 1';
      case 'stage2':
        return 'Stage 2';
      case 'stage3':
        return 'Stage 3';
      default:
        return stageId;
    }
  }

  List<String> _getStageGameIds(String stageId) {
    final stages = {
      'stage1': [
        'stage1_sound_match',
        'stage1_blend_builder',
        'stage1_begin_end_sound',
        'stage1_vowel_listener',
      ],
      'stage2': [
        'stage2_digraph_detective',
        'stage2_vowel_team_match',
        'stage2_syllable_tap',
        'stage2_word_family_sort',
      ],
      'stage3': [
        'stage3_sentence_listener',
        'stage3_question_statement',
        'stage3_phrase_builder',
        'stage3_meaning_match',
      ],
    };
    return stages[stageId] ?? [];
  }

  bool _isStageComplete(String stageId) {
    return _getStageGameIds(stageId).every((id) => _gameCompleted[id] == true);
  }

  String _getCurrentStageId() {
    switch (_tabController.index) {
      case 0:
        return 'stage1';
      case 1:
        return 'stage2';
      case 2:
        return 'stage3';
      default:
        return 'stage1';
    }
  }

  Color _getCurrentStageColor() {
    switch (_tabController.index) {
      case 0:
        return const Color(0xFF4CAF50);
      case 1:
        return const Color(0xFF2196F3);
      case 2:
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  bool _isCurrentStageComplete() {
    return _isStageComplete(_getCurrentStageId());
  }

  void _showGameLockedSnackBar() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        backgroundColor: _getCurrentStageColor(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
        content: Row(
          children: const [
            Icon(Icons.lock, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Complete the previous game to unlock this!',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompletionSummary() {
    final stageId = _getCurrentStageId();
    final stageName = _getStageName(stageId);
    final stageColor = _getCurrentStageColor();
    final gameIds = _getStageGameIds(stageId);

    final gameNames = {
      'stage1_sound_match': 'Sound Match',
      'stage1_blend_builder': 'Blend Builder',
      'stage1_begin_end_sound': 'Beginning vs Ending',
      'stage1_vowel_listener': 'Vowel Listener',
      'stage2_digraph_detective': 'Digraph Detective',
      'stage2_vowel_team_match': 'Vowel Team Match',
      'stage2_syllable_tap': 'Syllable Tap',
      'stage2_word_family_sort': 'Word Family Sort',
      'stage3_sentence_listener': 'Sentence Listener',
      'stage3_question_statement': 'Question or Statement?',
      'stage3_phrase_builder': 'Phrase Builder',
      'stage3_meaning_match': 'Meaning Match',
    };

    int totalFailed = 0;
    for (final id in gameIds) {
      totalFailed += _gameAttempts[id] ?? 0;
    }

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: stageColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: stageColor,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$stageName Complete!',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: stageColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All games finished!',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...gameIds.map((id) {
                    final failed = _gameAttempts[id] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: stageColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              gameNames[id] ?? id,
                              style: const TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          Text(
                            '$failed failed',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color:
                                  failed > 0
                                      ? Colors.red[400]
                                      : Colors.grey[400],
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close, size: 16, color: Colors.red[300]),
                        const SizedBox(width: 6),
                        Text(
                          'Total failed attempts: $totalFailed',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: stageColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showGameCompletedNotification(String gameId) {
    final stageId = _getStageForGame(gameId);
    final stageName = _getStageName(stageId);

    _notificationPlayer.play(AssetSource('sounds/correctAnswer.wav'));

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Great job! Game completed! 🎉',
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isStageComplete(stageId)) {
        _showStageCompletedNotification(stageName);
      }
    });
  }

  void _showStageCompletedNotification(String stageName) {
    _notificationPlayer.play(AssetSource('sounds/correctAnswer.wav'));

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$stageName Complete! All games finished! 🏆',
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF8F00),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _navigateToGame(Widget gameScreen, String gameId) async {
    final stageId = _getStageForGame(gameId);

    if (!_isStageUnlocked(stageId)) {
      _showAssessmentLockedSnackBar(stageId);
      return;
    }

    if (!_isGameUnlocked(gameId)) {
      _showGameLockedSnackBar();
      return;
    }

    final wasCompleted = _gameCompleted[gameId] == true;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => gameScreen),
    );

    if (result != null && result is Map<String, dynamic>) {
      final score = result['score'] as int? ?? 0;
      final passed = score >= 4;

      await _saveProgress(gameId, passed: passed);

      if (passed && !wasCompleted && mounted) {
        _showGameCompletedNotification(gameId);
      }
    }
  }
}

// ─── Reusable tap-bounce button wrapper ─────────────────────────────────────
class _TapAnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapAnimatedButton({required this.child, required this.onTap});

  @override
  State<_TapAnimatedButton> createState() => _TapAnimatedButtonState();
}

class _TapAnimatedButtonState extends State<_TapAnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.85,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.85,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.05,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0).then((_) => widget.onTap());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
