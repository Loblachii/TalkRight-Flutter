import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'dart:math';
import 'settings_manager.dart';
import 'progress_manager.dart';
import 'courseTwo.dart';
import 'notification_helper.dart';

class CourseTwoLec1Exercise extends StatefulWidget {
  const CourseTwoLec1Exercise({super.key});

  @override
  State<CourseTwoLec1Exercise> createState() => _CourseTwoLec1ExerciseState();
}

class _CourseTwoLec1ExerciseState extends State<CourseTwoLec1Exercise>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _highScore = 0;
  int currentScore = 0;
  int currentQuestion = 1;
  final int totalQuestions = 5;
  int _originalHighScore = 0;
  bool _originalWasCompleted = false;
  bool _isPlayingPrompt = false;
  int? selectedAnswerIndex;

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
  bool _isSoundPlaying = false;

  final List<Map<String, dynamic>> allQuizData = [
    {
      'questionSound': 'chair',
      'answers': [
        {'label': 'ch', 'sound': 'chDigraph.m4a'},
        {'label': 'sh', 'sound': 'shDigraph.m4a'},
        {'label': 'th', 'sound': 'thDigraph.m4a'},
      ],
      'correctAnswer': 0,
    },
    {
      'questionSound': 'ship',
      'answers': [
        {'label': 'sh', 'sound': 'shDigraph.m4a'},
        {'label': 'wh', 'sound': 'whDigraph.m4a'},
        {'label': 'ch', 'sound': 'chDigraph.m4a'},
      ],
      'correctAnswer': 0,
    },
    {
      'questionSound': 'thumb',
      'answers': [
        {'label': 'th', 'sound': 'thDigraph.m4a'},
        {'label': 'ng', 'sound': 'ngDigraph.m4a'},
        {'label': 'sh', 'sound': 'shDigraph.m4a'},
      ],
      'correctAnswer': 0,
    },
    {
      'questionSound': 'whale',
      'answers': [
        {'label': 'wh', 'sound': 'whDigraph.m4a'},
        {'label': 'ch', 'sound': 'chDigraph.m4a'},
        {'label': 'ng', 'sound': 'ngDigraph.m4a'},
      ],
      'correctAnswer': 0,
    },
    {
      'questionSound': 'ring',
      'answers': [
        {'label': 'wh', 'sound': 'whDigraph.m4a'},
        {'label': 'ng', 'sound': 'ngDigraph.m4a'},
        {'label': 'ch', 'sound': 'chDigraph.m4a'},
      ],
      'correctAnswer': 1,
    },
    {
      'questionSound': 'this',
      'answers': [
        {'label': 'sh', 'sound': 'shDigraph.m4a'},
        {'label': 'th', 'sound': 'th1Digraph.m4a'},
        {'label': 'wh', 'sound': 'whDigraph.m4a'},
      ],
      'correctAnswer': 1,
    },
    {
      'questionSound': 'chicken',
      'answers': [
        {'label': 'ng', 'sound': 'ngDigraph.m4a'},
        {'label': 'ch', 'sound': 'chDigraph.m4a'},
        {'label': 'th', 'sound': 'thDigraph.m4a'},
      ],
      'correctAnswer': 1,
    },
    {
      'questionSound': 'shoe',
      'answers': [
        {'label': 'th', 'sound': 'th1Digraph.m4a'},
        {'label': 'wh', 'sound': 'whDigraph.m4a'},
        {'label': 'sh', 'sound': 'shDigraph.m4a'},
      ],
      'correctAnswer': 2,
    },
    {
      'questionSound': 'that',
      'answers': [
        {'label': 'ch', 'sound': 'chDigraph.m4a'},
        {'label': 'sh', 'sound': 'shDigraph.m4a'},
        {'label': 'th', 'sound': 'th1Digraph.m4a'},
      ],
      'correctAnswer': 2,
    },
    {
      'questionSound': 'sing',
      'answers': [
        {'label': 'th', 'sound': 'thDigraph.m4a'},
        {'label': 'wh', 'sound': 'whDigraph.m4a'},
        {'label': 'ng', 'sound': 'ngDigraph.m4a'},
      ],
      'correctAnswer': 2,
    },
  ];

  String _displayLabel(String raw) => raw;

  Future<void> _restoreProgress() async {
    _progressManager.forceSetHighScore(
      'course_two',
      0,
      'Stage2_Exercise',
      _originalHighScore,
    );
    await _progressManager.updateExerciseCompletion(
      'course_two',
      0,
      'Stage2_Exercise',
      _originalWasCompleted,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _highScore = _progressManager.getExerciseHighScore(
      'course_two',
      0,
      'Stage2_Exercise',
    );
    _wasEverCompleted = _progressManager.isExerciseCompleted(
      'course_two',
      0,
      'Stage2_Exercise',
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

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted && !_disposed) setState(() => _isSoundPlaying = false);
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
        setState(() {
          _isSoundPlaying = false;
        });
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
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  Future<void> _playCurrentSound() async {
    if (_disposed || !mounted) return;
    if (currentQuestion > currentQuizQuestions.length) return;
    if (_isSoundPlaying) return;

    setState(() {
      _isSoundPlaying = true;
      _isPlayingPrompt = true;
    });

    _flutterTts.setCompletionHandler(() {
      if (!_disposed && mounted) {
        if (_isPlayingPrompt) {
          _isPlayingPrompt = false;
          setState(() => _isSoundPlaying = false);
          _playQuestionAudio();
        } else {
          setState(() => _isSoundPlaying = false);
        }
      }
    });

    try {
      await _flutterTts.stop();
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.speak('Tap the sound you hear.');
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _isPlayingPrompt = false;
      setState(() => _isSoundPlaying = false);
      _playQuestionAudio();
    }
  }

  Future<void> _playQuestionAudio() async {
    if (_disposed || !mounted) return;
    if (currentQuestion > currentQuizQuestions.length) return;
    if (_isSoundPlaying) return;

    final String word =
        currentQuizQuestions[currentQuestion - 1]['questionSound'] as String;

    setState(() => _isSoundPlaying = true);
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(word);
    } catch (e) {
      debugPrint('TTS question audio error: $e');
      setState(() => _isSoundPlaying = false);
    }
  }

  Future<void> _playAsset(String fileName) async {
    if (_disposed || !mounted) return;
    setState(() => _isSoundPlaying = true);
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(SettingsManager.speechOutputVolume);
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint('Audio play error: $e');
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

  void selectAnswer(int index) {
    if (!_exerciseStarted || _isTransitioning || _disposed) return;
    if (_answerRevealed) return;
    if (_isSoundPlaying) return;

    final questionData = currentQuizQuestions[currentQuestion - 1];
    final int correctIndex = questionData['correctAnswer'] as int;
    final bool isCorrect = index == correctIndex;

    setState(() {
      selectedAnswerIndex = index;
      _isTransitioning = true;
    });

    _flutterTts.stop();

    final answers = questionData['answers'] as List<dynamic>;
    final String selectedSound = (answers[index] as Map)['sound'] as String;

    _playAsset(selectedSound).then((_) {
      _waitForSoundThen(() {
        if (_disposed || !mounted) return;

        setState(() {
          _answerRevealed = true;
          _lastAnswerCorrect = isCorrect;
          if (!isCorrect) _showWrongHighlight = true;
        });

        if (isCorrect) {
          _handleCorrectFlow(index, questionData);
        } else {
          _handleIncorrectFlow(index, correctIndex, questionData);
        }
      });
    });
  }

  void _handleCorrectFlow(
    int selectedIndex,
    Map<String, dynamic> questionData,
  ) {
    setState(() => currentScore++);

    _playFeedbackSound(true).then((_) {
      if (mounted) _showAnswerSnackbar(isCorrect: true);
      _waitForSoundThen(() {
        if (_disposed || !mounted) return;
        _flutterTts.stop();
        _showListenRepeatOverlay(
          questionData['questionSound'] as String,
          onDone: _advanceQuestion,
        );
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

  void _handleIncorrectFlow(
    int selectedIndex,
    int correctIndex,
    Map<String, dynamic> questionData,
  ) {
    final answers = questionData['answers'] as List<dynamic>;
    final String correctSound =
        (answers[correctIndex] as Map)['sound'] as String;

    _playFeedbackSound(false).then((_) {
      if (mounted) _showAnswerSnackbar(isCorrect: false);

      _waitForSoundThen(() async {
        if (_disposed || !mounted) return;

        await Future.delayed(const Duration(milliseconds: 300));
        if (_disposed || !mounted) return;

        setState(() => _showCorrectHighlight = true);

        await _playAsset(correctSound);

        _waitForSoundThen(() {
          if (_disposed || !mounted) return;
          _advanceQuestion();
        });
      });
    });
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
          _isPlayingPrompt = false;
        });
        Future.delayed(const Duration(milliseconds: 150), () {
          if (_disposed || !mounted) return;
          _playCurrentSound();
        });
      });
    }
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
            boxShadow: [
              BoxShadow(
                color: (isCorrect
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFE53935))
                    .withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
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
                          ? 'Great job identifying that sound!'
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

  _AnswerTileStyle _tileStyle(int index, int correctIndex) {
    final _AnswerTileStyle neutral = _AnswerTileStyle(
      background: Colors.white,
      borderColor: Colors.grey.shade300,
      borderWidth: 1,
      textColor: Colors.black87,
      trailingIcon: null,
      trailingColor: Colors.grey.shade400,
      shadowColor: Colors.black.withOpacity(0.05),
      shadowBlur: 4,
    );

    if (!_answerRevealed) {
      final bool isSelected = selectedAnswerIndex == index;
      if (!isSelected) return neutral;
      return _AnswerTileStyle(
        background: Colors.orange.shade50,
        borderColor: Colors.orange,
        borderWidth: 2,
        textColor: Colors.orange.shade700,
        trailingIcon: const Icon(Icons.check, color: Colors.white, size: 14),
        trailingColor: Colors.orange,
        shadowColor: Colors.orange.withOpacity(0.15),
        shadowBlur: 8,
      );
    }

    if (_lastAnswerCorrect == true) {
      if (index == correctIndex) {
        return _AnswerTileStyle(
          background: const Color(0xFFE8F5E9),
          borderColor: const Color(0xFF4CAF50),
          borderWidth: 2.5,
          textColor: const Color(0xFF2E7D32),
          trailingIcon: const Icon(
            Icons.check_circle,
            color: Color(0xFF4CAF50),
            size: 20,
          ),
          trailingColor: Colors.transparent,
          shadowColor: const Color(0xFF4CAF50).withOpacity(0.25),
          shadowBlur: 10,
        );
      }
      return neutral;
    }

    if (_lastAnswerCorrect == false) {
      if (_showCorrectHighlight) {
        if (index == correctIndex) {
          return _AnswerTileStyle(
            background: const Color(0xFFE8F5E9),
            borderColor: const Color(0xFF4CAF50),
            borderWidth: 2.5,
            textColor: const Color(0xFF2E7D32),
            trailingIcon: const Icon(
              Icons.check_circle,
              color: Color(0xFF4CAF50),
              size: 20,
            ),
            trailingColor: Colors.transparent,
            shadowColor: const Color(0xFF4CAF50).withOpacity(0.25),
            shadowBlur: 10,
          );
        }
        return _AnswerTileStyle(
          background: const Color(0xFFFFEBEE),
          borderColor: const Color(0xFFE53935),
          borderWidth: 2.5,
          textColor: const Color(0xFFC62828),
          trailingIcon: const Icon(
            Icons.cancel,
            color: Color(0xFFE53935),
            size: 20,
          ),
          trailingColor: Colors.transparent,
          shadowColor: const Color(0xFFE53935).withOpacity(0.25),
          shadowBlur: 10,
        );
      }

      if (_showWrongHighlight) {
        if (index == selectedAnswerIndex) {
          return _AnswerTileStyle(
            background: const Color(0xFFFFEBEE),
            borderColor: const Color(0xFFE53935),
            borderWidth: 2.5,
            textColor: const Color(0xFFC62828),
            trailingIcon: const Icon(
              Icons.cancel,
              color: Color(0xFFE53935),
              size: 20,
            ),
            trailingColor: Colors.transparent,
            shadowColor: const Color(0xFFE53935).withOpacity(0.25),
            shadowBlur: 10,
          );
        }
        return neutral;
      }
    }

    return neutral;
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
                        color: const Color(0xFF41596D),
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
                                      builder: (_) => const CourseTwo(),
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
                      color: const Color(0xFF41596D),
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

  Future<void> _saveProgress() async {
    final bool wasCompleted = _progressManager.isLessonFullyCompleted(
      'course_two',
      0,
    );

    if (currentScore > _highScore) {
      _highScore = currentScore;
      await _progressManager.updateExerciseHighScore(
        'course_two',
        0,
        'Stage2_Exercise',
        currentScore,
      );
    }
    final shouldMark = (currentScore >= 3) || _wasEverCompleted;
    if (shouldMark) {
      await _progressManager.updateExerciseCompletion(
        'course_two',
        0,
        'Stage2_Exercise',
        true,
      );
      _wasEverCompleted = true;
    }
    _originalHighScore = _highScore;
    _originalWasCompleted = _wasEverCompleted;

    if (!wasCompleted &&
        _progressManager.isLessonFullyCompleted('course_two', 0)) {
      NotificationHelper.onLessonComplete('course_two', 0, 'Compound Sounds');
    }
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
      ).pushReplacement(MaterialPageRoute(builder: (_) => const CourseTwo()));
    } else {
      if (mounted) {
        setState(() => _isSoundPlaying = false);
        _playCurrentSound();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = currentQuestion / totalQuestions;
    final questionData =
        currentQuestion <= currentQuizQuestions.length
            ? currentQuizQuestions[currentQuestion - 1]
            : null;
    final List<Map<String, String>> answers =
        questionData != null
            ? List<Map<String, String>>.from(
              (questionData['answers'] as List).map(
                (e) => Map<String, String>.from(e as Map),
              ),
            )
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
        backgroundColor: const Color(0xFFB6DAE8),
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 28,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF41596D),
                            width: 6,
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
                              '"Tap the sound you hear."',
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 20,
                                fontWeight: FontWeight.w400,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            AnimatedOpacity(
                              opacity: _isSoundPlaying ? 0.5 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: _TapAnimatedButton(
                                onTap:
                                    _isSoundPlaying
                                        ? () {}
                                        : _playQuestionAudio,
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
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
                      if (questionData != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 100),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(answers.length, (index) {
                              final style = _tileStyle(index, correctIndex);
                              final bool dimmed =
                                  _isSoundPlaying &&
                                  !_answerRevealed &&
                                  selectedAnswerIndex != index;
                              final String label = _displayLabel(
                                answers[index]['label']!,
                              );

                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index < answers.length - 1 ? 12 : 0,
                                ),
                                child: GestureDetector(
                                  onTap: () => selectAnswer(index),
                                  child: AnimatedOpacity(
                                    opacity: dimmed ? 0.45 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOut,
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: style.background,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: style.borderColor,
                                          width: style.borderWidth,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: style.shadowColor,
                                            blurRadius: style.shadowBlur,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontFamily: 'Fredoka',
                                              fontWeight: FontWeight.w400,
                                              color: style.textColor,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (style.trailingIcon != null &&
                                              style.trailingColor ==
                                                  Colors.transparent)
                                            style.trailingIcon!
                                          else
                                            Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: style.trailingColor,
                                              ),
                                              child: style.trailingIcon,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
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

    // Auto-play: "Repeat the word" + pause + target word
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
        // Tapping the word tile → just say the word
        widget.tts.setCompletionHandler(() {
          if (mounted) setState(() => _isSpeaking = false);
        });
        await widget.tts.speak(widget.word);
      } else {
        // Default (auto-play on open) → "Repeat the word" + pause + target word
        widget.tts.setCompletionHandler(() async {
          if (!mounted) return;
          await Future.delayed(const Duration(milliseconds: 400));
          if (!mounted) return;
          widget.tts.setCompletionHandler(() {
            if (mounted) setState(() => _isSpeaking = false);
          });
          await widget.tts.speak(widget.word);
        });
        await widget.tts.speak('Repeat the word');
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
          // ── Drag handle ──
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 28),

          // ── SECTION 1: Header ──
          const Text(
            'Listen & Repeat',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Color(0xFF41596D),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Say the word out loud!',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 16,
              fontWeight: FontWeight.w300,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 32),

          // ── SECTION 2: Body — target word (tap to replay word only) ──
          GestureDetector(
            onTap: _isListening ? null : () => _speakWord(wordOnly: true),
            child: AnimatedOpacity(
              opacity: (_isSpeaking || _isListening) ? 0.6 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF41596D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.word,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // ── SECTION 3: Bottom — mic ──
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

// ── Helper class for tile styling ────────────────────────────────────────────

class _AnswerTileStyle {
  final Color background;
  final Color borderColor;
  final double borderWidth;
  final Color textColor;
  final Widget? trailingIcon;
  final Color trailingColor;
  final Color shadowColor;
  final double shadowBlur;

  const _AnswerTileStyle({
    required this.background,
    required this.borderColor,
    required this.borderWidth,
    required this.textColor,
    required this.trailingIcon,
    required this.trailingColor,
    required this.shadowColor,
    required this.shadowBlur,
  });
}
