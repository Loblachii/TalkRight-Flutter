import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

class Stage2WordFamilySort extends StatefulWidget {
  const Stage2WordFamilySort({super.key});

  @override
  State<Stage2WordFamilySort> createState() => _Stage2WordFamilySortState();
}

class _Stage2WordFamilySortState extends State<Stage2WordFamilySort>
    with TickerProviderStateMixin {
  int currentRound = 0;
  int correctSorts = 0;
  int totalRounds = 7;
  bool showFeedback = false;
  bool isPlaying = false;
  bool _timedOut = false;
  int _playCount = 0;
  final int _maxPlays = 4;
  int _highScore = 0;
  Timer? _timer;
  int _remainingSeconds = 45;
  bool _buttonsEnabled = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  late AnimationController _bounceController;

  final Random _random = Random();
  List<Map<String, dynamic>> _rounds = [];

  // Word families with their words
  Map<String, List<String>> _sortedWords = {};
  List<String> _unsortedWords = [];
  Set<String> _wrongWords = {};

  final List<Map<String, dynamic>> _allRounds = [
    {
      'families': {
        'at': ['cat', 'bat', 'hat'],
        'an': ['can', 'fan', 'man'],
      },
    },
    {
      'families': {
        'ig': ['pig', 'big', 'dig'],
        'it': ['sit', 'hit', 'fit'],
      },
    },
    {
      'families': {
        'op': ['top', 'hop', 'mop'],
        'ot': ['hot', 'dot', 'pot'],
      },
    },
    {
      'families': {
        'ug': ['bug', 'hug', 'rug'],
        'un': ['sun', 'run', 'fun'],
      },
    },
    {
      'families': {
        'ed': ['bed', 'red', 'fed'],
        'en': ['pen', 'ten', 'hen'],
      },
    },
    {
      'families': {
        'ake': ['cake', 'make', 'lake'],
        'ame': ['game', 'name', 'fame'],
      },
    },
    {
      'families': {
        'eep': ['deep', 'keep', 'beep'],
        'eel': ['feel', 'peel', 'heel'],
      },
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _initTts();
    _setupAnimations();
    _generateRounds();
    _setupCurrentRound();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRoundFlow(withInstruction: true);
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _handleTimeUp();
      }
    });
  }

  void _handleTimeUp() {
    setState(() {
      showFeedback = true;
      _timedOut = true;
      _buttonsEnabled = false;
    });
    _audioPlayer.play(AssetSource('sounds/incorrectAnswer.wav'));

    Timer(const Duration(milliseconds: 2000), () {
      if (currentRound < totalRounds - 1) {
        setState(() {
          currentRound++;
          showFeedback = false;
          _remainingSeconds = 45;
          _playCount = 0;
        });
        _setupCurrentRound();
        _startRoundFlow(withInstruction: true);
      } else {
        _showCompletionDialog();
      }
    });
  }

  void _setupAnimations() {
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.35);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _generateRounds() {
    _rounds = List.from(_allRounds)..shuffle(_random);
    _rounds = _rounds.take(totalRounds).toList();
  }

  void _setupCurrentRound() {
    if (currentRound >= _rounds.length) return;

    Map<String, List<String>> families = Map.from(
      _rounds[currentRound]['families'],
    );

    _sortedWords = {};
    _wrongWords = {};
    for (String family in families.keys) {
      _sortedWords[family] = [];
    }

    _unsortedWords = [];
    for (var words in families.values) {
      _unsortedWords.addAll(words);
    }
    _unsortedWords.shuffle(_random);
    _timedOut = false; // ← add at the end
  }

  Future<void> _startRoundFlow({bool withInstruction = false}) async {
    setState(() {
      _buttonsEnabled = false;
    });

    if (withInstruction) {
      Completer<void> ttsCompleter = Completer<void>();
      _flutterTts.setCompletionHandler(() {
        if (!ttsCompleter.isCompleted) ttsCompleter.complete();
      });
      await _flutterTts.speak('Drag words to their rhyming family');
      await ttsCompleter.future;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      setState(() {
        _buttonsEnabled = true;
      });
      _startTimer();
    }
  }

  Future<void> _playWord(String word) async {
    if (_playCount >= _maxPlays || !_buttonsEnabled) return;

    _playCount++;
    setState(() {
      isPlaying = true;
      _buttonsEnabled = false;
    });
    await _flutterTts.speak(word);
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      isPlaying = false;
      _buttonsEnabled = true;
    });
  }

  void _sortWord(String word, String family) {
    if (showFeedback || !_buttonsEnabled) return;

    Map<String, List<String>> correctFamilies = Map.from(
      _rounds[currentRound]['families'],
    );

    bool isCorrect = correctFamilies[family]?.contains(word) ?? false;

    setState(() {
      _unsortedWords.remove(word);
      _sortedWords[family]!.add(word);
      if (!isCorrect) {
        _wrongWords.add(word);
      }
    });

    _audioPlayer.play(
      AssetSource(
        isCorrect ? 'sounds/correctAnswer.wav' : 'sounds/incorrectAnswer.wav',
      ),
    );

    // Check if round is complete
    if (_unsortedWords.isEmpty) {
      _completeRound();
    }
  }

  void _completeRound() {
    bool allCorrect = _wrongWords.isEmpty;

    setState(() {
      showFeedback = true;
      if (allCorrect) correctSorts++;
      _buttonsEnabled = false;
    });

    _audioPlayer.play(
      AssetSource(
        allCorrect ? 'sounds/correctAnswer.wav' : 'sounds/incorrectAnswer.wav',
      ),
    );

    Timer(const Duration(milliseconds: 1500), () {
      if (currentRound < totalRounds - 1) {
        _timer?.cancel();
        setState(() {
          currentRound++;
          showFeedback = false;
          _remainingSeconds = 45;
          _playCount = 0;
        });
        _setupCurrentRound();
        _startRoundFlow(withInstruction: true);
      } else {
        _showCompletionDialog();
      }
    });
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('stage2_word_family_sort_high_score') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    if (correctSorts > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('stage2_word_family_sort_high_score', correctSorts);
      _highScore = correctSorts;
    }
  }

  String _getFeedbackMessage() {
    double percentage = correctSorts / totalRounds;
    if (percentage >= 0.9) return 'Amazing sorting skills!';
    if (percentage >= 0.7) return 'Great word family knowledge!';
    if (percentage >= 0.5) return 'Good effort! Try again to improve!';
    return 'Keep trying! Practice makes perfect!';
  }

  Future<void> _showCompletionDialog() async {
    _timer?.cancel();
    await _saveHighScore();
    final prefs = await SharedPreferences.getInstance();
    bool passed = correctSorts >= 4;
    int failedAttempts = prefs.getInt('stage2_word_family_sort_failed') ?? 0;
    if (!passed) failedAttempts += 1;
    String feedbackMessage = _getFeedbackMessage();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      passed
                          ? [const Color(0xFF42A5F5), const Color(0xFF1E88E5)]
                          : [const Color(0xFFEF9A9A), const Color(0xFFE57373)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    passed ? Icons.sort : Icons.sentiment_dissatisfied,
                    size: 70,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    passed ? 'Sorting Pro!' : 'Keep Practicing!',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      letterSpacing: 0.2,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.stars, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Score: $correctSorts / $totalRounds',
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            letterSpacing: 0.2,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.amber,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'High Score: $_highScore / $totalRounds',
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            letterSpacing: 0.2,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    feedbackMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      letterSpacing: 0.2,
                      fontSize: 14,
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            currentRound = 0;
                            correctSorts = 0;
                            showFeedback = false;
                            _remainingSeconds = 45;
                            _playCount = 0;
                          });
                          _generateRounds();
                          _setupCurrentRound();
                          _startRoundFlow(withInstruction: true);
                        },
                        icon: const Icon(Icons.replay),
                        label: const Text('Play Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor:
                              passed
                                  ? const Color(0xFF1E88E5)
                                  : const Color(0xFFE57373),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context, {
                            'completed': true,
                            'score': correctSorts,
                            'total': totalRounds,
                          });
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Done'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor:
                              passed
                                  ? const Color(0xFF1E88E5)
                                  : const Color(0xFFE57373),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<bool> _showExitWarningDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => Dialog(
                insetPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                backgroundColor: Colors.white,
                child: Container(
                  width: 360,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF1976D2),
                      width: 6,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Assessment Pause.',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              letterSpacing: 0.2,
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('🎮', style: TextStyle(fontSize: 24)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Are you sure you want to leave your learning adventure?\n\nYou\'ll lose your current progress!',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          letterSpacing: 0.2,
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1976D2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  letterSpacing: 0.2,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1976D2),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: Color(0xFF1976D2),
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Exit',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  letterSpacing: 0.2,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bounceController.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_rounds.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    List<String> families = _sortedWords.keys.toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _timer?.cancel();
        _flutterTts.stop();
        bool shouldExit = await _showExitWarningDialog();
        if (shouldExit && context.mounted) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            isPlaying = false;
          });
          if (!_buttonsEnabled) {
            _startRoundFlow(withInstruction: true);
          } else {
            _startTimer();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE3F2FD),
        appBar: AppBar(
          backgroundColor: const Color(0xFF42A5F5),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              _timer?.cancel();
              _flutterTts.stop();
              bool shouldExit = await _showExitWarningDialog();
              if (shouldExit && context.mounted) {
                Navigator.of(context).pop();
              } else {
                setState(() {
                  isPlaying = false;
                });
                if (!_buttonsEnabled) {
                  _startRoundFlow(withInstruction: true);
                } else {
                  _startTimer();
                }
              }
            },
          ),
          title: const Text(
            'Word Family Sort',
            style: TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        _buildProgressBar(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildScoreDisplay(),
                            _buildTimerDisplay(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Drag words to their rhyming family',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            letterSpacing: 0.2,
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: (constraints.maxHeight * 0.42).clamp(
                            220.0,
                            360.0,
                          ),
                          child: Row(
                            children:
                                families.map((family) {
                                  return Expanded(
                                    child: _buildFamilyBucket(family),
                                  );
                                }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildUnsortedWords(),
                        const SizedBox(height: 4),
                        Text(
                          '${_maxPlays - _playCount} plays left',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            letterSpacing: 0.2,
                            fontSize: 12,
                            color:
                                _playCount >= _maxPlays
                                    ? Colors.red[400]
                                    : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (showFeedback) ...[
                          const SizedBox(height: 16),
                          _buildFeedbackBanner(),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Round ${currentRound + 1}',
              style: const TextStyle(
                fontFamily: 'Fredoka',
                letterSpacing: 0.2,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E88E5),
              ),
            ),
            Text(
              '${currentRound + 1}/$totalRounds',
              style: TextStyle(
                fontFamily: 'Fredoka',
                letterSpacing: 0.2,
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: (currentRound + 1) / totalRounds,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF42A5F5)),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sort, color: Color(0xFFFFB300), size: 24),
          const SizedBox(width: 8),
          Text(
            'Sorted: $correctSorts',
            style: const TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E88E5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay() {
    Color timerColor =
        _remainingSeconds <= 10 ? Colors.red : const Color(0xFF1E88E5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: timerColor.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: timerColor, size: 24),
          const SizedBox(width: 8),
          Text(
            '${_remainingSeconds}s',
            style: TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: timerColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyBucket(String family) {
    List<String> wordsInFamily = _sortedWords[family] ?? [];

    return DragTarget<String>(
      onAcceptWithDetails: (details) => _sortWord(details.data, family),
      builder: (context, candidateData, rejectedData) {
        bool isHovering = candidateData.isNotEmpty;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color:
                isHovering
                    ? const Color(0xFF42A5F5).withOpacity(0.2)
                    : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isHovering
                      ? const Color(0xFF42A5F5)
                      : const Color(0xFFE0E0E0),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF42A5F5),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Center(
                  child: Text(
                    '-$family',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      letterSpacing: 0.2,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child:
                      wordsInFamily.isEmpty
                          ? Center(
                            child: Text(
                              'Drop here',
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                letterSpacing: 0.2,
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          )
                          : Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children:
                                wordsInFamily.map((word) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _wrongWords.contains(word)
                                              ? const Color(
                                                0xFFE57373,
                                              ).withOpacity(0.2)
                                              : const Color(
                                                0xFF4CAF50,
                                              ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            _wrongWords.contains(word)
                                                ? const Color(0xFFE57373)
                                                : const Color(0xFF4CAF50),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      word,
                                      style: TextStyle(
                                        fontFamily: 'Fredoka',
                                        letterSpacing: 0.2,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            _wrongWords.contains(word)
                                                ? const Color(0xFFC62828)
                                                : const Color(0xFF2E7D32),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnsortedWords() {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
      ),
      child:
          _unsortedWords.isEmpty
              ? const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Color(0xFF4CAF50),
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'All sorted!',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        letterSpacing: 0.2,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
              )
              : ListView(
                scrollDirection: Axis.horizontal,
                children:
                    _unsortedWords.map((word) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Draggable<String>(
                          data: word,
                          maxSimultaneousDrags: _buttonsEnabled ? 1 : 0,
                          feedback: Material(
                            elevation: 8,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF42A5F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                word,
                                style: const TextStyle(
                                  fontFamily: 'Fredoka',
                                  letterSpacing: 0.2,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Text(
                              word,
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                letterSpacing: 0.2,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                          child: GestureDetector(
                            onTap:
                                _playCount < _maxPlays && _buttonsEnabled
                                    ? () => _playWord(word)
                                    : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (_playCount < _maxPlays && _buttonsEnabled)
                                        ? const Color(0xFFE3F2FD)
                                        : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      (_playCount < _maxPlays &&
                                              _buttonsEnabled)
                                          ? const Color(0xFF42A5F5)
                                          : Colors.grey[400]!,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    word,
                                    style: TextStyle(
                                      fontFamily: 'Fredoka',
                                      letterSpacing: 0.2,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          (_playCount < _maxPlays &&
                                                  _buttonsEnabled)
                                              ? const Color(0xFF1E88E5)
                                              : Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _playCount >= _maxPlays
                                        ? Icons.volume_off
                                        : (isPlaying
                                            ? Icons.volume_up
                                            : Icons.volume_up_outlined),
                                    size: 16,
                                    color:
                                        (_playCount < _maxPlays &&
                                                _buttonsEnabled)
                                            ? const Color(0xFF1E88E5)
                                            : Colors.grey[500],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
    );
  }

  Widget _buildFeedbackBanner() {
    bool allCorrect = _wrongWords.isEmpty && !_timedOut;

    final String message;
    if (_timedOut) {
      message = "Time's up! Keep practicing!";
    } else if (allCorrect) {
      message = 'Round Complete! Great sorting!';
    } else {
      message = 'Some words are in the wrong family!';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            allCorrect
                ? const Color(0xFF4CAF50).withOpacity(0.1)
                : const Color(0xFFE57373).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allCorrect ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _timedOut
                ? Icons
                    .timer_off // ← distinct icon
                : (allCorrect ? Icons.celebration : Icons.close),
            color:
                allCorrect ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color:
                  allCorrect
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
            ),
          ),
        ],
      ),
    );
  }
}
