import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

class Stage3MeaningMatch extends StatefulWidget {
  const Stage3MeaningMatch({super.key});

  @override
  State<Stage3MeaningMatch> createState() => _Stage3MeaningMatchState();
}

class _Stage3MeaningMatchState extends State<Stage3MeaningMatch>
    with TickerProviderStateMixin {
  int currentQuestion = 0;
  int correctAnswers = 0;
  int totalQuestions = 7;
  int? selectedMeaning;
  bool showFeedback = false;
  bool isCorrect = false;
  bool isPlaying = false;
  int _playCount = 0;
  final int _maxPlays = 5;
  bool _isAutoPlay = false;
  int _highScore = 0;
  bool _buttonsEnabled = false;

  Timer? _timer;
  int _remainingSeconds = 60;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  final Random _random = Random();
  List<Map<String, dynamic>> _questions = [];

  final List<Map<String, dynamic>> _allQuestions = [
    {
      'sentence': 'The boy broke his arm.',
      'correct': 'The boy hurt his arm.',
      'options': [
        'The boy hurt his arm.',
        'The boy washed his arm.',
        'The boy raised his arm.',
      ],
    },
    {
      'sentence': 'She is feeling under the weather.',
      'correct': 'She is feeling sick.',
      'options': [
        'She is feeling sick.',
        'She is standing in the rain.',
        'She is very happy.',
      ],
    },
    {
      'sentence': 'Time flies when you have fun.',
      'correct': 'Time passes quickly when you enjoy yourself.',
      'options': [
        'Time passes quickly when you enjoy yourself.',
        'Clocks can fly in the air.',
        'Time stops when you play.',
      ],
    },
    {
      'sentence': 'Please give me a hand.',
      'correct': 'Please help me.',
      'options': [
        'Please help me.',
        'Please show me your hand.',
        'Please wave at me.',
      ],
    },
    {
      'sentence': 'The test was a piece of cake.',
      'correct': 'The test was very easy.',
      'options': [
        'The test was very easy.',
        'The test had food.',
        'The test was very hard.',
      ],
    },
    {
      'sentence': 'She let the cat out of the bag.',
      'correct': 'She told a secret.',
      'options': [
        'She told a secret.',
        'She released her cat.',
        'She bought a new bag.',
      ],
    },
    {
      'sentence': 'Keep your chin up.',
      'correct': 'Stay positive and confident.',
      'options': [
        'Stay positive and confident.',
        'Look at the ceiling.',
        'Hold your head still.',
      ],
    },
    {
      'sentence': 'The dog has a loud bark.',
      'correct': 'The dog makes a loud sound.',
      'options': [
        'The dog makes a loud sound.',
        'The dog has something in its mouth.',
        'The dog is very quiet.',
      ],
    },
    {
      'sentence': 'I need to hit the books.',
      'correct': 'I need to study hard.',
      'options': [
        'I need to study hard.',
        'I need to throw books.',
        'I need to buy books.',
      ],
    },
    {
      'sentence': 'The movie was a big hit.',
      'correct': 'The movie was very popular.',
      'options': [
        'The movie was very popular.',
        'The movie had fighting scenes.',
        'The movie was very long.',
      ],
    },
    {
      'sentence': 'She has a green thumb.',
      'correct': 'She is good at gardening.',
      'options': [
        'She is good at gardening.',
        'Her thumb is painted green.',
        'She hurt her thumb.',
      ],
    },
    {
      'sentence': 'Hold your horses.',
      'correct': 'Be patient and wait.',
      'options': [
        'Be patient and wait.',
        'Grab some horses.',
        'Run very fast.',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
    _setupAnimations();
    _generateQuestions();
    _loadHighScore();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isAutoPlay = true;
      await _playCurrentSentence(withInstruction: true);
      if (mounted) _startTimer();
    });
  }

  void _setupAnimations() {
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticIn),
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
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
      isCorrect = false;
    });
    _audioPlayer.play(AssetSource('sounds/incorrectAnswer.wav'));

    Timer(const Duration(milliseconds: 2000), () {
      if (currentQuestion < totalQuestions - 1) {
        setState(() {
          currentQuestion++;
          selectedMeaning = null;
          showFeedback = false;
          _remainingSeconds = 60;
          _playCount = 0;
        });
        _startTimer();
        _isAutoPlay = true;
        _playCurrentSentence(withInstruction: true);
      } else {
        _showCompletionDialog();
      }
    });
  }

  void _generateQuestions() {
    _questions = List.from(_allQuestions)..shuffle(_random);
    _questions = _questions.take(totalQuestions).toList();
    for (var q in _questions) {
      List<String> options = List.from(q['options']);
      String correct = q['correct'];
      options.shuffle(_random);
      q['options'] = options;
      q['correctIndex'] = options.indexOf(correct);
    }
  }

  Future<void> _playCurrentSentence({bool withInstruction = false}) async {
    if (currentQuestion >= _questions.length) return;
    if (!_isAutoPlay) {
      if (_playCount >= _maxPlays) return;
      _playCount++;
    }
    _isAutoPlay = false;
    setState(() {
      isPlaying = true;
      _buttonsEnabled = false;
    });
    _bounceController.repeat(reverse: true);

    if (withInstruction) {
      Completer<void> ttsCompleter = Completer<void>();
      _flutterTts.setCompletionHandler(() {
        if (!ttsCompleter.isCompleted) ttsCompleter.complete();
      });
      await _flutterTts.speak(
        'Listen to a sentence and select another sentence with the same meaning',
      );
      await ttsCompleter.future;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    String sentence = _questions[currentQuestion]['sentence'];
    Completer<void> sentenceCompleter = Completer<void>();
    _flutterTts.setCompletionHandler(() {
      if (!sentenceCompleter.isCompleted) sentenceCompleter.complete();
    });
    await _flutterTts.speak(sentence);
    await sentenceCompleter.future;

    await Future.delayed(const Duration(milliseconds: 300));
    _bounceController.stop();
    _bounceController.reset();
    if (mounted) {
      setState(() {
        isPlaying = false;
        _buttonsEnabled = true;
      });
    }
  }

  void _selectMeaning(int index) {
    if (showFeedback || !_buttonsEnabled) return;
    setState(() {
      selectedMeaning = index;
    });
  }

  void _checkAnswer() {
    if (selectedMeaning == null) return;

    int correct = _questions[currentQuestion]['correctIndex'];

    setState(() {
      showFeedback = true;
      isCorrect = selectedMeaning == correct;
      if (isCorrect) correctAnswers++;
    });

    _audioPlayer.play(
      AssetSource(
        isCorrect ? 'sounds/correctAnswer.wav' : 'sounds/incorrectAnswer.wav',
      ),
    );

    Timer(const Duration(milliseconds: 1800), () {
      if (currentQuestion < totalQuestions - 1) {
        _timer?.cancel();
        setState(() {
          currentQuestion++;
          selectedMeaning = null;
          showFeedback = false;
          _remainingSeconds = 60;
          _playCount = 0;
        });
        _startTimer();
        _isAutoPlay = true;
        _playCurrentSentence(withInstruction: true);
      } else {
        _showCompletionDialog();
      }
    });
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('stage3_meaning_match_high_score') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    if (correctAnswers > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('stage3_meaning_match_high_score', correctAnswers);
      _highScore = correctAnswers;
    }
  }

  String _getFeedbackMessage() {
    double percentage = correctAnswers / totalQuestions;
    if (percentage >= 0.9) return 'Outstanding meaning mastery!';
    if (percentage >= 0.7) return 'Great meaning matching!';
    if (percentage >= 0.5) return 'Good effort! Try again to improve!';
    return 'Keep trying! Practice makes perfect!';
  }

  Future<void> _showCompletionDialog() async {
    _timer?.cancel();
    await _saveHighScore();
    final prefs = await SharedPreferences.getInstance();
    bool passed = correctAnswers >= 4;
    int failedAttempts = prefs.getInt('stage3_meaning_match_failed') ?? 0;
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
                          ? [const Color(0xFF9C27B0), const Color(0xFF9C27B0)]
                          : [const Color(0xFFEF9A9A), const Color(0xFFE57373)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    passed ? Icons.lightbulb : Icons.sentiment_dissatisfied,
                    size: 70,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    passed ? 'Meaning Master!' : 'Keep Practicing!',
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
                          'Score: $correctAnswers / $totalQuestions',
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
                          'High Score: $_highScore / $totalQuestions',
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
                        onPressed: () async {
                          Navigator.pop(context);
                          setState(() {
                            currentQuestion = 0;
                            correctAnswers = 0;
                            selectedMeaning = null;
                            showFeedback = false;
                            _remainingSeconds = 60;
                            _playCount = 0;
                          });
                          _generateQuestions();
                          _isAutoPlay = true;
                          await _playCurrentSentence(withInstruction: true);
                          if (mounted) _startTimer();
                        },
                        icon: const Icon(Icons.replay),
                        label: const Text('Play Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor:
                              passed
                                  ? const Color(0xFF9C27B0)
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
                            'score': correctAnswers,
                            'total': totalQuestions,
                          });
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Done'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor:
                              passed
                                  ? const Color(0xFF9C27B0)
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
                      color: const Color(0xFF7E57C2),
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
                                backgroundColor: const Color(0xFF7E57C2),
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
                                foregroundColor: const Color(0xFF7E57C2),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: Color(0xFF7E57C2),
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
    if (_questions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    String sentence = _questions[currentQuestion]['sentence'];
    List<String> options = List.from(_questions[currentQuestion]['options']);
    int correctIndex = _questions[currentQuestion]['correctIndex'];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _timer?.cancel();
        _flutterTts.stop();
        _audioPlayer.stop();
        final shouldExit = await _showExitWarningDialog();
        if (shouldExit) {
          if (context.mounted) Navigator.of(context).pop();
        } else {
          setState(() {
            isPlaying = false;
            _buttonsEnabled = true;
          });
          _startTimer();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3E5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF9C27B0),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              _timer?.cancel();
              _flutterTts.stop();
              _audioPlayer.stop();
              final shouldExit = await _showExitWarningDialog();
              if (shouldExit) {
                if (context.mounted) Navigator.of(context).pop();
              } else {
                setState(() {
                  isPlaying = false;
                  _buttonsEnabled = true;
                });
                _startTimer();
              }
            },
          ),
          title: const Text(
            'Meaning Match',
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
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildScoreDisplay(),
                            _buildTimerDisplay(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildSoundButton(),
                        const SizedBox(height: 10),
                        _buildSentenceDisplay(sentence),
                        const SizedBox(height: 8),
                        Text(
                          'What does this mean?',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            letterSpacing: 0.2,
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: (constraints.maxHeight * 0.38).clamp(
                            220.0,
                            360.0,
                          ),
                          child: _buildMeaningOptions(options, correctIndex),
                        ),
                        const SizedBox(height: 12),
                        _buildCheckButton(),
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
              'Sentence ${currentQuestion + 1}',
              style: const TextStyle(
                fontFamily: 'Fredoka',
                letterSpacing: 0.2,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9C27B0),
              ),
            ),
            Text(
              '${currentQuestion + 1}/$totalQuestions',
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
            value: (currentQuestion + 1) / totalQuestions,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
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
            color: Colors.purple.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lightbulb, color: Color(0xFFFFB300), size: 24),
          const SizedBox(width: 8),
          Text(
            'Score: $correctAnswers',
            style: const TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9C27B0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _remainingSeconds <= 15 ? Colors.red[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            color:
                _remainingSeconds <= 15 ? Colors.red : const Color(0xFF9C27B0),
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            '${_remainingSeconds}s',
            style: TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color:
                  _remainingSeconds <= 15
                      ? Colors.red
                      : const Color(0xFF9C27B0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundButton() {
    bool canPlay = !isPlaying && _playCount < _maxPlays;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _bounceAnimation,
          child: GestureDetector(
            onTap: canPlay ? _playCurrentSentence : null,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.18,
              height: MediaQuery.of(context).size.width * 0.18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      canPlay
                          ? [const Color(0xFF9C27B0), const Color(0xFF9C27B0)]
                          : [Colors.grey[400]!, Colors.grey[500]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF9C27B0,
                    ).withOpacity(canPlay ? 0.4 : 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                isPlaying
                    ? Icons.volume_up
                    : (_playCount >= _maxPlays
                        ? Icons.volume_off
                        : Icons.play_arrow),
                size: 36,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_maxPlays - _playCount} plays left',
          style: TextStyle(
            fontFamily: 'Fredoka',
            letterSpacing: 0.2,
            fontSize: 12,
            color: _playCount >= _maxPlays ? Colors.red[400] : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSentenceDisplay(String sentence) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.format_quote,
              color: Color(0xFF9C27B0),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sentence,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                letterSpacing: 0.2,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeaningOptions(List<String> options, int correctIndex) {
    return ListView.builder(
      itemCount: options.length,
      itemBuilder: (context, index) {
        bool isSelected = selectedMeaning == index;
        bool showWrong = showFeedback && isSelected && !isCorrect;

        Color bgColor = Colors.white;
        Color borderColor = const Color(0xFFE0E0E0);
        Color textColor = const Color(0xFF333333);
        IconData? trailingIcon;

        if (isSelected && !showFeedback) {
          bgColor = const Color(0xFF9C27B0).withOpacity(0.15);
          borderColor = const Color(0xFF9C27B0);
          textColor = const Color(0xFF9C27B0);
        } else if (showWrong) {
          bgColor = const Color(0xFFE57373).withOpacity(0.15);
          borderColor = const Color(0xFFE57373);
          textColor = const Color(0xFFC62828);
          trailingIcon = Icons.cancel;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => _selectMeaning(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: borderColor.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: borderColor.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        String.fromCharCode(65 + index), // A, B, C
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          letterSpacing: 0.2,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      options[index],
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        letterSpacing: 0.2,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (trailingIcon != null)
                    Icon(
                      trailingIcon,
                      color: const Color(0xFFE57373),
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed:
            selectedMeaning != null && !showFeedback ? _checkAnswer : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9C27B0),
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Text(
          showFeedback
              ? (isCorrect ? 'You got it!' : 'Keep learning!')
              : 'Check Meaning',
          style: TextStyle(
            fontFamily: 'Fredoka',
            letterSpacing: 0.2,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color:
                (selectedMeaning != null || showFeedback)
                    ? Colors.white
                    : Colors.grey[500],
          ),
        ),
      ),
    );
  }
}
