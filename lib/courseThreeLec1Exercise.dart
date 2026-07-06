import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'dart:math';
import 'settings_manager.dart';
import 'progress_manager.dart';
import 'courseThree.dart';
import 'notification_helper.dart';

class CourseThreeLec1Exercise extends StatefulWidget {
  const CourseThreeLec1Exercise({super.key});

  @override
  State<CourseThreeLec1Exercise> createState() =>
      _CourseThreeLec1ExerciseState();
}

class _CourseThreeLec1ExerciseState extends State<CourseThreeLec1Exercise>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _highScore = 0;
  int currentScore = 0;
  int currentQuestion = 1;
  final int totalQuestions = 5;
  int? selectedAnswerIndex;
  int _originalHighScore = 0;
  bool _originalWasCompleted = false;

  // ─── Answer reveal state ───
  bool _answerRevealed = false;
  bool? _lastAnswerCorrect;
  bool _showWrongHighlight = false;
  bool _showCorrectHighlight = false;

  late AnimationController _dialogController;
  late Animation<double> _dialogScaleAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  final ProgressManager _progressManager = ProgressManager();

  List<Map<String, dynamic>> currentQuizQuestions = [];
  final Random _random = Random();

  bool _exerciseStarted = false;
  bool _wasEverCompleted = false;
  bool _isTransitioning = false;
  bool _disposed = false;

  // ─── Sound-lock state ───
  bool _isSoundPlaying = false;

  // ── 10 sentence-picture questions ─────────────────────────────────────────
  final List<Map<String, dynamic>> allQuizData = [
    // 1️⃣  correct @ 0
    {
      'audioSentence': 'The cat runs.',
      'answers': [
        {'label': 'Cat running', 'image': 'assets/images/catRun.png'},
        {'label': 'Cat sleeping', 'image': 'assets/images/catSleep.png'},
        {'label': 'Dog running', 'image': 'assets/images/dogRun.png'},
      ],
      'ttsChoices': ['The cat runs', 'The cat sleeps', 'The dog runs'],
      'correctAnswer': 0,
    },
    // 2️⃣  correct @ 0
    {
      'audioSentence': 'The cat sleeps.',
      'answers': [
        {'label': 'Cat sleeping', 'image': 'assets/images/catSleep.png'},
        {'label': 'Cat running', 'image': 'assets/images/catRun.png'},
        {'label': 'Dog jumping', 'image': 'assets/images/dogJump.png'},
      ],
      'ttsChoices': ['The cat sleeps', 'The cat runs', 'The dog jumps'],
      'correctAnswer': 0,
    },
    // 3️⃣  correct @ 1
    {
      'audioSentence': 'The dog runs.',
      'answers': [
        {'label': 'Cat running', 'image': 'assets/images/catRun.png'},
        {'label': 'Dog running', 'image': 'assets/images/dogRun.png'},
        {'label': 'Fish Swimming', 'image': 'assets/images/fishSwim.png'},
      ],
      'ttsChoices': ['The cat runs', 'The dog runs', 'The fish swims'],
      'correctAnswer': 1,
    },
    // 4️⃣  correct @ 2
    {
      'audioSentence': 'The dog jumps.',
      'answers': [
        {'label': 'Fish Swimming', 'image': 'assets/images/fishSwim.png'},
        {'label': 'Bird flying', 'image': 'assets/images/birdFly.png'},
        {'label': 'Dog jumping', 'image': 'assets/images/dogJump.png'},
      ],
      'ttsChoices': ['The fish swims', 'The bird flies', 'The dog jumps'],
      'correctAnswer': 2,
    },
    // 5️⃣  correct @ 0
    {
      'audioSentence': 'The cat eats fish.',
      'answers': [
        {'label': 'Cat eating fish', 'image': 'assets/images/catEat.png'},
        {'label': 'Cat sleeping', 'image': 'assets/images/catSleep.png'},
        {'label': 'Fish swimming', 'image': 'assets/images/fishSwim.png'},
      ],
      'ttsChoices': ['The cat eats fish', 'The cat sleeps', 'The fish swims'],
      'correctAnswer': 0,
    },
    // 6️⃣  correct @ 1
    {
      'audioSentence': 'The boy kicks the ball.',
      'answers': [
        {'label': 'Dog jumping', 'image': 'assets/images/dogJump.png'},
        {'label': 'Boy kicking ball', 'image': 'assets/images/boyKick.png'},
        {'label': 'Girl reading book', 'image': 'assets/images/girlRead.png'},
      ],
      'ttsChoices': [
        'The dog jumps',
        'The boy kicks the ball',
        'The girl reads a book',
      ],
      'correctAnswer': 1,
    },
    // 7️⃣  correct @ 2
    {
      'audioSentence': 'The girl reads a book.',
      'answers': [
        {'label': 'Boy kicking ball', 'image': 'assets/images/boyKick.png'},
        {'label': 'Cat sleeping', 'image': 'assets/images/catSleep.png'},
        {'label': 'Girl reading book', 'image': 'assets/images/girlRead.png'},
      ],
      'ttsChoices': [
        'The boy kicks the ball',
        'The cat sleeps',
        'The girl reads a book',
      ],
      'correctAnswer': 2,
    },
    // 8️⃣  correct @ 0
    {
      'audioSentence': 'The bird flies.',
      'answers': [
        {'label': 'Bird flying', 'image': 'assets/images/birdFly.png'},
        {'label': 'Fish swimming', 'image': 'assets/images/fishSwim.png'},
        {'label': 'Dog running', 'image': 'assets/images/dogRun.png'},
      ],
      'ttsChoices': ['The bird flies', 'The fish swims', 'The dog runs'],
      'correctAnswer': 0,
    },
    // 9️⃣  correct @ 1
    {
      'audioSentence': 'The fish swims.',
      'answers': [
        {'label': 'Bird flying', 'image': 'assets/images/birdFly.png'},
        {'label': 'Fish swimming', 'image': 'assets/images/fishSwim.png'},
        {'label': 'Cat eating fish', 'image': 'assets/images/catEat.png'},
      ],
      'ttsChoices': ['The bird flies', 'The fish swims', 'The cat eats fish'],
      'correctAnswer': 1,
    },
    // 🔟  correct @ 2
    {
      'audioSentence': 'The cat runs.',
      'answers': [
        {'label': 'Dog running', 'image': 'assets/images/dogRun.png'},
        {'label': 'Cat sleeping', 'image': 'assets/images/catSleep.png'},
        {'label': 'Cat running', 'image': 'assets/images/catRun.png'},
      ],
      'ttsChoices': ['The dog runs', 'The cat sleeps', 'The cat runs'],
      'correctAnswer': 2,
    },
  ];

  Future<void> _restoreProgress() async {
    _progressManager.forceSetHighScore(
      'course_three',
      0,
      'Stage3_Exercise',
      _originalHighScore,
    );
    await _progressManager.updateExerciseCompletion(
      'course_three',
      0,
      'Stage3_Exercise',
      _originalWasCompleted,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _highScore = _progressManager.getExerciseHighScore(
      'course_three',
      0,
      'Stage3_Exercise',
    );
    _wasEverCompleted = _progressManager.isExerciseCompleted(
      'course_three',
      0,
      'Stage3_Exercise',
    );
    _originalHighScore = _highScore;
    _originalWasCompleted = _wasEverCompleted;

    _dialogController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _dialogScaleAnimation = CurvedAnimation(
      parent: _dialogController,
      curve: Curves.elasticOut,
    );

    // Release sound lock when audio file finishes
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted && !_disposed) {
        setState(() => _isSoundPlaying = false);
      }
    });

    _selectRandomQuestions();

    _initializeTts().then((_) {
      if (_disposed) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed || !mounted) return;
        setState(() => _exerciseStarted = true);
        _playCurrentSound();
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_exerciseStarted || _disposed) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _flutterTts.stop();
      _audioPlayer.stop();
      if (mounted) {
        setState(() => _isSoundPlaying = false);
      }
    }
  }

  void _selectRandomQuestions() {
    final shuffled = List<Map<String, dynamic>>.from(allQuizData);
    shuffled.shuffle(_random);
    currentQuizQuestions = shuffled.take(5).toList();
  }

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(SettingsManager.speechOutputVolume);
      await _flutterTts.setPitch(1.0);

      // Default handler: just release the sound lock.
      // _playCurrentSound overrides this with a one-shot handler when needed.
      _flutterTts.setCompletionHandler(() {
        if (!_disposed && mounted) setState(() => _isSoundPlaying = false);
      });
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  /// Speaks the fixed instruction, then auto-speaks the question sentence
  /// via a one-shot completion handler that restores the default when done.
  Future<void> _playCurrentSound() async {
    if (_disposed || !mounted) return;
    if (currentQuestion > currentQuizQuestions.length) return;
    if (_isSoundPlaying) return;

    setState(() => _isSoundPlaying = true);
    try {
      await _flutterTts.stop();
      await _audioPlayer.stop();

      // One-shot: fires after the instruction, restores default before
      // speaking the sentence so the sentence's completion doesn't loop.
      _flutterTts.setCompletionHandler(() {
        if (_disposed || !mounted) return;
        _flutterTts.setCompletionHandler(() {
          if (!_disposed && mounted) setState(() => _isSoundPlaying = false);
        });
        setState(() => _isSoundPlaying = false);
        _playQuestionAudio();
      });

      await _flutterTts.speak('Tap the sentence you hear.');
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _flutterTts.setCompletionHandler(() {
        if (!_disposed && mounted) setState(() => _isSoundPlaying = false);
      });
      setState(() => _isSoundPlaying = false);
      _playQuestionAudio();
    }
  }

  /// Speaks only the question sentence. Wired to the speaker button.
  Future<void> _playQuestionAudio() async {
    if (_disposed || !mounted) return;
    if (currentQuestion > currentQuizQuestions.length) return;
    if (_isSoundPlaying) return;

    final sentence =
        currentQuizQuestions[currentQuestion - 1]['audioSentence'] as String;
    setState(() => _isSoundPlaying = true);
    try {
      await _flutterTts.stop();
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.speak(sentence);
      // Default TTS completion handler releases the lock
    } catch (e) {
      debugPrint('TTS speak error: $e');
      setState(() => _isSoundPlaying = false);
    }
  }

  Future<void> _playFeedbackSound(bool isCorrect) async {
    if (!SettingsManager.soundEffectsEnabled) return;
    setState(() => _isSoundPlaying = true);
    try {
      final path =
          isCorrect ? 'sounds/correctAnswer.wav' : 'sounds/incorrectAnswer.wav';
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(SettingsManager.speechOutputVolume);
      await _audioPlayer.play(AssetSource(path));
    } catch (e) {
      debugPrint('Feedback sound error: $e');
      setState(() => _isSoundPlaying = false);
    }
  }

  Future<void> _speakSelectedAnswer(
    Map<String, dynamic> questionData,
    int index,
  ) async {
    final ttsChoices = _resolveTtsChoices(questionData);
    final answers = questionData['answers'] as List<dynamic>;
    final text =
        ttsChoices != null
            ? ttsChoices[index]
            : (answers[index] as Map)['label'] as String;
    setState(() => _isSoundPlaying = true);
    try {
      await _flutterTts.stop();
      await _audioPlayer.stop();
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Selected answer speak error: $e');
      if (mounted) setState(() => _isSoundPlaying = false);
    }
  }

  List<String>? _resolveTtsChoices(Map<String, dynamic> questionData) {
    final raw = questionData['ttsChoices'];
    if (raw is List && raw.length >= 3) {
      return raw.map((e) => e.toString()).toList();
    }

    // Fallback for stale in-memory question maps (e.g. hot reload state).
    final answers = questionData['answers'] as List<dynamic>;
    final labels =
        answers
            .map((e) => (e as Map<String, dynamic>)['label'] as String)
            .toList();
    final key = labels.join('|');
    const fallbackMap = <String, List<String>>{
      'Cat running|Cat sleeping|Dog running': [
        'The cat runs',
        'The cat sleeps',
        'The dog runs',
      ],
      'Cat sleeping|Cat running|Dog jumping': [
        'The cat sleeps',
        'The cat runs',
        'The dog jumps',
      ],
      'Cat running|Dog running|Fish Swimming': [
        'The cat runs',
        'The dog runs',
        'The fish swims',
      ],
      'Fish Swimming|Bird flying|Dog jumping': [
        'The fish swims',
        'The bird flies',
        'The dog jumps',
      ],
      'Cat eating fish|Cat sleeping|Fish swimming': [
        'The cat eats fish',
        'The cat sleeps',
        'The fish swims',
      ],
      'Dog jumping|Boy kicking ball|Girl reading book': [
        'The dog jumps',
        'The boy kicks the ball',
        'The girl reads a book',
      ],
      'Boy kicking ball|Cat sleeping|Girl reading book': [
        'The boy kicks the ball',
        'The cat sleeps',
        'The girl reads a book',
      ],
      'Bird flying|Fish swimming|Dog running': [
        'The bird flies',
        'The fish swims',
        'The dog runs',
      ],
      'Bird flying|Fish swimming|Cat eating fish': [
        'The bird flies',
        'The fish swims',
        'The cat eats fish',
      ],
      'Dog running|Cat sleeping|Cat running': [
        'The dog runs',
        'The cat sleeps',
        'The cat runs',
      ],
    };
    return fallbackMap[key];
  }

  void selectAnswer(int index) {
    if (!_exerciseStarted || _isTransitioning || _disposed) return;
    if (_answerRevealed) return;
    if (_isSoundPlaying) return;

    setState(() {
      selectedAnswerIndex = index;
      _isTransitioning = true;
    });

    final questionData = currentQuizQuestions[currentQuestion - 1];
    final int correctIndex = questionData['correctAnswer'] as int;
    final bool isCorrect = index == correctIndex;

    _flutterTts.stop();
    _audioPlayer.stop();

    _speakSelectedAnswer(questionData, index).then((_) {
      _waitForSoundThen(() {
        if (_disposed || !mounted) return;
        setState(() {
          _answerRevealed = true;
          _lastAnswerCorrect = isCorrect;
          if (!isCorrect) _showWrongHighlight = true;
        });

        if (isCorrect) {
          _handleCorrectFlow(questionData);
        } else {
          _handleIncorrectFlow();
        }
      });
    });
  }

  void _handleCorrectFlow(Map<String, dynamic> questionData) {
    setState(() => currentScore++);
    _playFeedbackSound(true).then((_) {
      if (mounted) _showAnswerSnackbar(isCorrect: true);
      _waitForSoundThen(() {
        if (_disposed || !mounted) return;
        _flutterTts.stop();
        _showListenRepeatOverlay(
          questionData['audioSentence'] as String,
          onDone: _advanceQuestion,
        );
      });
    });
  }

  void _handleIncorrectFlow() {
    _playFeedbackSound(false).then((_) {
      if (mounted) _showAnswerSnackbar(isCorrect: false);
      _waitForSoundThen(() async {
        if (_disposed || !mounted) return;
        await Future.delayed(const Duration(milliseconds: 300));
        if (_disposed || !mounted) return;
        setState(() {
          _showCorrectHighlight = true;
        });
        await _playQuestionAudio();
        _waitForSoundThen(() {
          if (_disposed || !mounted) return;
          _advanceQuestion();
        });
      });
    });
  }

  void _showListenRepeatOverlay(String word, {required VoidCallback onDone}) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => _ListenRepeatOverlay(
            word: word,
            tts: _flutterTts,
            onDone: () {
              Navigator.of(context).pop();
              onDone();
            },
          ),
    );
  }

  void _waitForSoundThen(VoidCallback callback) {
    if (!_isSoundPlaying) {
      callback();
      return;
    }
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_disposed || !mounted) {
        timer.cancel();
        return;
      }
      if (!_isSoundPlaying) {
        timer.cancel();
        callback();
      }
    });
  }

  void _advanceQuestion() {
    if (_disposed || !mounted) return;
    if (currentQuestion >= totalQuestions) {
      Timer(const Duration(milliseconds: 400), () {
        if (_disposed || !mounted) return;
        _dialogController.forward();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _buildCompletionDialog(),
        );
      });
    } else {
      _flutterTts.stop();
      _audioPlayer.stop();
      Timer(const Duration(milliseconds: 400), () {
        if (_disposed || !mounted) return;
        setState(() {
          currentQuestion++;
          selectedAnswerIndex = null;
          _answerRevealed = false;
          _lastAnswerCorrect = null;
          _showWrongHighlight = false;
          _showCorrectHighlight = false;
          _isTransitioning = false;
          _isSoundPlaying = false;
        });
        Future.delayed(const Duration(milliseconds: 150), () {
          if (_disposed || !mounted) return;
          _playCurrentSound();
        });
      });
    }
  }

  void resetQuiz() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    _selectRandomQuestions();
    setState(() {
      currentScore = 0;
      currentQuestion = 1;
      selectedAnswerIndex = null;
      _answerRevealed = false;
      _lastAnswerCorrect = null;
      _showWrongHighlight = false;
      _showCorrectHighlight = false;
      _exerciseStarted = true;
      _isTransitioning = false;
      _isSoundPlaying = false;
    });
    _dialogController.reset();
    _playCurrentSound();
  }

  void _showAnswerSnackbar({required bool isCorrect}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          decoration: BoxDecoration(
            color:
                isCorrect ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isCorrect ? 'Correct! 🎉' : 'Not quite!',
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      isCorrect
                          ? 'Great job identifying the sentence!'
                          : 'Listen to the correct answer.',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _flutterTts.stop();
    _dialogController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _saveProgress() async {
    final bool wasCompleted = _progressManager.isLessonFullyCompleted(
      'course_three',
      0,
    );

    if (currentScore > _highScore) {
      _highScore = currentScore;
      await _progressManager.updateExerciseHighScore(
        'course_three',
        0,
        'Stage3_Exercise',
        currentScore,
      );
    }
    final shouldMark = (currentScore >= 3) || _wasEverCompleted;
    if (shouldMark) {
      await _progressManager.updateExerciseCompletion(
        'course_three',
        0,
        'Stage3_Exercise',
        true,
      );
      _wasEverCompleted = true;
    }
    _originalHighScore = _highScore;
    _originalWasCompleted = _wasEverCompleted;

    if (!wasCompleted &&
        _progressManager.isLessonFullyCompleted('course_three', 0)) {
      NotificationHelper.onLessonComplete(
        'course_three',
        0,
        'Basic Sentence Patterns',
      );
    }
  }

  // ── COMPLETION DIALOG ────────────────────────────────────────────────────

  Widget _buildCompletionDialog() {
    String starImage;
    String message;
    if (currentScore >= 4) {
      starImage = 'assets/images/threeStar.png';
      message = "Excellent work! You're a quiz master!";
    } else if (currentScore >= 3) {
      starImage = 'assets/images/twoStar.png';
      message = "Great job! You've reached the passing score!";
    } else if (currentScore >= 2) {
      starImage = 'assets/images/oneStar.png';
      message = "Good effort! You're getting there!";
    } else {
      starImage = 'assets/images/zeroStar.png';
      message = "Everyone starts somewhere. Try again!";
    }
    final bool isNewHighScore = currentScore > _highScore;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _dialogScaleAnimation,
        builder:
            (context, _) => Transform.scale(
              scale: _dialogScaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D5C5D),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 20,
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 120,
                            width: 240,
                            child: Image.asset(starImage, fit: BoxFit.contain),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -10),
                            child: const Text(
                              'Total Score',
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 20,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 2),
                                    blurRadius: 2,
                                    color: Color.fromRGBO(0, 0, 0, 0.25),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -24),
                            child: Text(
                              '$currentScore/$totalQuestions',
                              style: const TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 72,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 4),
                                    blurRadius: 2,
                                    color: Color.fromRGBO(0, 0, 0, 0.35),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isNewHighScore && currentScore > 0)
                            Transform.translate(
                              offset: const Offset(0, -20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.5),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.emoji_events,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'New High Score!',
                                      style: TextStyle(
                                        fontFamily: 'Fredoka',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (_highScore > 0)
                            Transform.translate(
                              offset: const Offset(0, -20),
                              child: Text(
                                'High Score: $_highScore/$totalQuestions',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            style: const TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 22),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _TapAnimatedButton(
                              onTap: () async {
                                await _saveProgress();
                                if (mounted) {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const CourseThree(),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.asset(
                                    'assets/images/closeButton.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _TapAnimatedButton(
                            onTap: () async {
                              await _saveProgress();
                              if (mounted) {
                                Navigator.of(context).pop();
                                resetQuiz();
                              }
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset(
                                  'assets/images/restartButton.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                      color: const Color(0xFF9D5C5D),
                      width: 6,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Adventure Paused!',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
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
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          // ─── Cancel button with tap animation ───
                          Expanded(
                            child: _TapAnimatedButton(
                              onTap: () => Navigator.of(ctx).pop(false),
                              child: Container(
                                height: 50,
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Image.asset(
                                  'assets/images/cancelButton.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // ─── Exit button with tap animation ───
                          Expanded(
                            child: _TapAnimatedButton(
                              onTap: () => Navigator.of(ctx).pop(true),
                              child: Container(
                                height: 50,
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Image.asset(
                                  'assets/images/exitButton.png',
                                  fit: BoxFit.cover,
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

  Future<void> _onBackButtonTap() async {
    if (!_exerciseStarted) return;
    _flutterTts.stop();
    _audioPlayer.stop();
    final shouldExit = await _showExitWarningDialog();
    if (shouldExit && context.mounted) {
      await _restoreProgress();
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const CourseThree()));
    } else {
      if (mounted) {
        setState(() => _isSoundPlaying = false);
        _playCurrentSound();
      }
    }
  }

  // ── IMAGE CHOICE BUTTON ──────────────────────────────────────────────────

  Widget _buildImageChoice({
    required int index,
    required Map<String, String> answer,
    required int correctIndex,
  }) {
    final bool isSelected = selectedAnswerIndex == index;

    // ── Revealed state colours ──
    Color borderColor;
    Color overlayColor;
    Widget? badge;

    if (_answerRevealed) {
      if (_lastAnswerCorrect == true) {
        if (index == correctIndex) {
          borderColor = const Color(0xFF4CAF50);
          overlayColor = const Color(0xFF4CAF50).withOpacity(0.25);
          badge = _revealBadge(Icons.check_circle, const Color(0xFF4CAF50));
        } else {
          borderColor = Colors.white;
          overlayColor = Colors.transparent;
          badge = null;
        }
      } else if (_showCorrectHighlight) {
        if (index == correctIndex) {
          borderColor = const Color(0xFF4CAF50);
          overlayColor = const Color(0xFF4CAF50).withOpacity(0.25);
          badge = _revealBadge(Icons.check_circle, const Color(0xFF4CAF50));
        } else {
          borderColor = const Color(0xFFE53935);
          overlayColor = const Color(0xFFE53935).withOpacity(0.15);
          badge = _revealBadge(Icons.cancel, const Color(0xFFE53935));
        }
      } else if (_showWrongHighlight && index == selectedAnswerIndex) {
        borderColor = const Color(0xFFE53935);
        overlayColor = const Color(0xFFE53935).withOpacity(0.25);
        badge = _revealBadge(Icons.cancel, const Color(0xFFE53935));
      } else {
        borderColor = Colors.white;
        overlayColor = Colors.transparent;
        badge = null;
      }
    } else {
      // Normal selection state
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

    // Dim tiles that are not selected while sound is playing (pre-reveal only)
    final bool dimmed =
        _isSoundPlaying && !_answerRevealed && selectedAnswerIndex != index;

    return GestureDetector(
      onTap: () => selectAnswer(index),
      child: AnimatedOpacity(
        opacity: dimmed ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 4),
            boxShadow: [
              BoxShadow(
                color:
                    _answerRevealed
                        ? borderColor.withOpacity(0.35)
                        : isSelected
                        ? Colors.orange.withOpacity(0.4)
                        : Colors.black.withOpacity(0.15),
                blurRadius: _answerRevealed || isSelected ? 10 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset(
                    answer['image']!,
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
                // Colour overlay
                if (overlayColor != Colors.transparent)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: overlayColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                // Badge (check / cancel / orange check)
                if (badge != null) Positioned(top: 8, right: 8, child: badge),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Small circular badge used in the revealed state.
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

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double progress = currentQuestion / totalQuestions;
    final questionData =
        currentQuestion <= currentQuizQuestions.length
            ? currentQuizQuestions[currentQuestion - 1]
            : null;
    final List<Map<String, String>> answers =
        questionData != null
            ? (questionData['answers'] as List)
                .map((e) => Map<String, String>.from(e as Map))
                .toList()
            : [];
    final int correctIndex =
        questionData != null ? questionData['correctAnswer'] as int : -1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onBackButtonTap();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE8B6B7),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TapAnimatedButton(
                      onTap: _onBackButtonTap,
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
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '$currentScore of $totalQuestions',
                            style: const TextStyle(
                              fontSize: 18,
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w400,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                                tween: Tween<double>(begin: 0, end: progress),
                                builder:
                                    (_, value, __) => LinearProgressIndicator(
                                      value: value,
                                      backgroundColor: Colors.transparent,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Colors.orange,
                                          ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '$currentQuestion of $totalQuestions',
                            style: const TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      width: 6,
                      color: const Color(0xFF9D5C5D),
                    ),
                    color: const Color(0xFFFFFCF2),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '"Tap the sentence you hear."',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      AnimatedOpacity(
                        opacity: _isSoundPlaying ? 0.5 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: _TapAnimatedButton(
                          onTap: _isSoundPlaying ? () {} : _playQuestionAudio,
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: Image.asset(
                              'assets/images/soundButton.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child:
                      answers.length == 3
                          ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildImageChoice(
                                      index: 0,
                                      answer: answers[0],
                                      correctIndex: correctIndex,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildImageChoice(
                                      index: 1,
                                      answer: answers[1],
                                      correctIndex: correctIndex,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final itemWidth =
                                      (constraints.maxWidth - 10) / 2;
                                  return SizedBox(
                                    width: itemWidth,
                                    child: _buildImageChoice(
                                      index: 2,
                                      answer: answers[2],
                                      correctIndex: correctIndex,
                                    ),
                                  );
                                },
                              ),
                            ],
                          )
                          : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Listen & Repeat Overlay ───────────────────────────────────────────────────
class _ListenRepeatOverlay extends StatefulWidget {
  final String word;
  final FlutterTts tts;
  final VoidCallback onDone;

  const _ListenRepeatOverlay({
    required this.word,
    required this.tts,
    required this.onDone,
  });

  @override
  State<_ListenRepeatOverlay> createState() => _ListenRepeatOverlayState();
}

class _ListenRepeatOverlayState extends State<_ListenRepeatOverlay>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _attempted = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.stop();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakWord());
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize();
    if (mounted) setState(() => _speechAvailable = available);
  }

  Future<void> _speakWord({bool wordOnly = false}) async {
    if (!mounted || _isSpeaking) return;
    setState(() => _isSpeaking = true);
    try {
      await widget.tts.stop();
      await widget.tts.setSpeechRate(0.4);
      if (wordOnly) {
        widget.tts.setCompletionHandler(() {
          if (mounted) setState(() => _isSpeaking = false);
        });
        await widget.tts.speak(widget.word);
      } else {
        widget.tts.setCompletionHandler(() async {
          if (!mounted) return;
          await Future.delayed(const Duration(milliseconds: 400));
          if (!mounted) return;
          widget.tts.setCompletionHandler(() {
            if (mounted) setState(() => _isSpeaking = false);
          });
          await widget.tts.speak(widget.word);
        });
        await widget.tts.speak('Repeat the sentence');
      }
    } catch (e) {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<void> _startListening() async {
    if (_attempted || _isListening || _isSpeaking || !_speechAvailable) return;
    setState(() {
      _isListening = true;
      _attempted = true;
    });
    _pulseController.repeat(reverse: true);
    await _speech.listen(
      onResult: (_) {},
      listenFor: const Duration(seconds: 4),
      pauseFor: const Duration(seconds: 2),
      localeId: 'en_US',
    );
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) {
      await _speech.stop();
      _pulseController.stop();
      setState(() => _isListening = false);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) widget.onDone();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFCF2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Listen & Repeat',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9D5C5D),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Say the sentence out loud!',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 16,
              fontWeight: FontWeight.w300,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _isListening ? null : () => _speakWord(wordOnly: true),
            child: AnimatedOpacity(
              opacity: (_isSpeaking || _isListening) ? 0.6 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF9D5C5D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.word,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 34),
          GestureDetector(
            onTap: _startListening,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isListening ? _pulseAnimation.value : 1.0,
                  child: child,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color:
                      _isListening
                          ? const Color(0xFFFFEBEE)
                          : _attempted
                          ? Colors.grey.shade100
                          : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color:
                        _isListening
                            ? const Color(0xFFE53935)
                            : _attempted
                            ? Colors.grey.shade300
                            : const Color(0xFF4CAF50),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    _isListening
                        ? 'assets/images/micActive.png'
                        : 'assets/images/micInactive.png',
                    width: 42,
                    height: 42,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isListening
                ? 'Listening...'
                : _attempted
                ? 'Done!'
                : 'Tap to speak',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: _isListening ? const Color(0xFFE53935) : Colors.black45,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Reusable tap-bounce button wrapper ───────────────────────────────────────
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
