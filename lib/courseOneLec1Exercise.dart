import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:math';
import 'settings_manager.dart';
import 'progress_manager.dart';
import 'courseOne.dart';
import 'notification_helper.dart';

class CourseOneLec1Exercise extends StatefulWidget {
  const CourseOneLec1Exercise({super.key});

  @override
  State<CourseOneLec1Exercise> createState() => _CourseOneLec1ExerciseState();
}

class _CourseOneLec1ExerciseState extends State<CourseOneLec1Exercise>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _highScore = 0;
  int currentScore = 0;
  int currentQuestion = 1;
  final int totalQuestions = 5;
  int _originalHighScore = 0;
  bool _originalWasCompleted = false;
  int? selectedAnswerIndex;

  // ─── Answer reveal state ───
  bool _answerRevealed = false;
  bool? _lastAnswerCorrect;
  bool _showWrongHighlight = false; // red tile visible
  bool _showCorrectHighlight = false; // green tile(s) visible

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

  final List<Map<String, dynamic>> allQuizData = [
    {
      'sound': 'bSound.m4a',
      'answers': ['M', 'S', 'B'],
      'correctAnswer': 2,
    },
    {
      'sound': 'mSound.m4a',
      'answers': ['B', 'M', 'T'],
      'correctAnswer': 1,
    },
    {
      'sound': 'sSound.m4a',
      'answers': ['F', 'P', 'S'],
      'correctAnswer': 2,
    },
    {
      'sound': 'tSound.m4a',
      'answers': ['D', 'T', 'L'],
      'correctAnswer': 1,
    },
    {
      'sound': 'pSound.m4a',
      'answers': ['P', 'B', 'K'],
      'correctAnswer': 0,
    },
    {
      'sound': 'kSound.m4a',
      'answers': ['C', 'G', 'T'],
      'correctAnswer': 0,
    },
    {
      'sound': 'dSound.m4a',
      'answers': ['T', 'N', 'D'],
      'correctAnswer': 2,
    },
    {
      'sound': 'nSound.m4a',
      'answers': ['M', 'N', 'H'],
      'correctAnswer': 1,
    },
    {
      'sound': 'fSound.m4a',
      'answers': ['F', 'V', 'S'],
      'correctAnswer': 0,
    },
    {
      'sound': 'lSound.m4a',
      'answers': ['R', 'B', 'L'],
      'correctAnswer': 2,
    },
  ];

  Future<void> _restoreProgress() async {
    _progressManager.forceSetHighScore(
      'course_one',
      0,
      'Stage1_Exercise',
      _originalHighScore,
    );
    await _progressManager.updateExerciseCompletion(
      'course_one',
      0,
      'Stage1_Exercise',
      _originalWasCompleted,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _highScore = _progressManager.getExerciseHighScore(
      'course_one',
      0,
      'Stage1_Exercise',
    );
    _wasEverCompleted = _progressManager.isExerciseCompleted(
      'course_one',
      0,
      'Stage1_Exercise',
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

      _flutterTts.setCompletionHandler(() {
        if (!_disposed && mounted) {
          setState(() => _isSoundPlaying = false);
          _playLetterSound();
        }
      });
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  Future<void> _playCurrentSound() async {
    if (_disposed || !mounted) return;
    if (currentQuestion > currentQuizQuestions.length) return;
    if (_isSoundPlaying) return;

    setState(() => _isSoundPlaying = true);
    try {
      await _flutterTts.stop();
      await _audioPlayer.stop();
      await _flutterTts.speak("Tap the sound you hear.");
    } catch (e) {
      debugPrint('TTS speak error: $e');
      setState(() => _isSoundPlaying = false);
      _playLetterSound();
    }
  }

  Future<void> _playLetterSound() async {
    if (_disposed || !mounted) return;
    if (currentQuestion > currentQuizQuestions.length) return;
    if (_isSoundPlaying) return;

    final soundFile =
        currentQuizQuestions[currentQuestion - 1]['sound'] as String;
    await _playAsset(soundFile);
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

  String _soundFileForLabel(String label) {
    const map = {
      'B': 'bSound.m4a',
      'M': 'mSound.m4a',
      'S': 'sSound.m4a',
      'T': 'tSound.m4a',
      'P': 'pSound.m4a',
      'C': 'kSound.m4a',
      'G': 'gSound.m4a',
      'D': 'dSound.m4a',
      'N': 'nSound.m4a',
      'F': 'fSound.m4a',
      'V': 'vSound.m4a',
      'L': 'lSound.m4a',
      'R': 'rSound.m4a',
      'K': 'kSound.m4a',
      'H': 'hSound.m4a',
    };
    return map[label] ?? '${label.toLowerCase()}Sound.m4a';
  }

  // ── Answer tap flow ──────────────────────────────────────────────────────
  //
  // Step 1  Tap → orange pre-select only (no correct/wrong indicator yet),
  //         lock further taps, play tapped letter's sound.
  //
  // Step 2  Letter sound finishes → reveal result highlight + snackbar
  //         + feedback sound.
  //
  // CORRECT path:
  //   • Green highlight on selected tile
  //   • Feedback sound plays
  //   • After feedback sound → advance
  //
  // WRONG path:
  //   • Only the selected tile turns red + snackbar + wrong feedback sound
  //   • After feedback sound → 300 ms pause →
  //     all tiles show full indicators (correct = green, rest = red)
  //     + correct letter sound plays → advance

  void selectAnswer(int index) {
    if (!_exerciseStarted || _isTransitioning || _disposed) return;
    if (_answerRevealed) return;
    if (_isSoundPlaying) return;

    final questionData = currentQuizQuestions[currentQuestion - 1];
    final int correctIndex = questionData['correctAnswer'] as int;
    final bool isCorrect = index == correctIndex;

    // Step 1: orange pre-select only, lock input, play tapped letter's sound
    setState(() {
      selectedAnswerIndex = index;
      _isTransitioning = true;
    });

    _flutterTts.stop();

    final String selectedLabel = questionData['answers'][index] as String;
    final String selectedSound = _soundFileForLabel(selectedLabel);

    _playAsset(selectedSound).then((_) {
      _waitForSoundThen(() {
        if (_disposed || !mounted) return;

        // Step 2: letter sound done — now reveal result
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

  // ── Correct answer flow ──────────────────────────────────────────────────
  // (green highlight already shown above before this is called)
  // 1. Increment score
  // 2. Play feedback sound + show snackbar
  // 3. After feedback sound → advance

  void _handleCorrectFlow(
    int selectedIndex,
    Map<String, dynamic> questionData,
  ) {
    setState(() => currentScore++);

    _playFeedbackSound(true).then((_) {
      if (mounted) _showAnswerSnackbar(isCorrect: true);
      _waitForSoundThen(() {
        if (_disposed || !mounted) return;
        _advanceQuestion();
      });
    });
  }

  // ── Incorrect answer flow ────────────────────────────────────────────────
  // (only selected tile is red when this is called)
  // 1. Play wrong feedback sound + show snackbar
  // 2. After feedback sound → 300 ms pause →
  //    reveal ALL tile indicators (correct = green, others = red)
  // 3. Play correct letter's sound
  // 4. After correct sound → advance

  void _handleIncorrectFlow(
    int selectedIndex,
    int correctIndex,
    Map<String, dynamic> questionData,
  ) {
    final String correctLabel = questionData['answers'][correctIndex] as String;
    final String correctSound = _soundFileForLabel(correctLabel);

    // Step 1: wrong feedback sound + snackbar — only selected tile is red
    _playFeedbackSound(false).then((_) {
      if (mounted) _showAnswerSnackbar(isCorrect: false);

      // Step 2: wait for feedback sound to finish
      _waitForSoundThen(() async {
        if (_disposed || !mounted) return;

        // Brief pause before the full reveal
        await Future.delayed(const Duration(milliseconds: 300));
        if (_disposed || !mounted) return;

        // Reveal all tile indicators:
        //   _showCorrectHighlight = true  →  _tileStyle returns green for correct,
        //                                    red for all wrong tiles
        setState(() => _showCorrectHighlight = true);

        // Step 3: play the correct letter's sound
        await _playAsset(correctSound);

        // Step 4: after correct sound finishes → advance
        _waitForSoundThen(() {
          if (_disposed || !mounted) return;
          _advanceQuestion();
        });
      });
    });
  }

  /// Waits for the current audio to finish, then calls [callback].
  /// Uses a polling timer to handle cases where onPlayerComplete already fired.
  void _waitForSoundThen(VoidCallback callback) {
    if (!_isSoundPlaying) {
      callback();
      return;
    }
    // Poll every 100ms until sound is done
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
        _playCurrentSound();
      });
    }
  }

  // ── Snackbar ─────────────────────────────────────────────────────────────

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
    // ── Neutral tile (default) ──
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

    // ── PRE-REVEAL: orange pre-selection highlight only ──
    // _answerRevealed is false while the tapped letter sound is playing.
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

    // ── POST-REVEAL: CORRECT SUBMISSION ──
    // Only the correct tile (== selected tile) goes green; all others neutral.
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

    // ── POST-REVEAL: INCORRECT SUBMISSION — three explicit stages ──
    //
    // Stage 1  _showWrongHighlight=true,  _showCorrectHighlight=false
    //          → ONLY the tapped (selected) tile = red. All others = neutral.
    //
    // Stage 2  _showCorrectHighlight=true
    //          → Correct tile = green. ALL other tiles (including selected) = red.
    //
    // (There is no longer an intermediate all-neutral gap stage.)

    if (_lastAnswerCorrect == false) {
      // Stage 2 — full reveal: correct = green, all wrong tiles = red
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
        // Every non-correct tile shows red
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

      // Stage 1 — only the selected (wrong) tile is red; correct tile stays neutral
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
        // All other tiles (including correct) stay neutral in Stage 1
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

  // ── DIALOGS ──────────────────────────────────────────────────────────────

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
                        color: const Color(0xFF61CE7E),
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
                                      builder: (_) => const CourseOne(),
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
                      color: const Color(0xFF4A7C59),
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
      'course_one',
      0,
    );

    if (currentScore > _highScore) {
      _highScore = currentScore;
      await _progressManager.updateExerciseHighScore(
        'course_one',
        0,
        'Stage1_Exercise',
        currentScore,
      );
    }
    final shouldMark = (currentScore >= 3) || _wasEverCompleted;
    if (shouldMark) {
      await _progressManager.updateExerciseCompletion(
        'course_one',
        0,
        'Stage1_Exercise',
        true,
      );
      _wasEverCompleted = true;
    }
    _originalHighScore = _highScore;
    _originalWasCompleted = _wasEverCompleted;

    if (!wasCompleted &&
        _progressManager.isLessonFullyCompleted('course_one', 0)) {
      NotificationHelper.onLessonComplete(
        'course_one',
        0,
        'Introduction to Phonemes',
      );
    }
  }

  // ── Back button handler ───────────────────────────────────────────────────

  Future<void> _onBackButtonTap() async {
    if (!_exerciseStarted) return;
    _flutterTts.stop();
    _audioPlayer.stop();
    final shouldExit = await _showExitWarningDialog();
    if (shouldExit && context.mounted) {
      await _restoreProgress();
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const CourseOne()));
    } else {
      if (mounted) {
        setState(() => _isSoundPlaying = false);
        _playCurrentSound();
      }
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double progress = currentQuestion / totalQuestions;
    final questionData =
        currentQuestion <= currentQuizQuestions.length
            ? currentQuizQuestions[currentQuestion - 1]
            : null;
    final answers = questionData != null ? questionData['answers'] as List : [];
    final int correctIndex =
        questionData != null ? questionData['correctAnswer'] as int : -1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onBackButtonTap();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFB6E8C1),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // ── SECTION 1: HEADER ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Row 1: Back button ──
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

                        // ── Row 2: Score | Progress bar | Question counter ──
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
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
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
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: progress,
                                    ),
                                    builder:
                                        (_, value, __) =>
                                            LinearProgressIndicator(
                                              value: value,
                                              backgroundColor:
                                                  Colors.transparent,
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                    Color
                                                  >(Colors.orange),
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

                  // ── SECTION 2: BODY + CHOICES (fills remaining space) ────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // ── Sound prompt card ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 28,
                              horizontal: 24,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF577E5F),
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
                                            : _playLetterSound,
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

                          // ── Choices ──
                          if (questionData != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 100),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(answers.length, (
                                  index,
                                ) {
                                  final style = _tileStyle(index, correctIndex);
                                  final bool dimmed =
                                      _isSoundPlaying &&
                                      !_answerRevealed &&
                                      selectedAnswerIndex != index;

                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          index < answers.length - 1 ? 12 : 0,
                                    ),
                                    child: GestureDetector(
                                      onTap: () => selectAnswer(index),
                                      child: AnimatedOpacity(
                                        opacity: dimmed ? 0.45 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
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
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
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
                                                answers[index] as String,
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
          ],
        ),
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
