import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

class Stage3SentenceListener extends StatefulWidget {
  const Stage3SentenceListener({super.key});

  @override
  State<Stage3SentenceListener> createState() => _Stage3SentenceListenerState();
}

class _Stage3SentenceListenerState extends State<Stage3SentenceListener>
    with TickerProviderStateMixin {
  int currentQuestion = 0;
  int correctAnswers = 0;
  int totalQuestions = 7;
  int? selectedAnswer;
  bool showFeedback = false;
  bool isCorrect = false;
  bool isPlaying = false;
  int _playCount = 0;
  final int _maxPlays = 5;
  bool _isAutoPlay = false;
  int _highScore = 0;
  Timer? _timer;
  int _remainingSeconds = 60;
  bool _buttonsEnabled = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  final Random _random = Random();
  List<Map<String, dynamic>> _questions = [];

  // Sentences with image-based options
  final List<Map<String, dynamic>> _allQuestions = [
    {
      'sentence': 'The cat is running.',
      'correct': 0,
      'options': [
        {'image': 'assets/images/catRun.png', 'label': 'Cat running'},
        {'image': 'assets/images/catSleep.png', 'label': 'Cat sleeping'},
        {'image': 'assets/images/dogRun.png', 'label': 'Dog running'},
      ],
    },
    {
      'sentence': 'The cat is sleeping.',
      'correct': 0,
      'options': [
        {'image': 'assets/images/catSleep.png', 'label': 'Cat sleeping'},
        {'image': 'assets/images/catRun.png', 'label': 'Cat running'},
        {'image': 'assets/images/catEat.png', 'label': 'Cat eating'},
      ],
    },
    {
      'sentence': 'The cat is eating.',
      'correct': 0,
      'options': [
        {'image': 'assets/images/catEat.png', 'label': 'Cat eating'},
        {'image': 'assets/images/catSleep.png', 'label': 'Cat sleeping'},
        {'image': 'assets/images/fishSwim.png', 'label': 'Fish swimming'},
      ],
    },
    {
      'sentence': 'The dog is running.',
      'correct': 0,
      'options': [
        {'image': 'assets/images/dogRun.png', 'label': 'Dog running'},
        {'image': 'assets/images/catRun.png', 'label': 'Cat running'},
        {'image': 'assets/images/birdFly.png', 'label': 'Bird flying'},
      ],
    },
    {
      'sentence': 'The dog is jumping.',
      'correct': 0,
      'options': [
        {'image': 'assets/images/dogJump.png', 'label': 'Dog jumping'},
        {'image': 'assets/images/dogRun.png', 'label': 'Dog running'},
        {'image': 'assets/images/fishSwim.png', 'label': 'Fish swimming'},
      ],
    },
    {
      'sentence': 'The bird is flying.',
      'correct': 0,
      'options': [
        {'image': 'assets/images/birdFly.png', 'label': 'Bird flying'},
        {'image': 'assets/images/fishSwim.png', 'label': 'Fish swimming'},
        {'image': 'assets/images/dogRun.png', 'label': 'Dog running'},
      ],
    },
    {
      'sentence': 'The fish is swimming.',
      'correct': 0,
      'options': [
        {'image': 'assets/images/fishSwim.png', 'label': 'Fish swimming'},
        {'image': 'assets/images/birdFly.png', 'label': 'Bird flying'},
        {'image': 'assets/images/catEat.png', 'label': 'Cat eating'},
      ],
    },
    {
      'sentence': 'The boy is kicking a ball.',
      'correct': 0,
      'options': [
        {'image': 'assets/images/boyKick.png', 'label': 'Boy kicking ball'},
        {'image': 'assets/images/girlRead.png', 'label': 'Girl reading'},
        {'image': 'assets/images/childRun.png', 'label': 'Child running'},
      ],
    },
    {
      'sentence': 'The girl is reading a book.',
      'correct': 0,
      'options': [
        {'image': 'assets/images/girlRead.png', 'label': 'Girl reading'},
        {'image': 'assets/images/boyKick.png', 'label': 'Boy kicking ball'},
        {'image': 'assets/images/childWrite.png', 'label': 'Child writing'},
      ],
    },
    {
      'sentence': 'The child is eating.',
      'correct': 0,
      'options': [
        {'image': 'assets/images/childEat.png', 'label': 'Child eating'},
        {'image': 'assets/images/childRun.png', 'label': 'Child running'},
        {'image': 'assets/images/childSleep.png', 'label': 'Child sleeping'},
      ],
    },
    {
      'sentence': 'The child is running.',
      'correct': 0,
      'options': [
        {'image': 'assets/images/childRun.png', 'label': 'Child running'},
        {'image': 'assets/images/childSleep.png', 'label': 'Child sleeping'},
        {'image': 'assets/images/childEat.png', 'label': 'Child eating'},
      ],
    },
    {
      'sentence': 'The child is sleeping.',
      'correct': 0,
      'options': [
        {'image': 'assets/images/childSleep.png', 'label': 'Child sleeping'},
        {'image': 'assets/images/childBook.png', 'label': 'Child reading'},
        {'image': 'assets/images/childJump.png', 'label': 'Child jumping'},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _initTts();
    _setupAnimations();
    _generateQuestions();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isAutoPlay = true;
      await _playCurrentSentence(withInstruction: true);
      if (mounted) _startTimer();
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
      isCorrect = false;
    });
    _audioPlayer.play(AssetSource('sounds/incorrectAnswer.wav'));

    Timer(const Duration(milliseconds: 2000), () {
      if (currentQuestion < totalQuestions - 1) {
        setState(() {
          currentQuestion++;
          selectedAnswer = null;
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

  void _generateQuestions() {
    _questions = List.from(_allQuestions)..shuffle(_random);
    _questions = _questions.take(totalQuestions).toList();
    for (var q in _questions) {
      // Shuffle options and update correct index
      List<Map<String, dynamic>> options = List.from(q['options']);
      Map<String, dynamic> correctOption = options[q['correct']];
      options.shuffle(_random);
      q['options'] = options;
      q['correct'] = options.indexOf(correctOption);
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
        'Listen to a sentence and select the matching image',
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

  void _selectAnswer(int index) {
    if (showFeedback || !_buttonsEnabled) return;
    setState(() {
      selectedAnswer = index;
    });
  }

  void _checkAnswer() {
    if (selectedAnswer == null) return;

    int correct = _questions[currentQuestion]['correct'];

    setState(() {
      showFeedback = true;
      isCorrect = selectedAnswer == correct;
      if (isCorrect) correctAnswers++;
    });

    _audioPlayer.play(
      AssetSource(
        isCorrect ? 'sounds/correctAnswer.wav' : 'sounds/incorrectAnswer.wav',
      ),
    );

    Timer(const Duration(milliseconds: 1500), () {
      if (currentQuestion < totalQuestions - 1) {
        _timer?.cancel();
        setState(() {
          currentQuestion++;
          selectedAnswer = null;
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
      _highScore = prefs.getInt('stage3_sentence_listener_high_score') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    if (correctAnswers > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('stage3_sentence_listener_high_score', correctAnswers);
      _highScore = correctAnswers;
    }
  }

  String _getFeedbackMessage() {
    double percentage = correctAnswers / totalQuestions;
    if (percentage >= 0.9) return 'Amazing listening skills!';
    if (percentage >= 0.7) return 'Great sentence comprehension!';
    if (percentage >= 0.5) return 'Good effort! Try again to improve!';
    return 'Keep trying! Practice makes perfect!';
  }

  Future<void> _showCompletionDialog() async {
    _timer?.cancel();
    await _saveHighScore();
    final prefs = await SharedPreferences.getInstance();
    bool passed = correctAnswers >= 4;
    int failedAttempts = prefs.getInt('stage3_sentence_listener_failed') ?? 0;
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
                          ? [const Color(0xFF9C27B0), const Color(0xFF673AB7)]
                          : [const Color(0xFFEF9A9A), const Color(0xFFE57373)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    passed ? Icons.hearing : Icons.sentiment_dissatisfied,
                    size: 70,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    passed ? 'Great Listening!' : 'Keep Practicing!',
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
                            selectedAnswer = null;
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
                                  ? const Color(0xFF673AB7)
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
                                  ? const Color(0xFF673AB7)
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
                      color: const Color(0xFF9C27B0),
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
                                backgroundColor: const Color(0xFF9C27B0),
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
                                foregroundColor: const Color(0xFF9C27B0),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: Color(0xFF9C27B0),
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

    List<Map<String, dynamic>> options = List.from(
      _questions[currentQuestion]['options'],
    );
    int correct = _questions[currentQuestion]['correct'];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _timer?.cancel();
        _flutterTts.stop();
        _audioPlayer.stop();
        final shouldExit = await _showExitWarningDialog();
        if (shouldExit && context.mounted) {
          Navigator.of(context).pop();
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
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              _timer?.cancel();
              _flutterTts.stop();
              _audioPlayer.stop();
              final shouldExit = await _showExitWarningDialog();
              if (shouldExit && context.mounted) {
                Navigator.of(context).pop();
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
            'Sentence Listener',
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
                        const SizedBox(height: 8),
                        Text(
                          'Listen and select the matching picture',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            letterSpacing: 0.2,
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: (constraints.maxHeight * 0.40).clamp(
                            220.0,
                            380.0,
                          ),
                          child: _buildImageOptions(options, correct),
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
          const Icon(Icons.hearing, color: Color(0xFFFFB300), size: 24),
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
    Color timerColor =
        _remainingSeconds <= 15 ? Colors.red : const Color(0xFF9C27B0);
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
              width: MediaQuery.of(context).size.width * 0.22,
              height: MediaQuery.of(context).size.width * 0.22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      canPlay
                          ? [const Color(0xFF9C27B0), const Color(0xFF673AB7)]
                          : [Colors.grey[400]!, Colors.grey[500]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF673AB7,
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
                size: 40,
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

  Widget _buildImageOptions(List<Map<String, dynamic>> options, int correct) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildImageChoice(
                index: 0,
                option: options[0],
                correctIndex: correct,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildImageChoice(
                index: 1,
                option: options[1],
                correctIndex: correct,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 12) / 2;
            return SizedBox(
              width: itemWidth,
              child: _buildImageChoice(
                index: 2,
                option: options[2],
                correctIndex: correct,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildImageChoice({
    required int index,
    required Map<String, dynamic> option,
    required int correctIndex,
  }) {
    final bool isSelected = selectedAnswer == index;

    Color borderColor;
    Color overlayColor;
    Widget? badge;

    if (showFeedback) {
      if (!isCorrect && isSelected) {
        borderColor = const Color(0xFFE53935);
        overlayColor = const Color(0xFFE53935).withOpacity(0.25);
        badge = _revealBadge(Icons.cancel, const Color(0xFFE53935));
      } else {
        borderColor = Colors.white;
        overlayColor = Colors.transparent;
        badge = null;
      }
    } else {
      borderColor = isSelected ? Colors.orange : Colors.white;
      overlayColor =
          isSelected ? Colors.orange.withOpacity(0.18) : Colors.transparent;
      badge =
          isSelected
              ? Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              )
              : null;
    }

    return GestureDetector(
      onTap: () => _selectAnswer(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 4),
          boxShadow: [
            BoxShadow(
              color:
                  showFeedback
                      ? borderColor.withOpacity(0.35)
                      : isSelected
                      ? Colors.orange.withOpacity(0.4)
                      : Colors.black.withOpacity(0.15),
              blurRadius: showFeedback || isSelected ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.3,
                child: Image.asset(
                  option['image'],
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                ),
              ),
              if (overlayColor != Colors.transparent)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: overlayColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              if (badge != null) Positioned(top: 8, right: 8, child: badge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _revealBadge(IconData icon, Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  Widget _buildCheckButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed:
            selectedAnswer != null && !showFeedback ? _checkAnswer : null,
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
              ? (isCorrect ? 'Great listening!' : 'Listen again!')
              : 'Check Answer',
          style: TextStyle(
            fontFamily: 'Fredoka',
            letterSpacing: 0.2,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color:
                (selectedAnswer != null || showFeedback)
                    ? Colors.white
                    : Colors.grey[500],
          ),
        ),
      ),
    );
  }
}
