import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:math';
import 'settings_manager.dart';
import 'progress_manager.dart';
import 'courseOne.dart';
import 'notification_helper.dart';

class CourseOneLec4Exercise extends StatefulWidget {
  const CourseOneLec4Exercise({super.key});

  @override
  State<CourseOneLec4Exercise> createState() => _CourseOneLec4ExerciseState();
}

class _CourseOneLec4ExerciseState extends State<CourseOneLec4Exercise>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _highScore = 0;
  int currentScore = 0;
  int currentQuestion = 1;
  final int totalQuestions = 5;
  int _originalHighScore = 0;
  bool _originalWasCompleted = false;

  // 3 answer slots
  List<String> arrangedLetters = ['', '', ''];

  // ─── Answer reveal state ───
  bool _answerRevealed =
      false; // true after Next is pressed, until next question loads
  bool? _lastAnswerCorrect; // whether the submitted answer was correct

  late AnimationController _dialogController;
  late Animation<double> _dialogScaleAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  final ProgressManager _progressManager = ProgressManager();

  bool _exerciseStarted = false;
  bool _wasEverCompleted = false;
  bool _isTransitioning = false;
  bool _disposed = false;

  // ─── Sound-lock state ───
  bool _isSoundPlaying = false;

  late List<Map<String, dynamic>> sessionQuizData;

  final List<Map<String, dynamic>> allQuizData = [
    {
      'word': 'CAT',
      'tiles': ['T', 'C', 'A'],
      'correctAnswer': 'CAT',
    },
    {
      'word': 'DOG',
      'tiles': ['G', 'D', 'O'],
      'correctAnswer': 'DOG',
    },
    {
      'word': 'SUN',
      'tiles': ['N', 'S', 'U'],
      'correctAnswer': 'SUN',
    },
    {
      'word': 'BED',
      'tiles': ['D', 'B', 'E'],
      'correctAnswer': 'BED',
    },
    {
      'word': 'MAP',
      'tiles': ['P', 'M', 'A'],
      'correctAnswer': 'MAP',
    },
    {
      'word': 'HAT',
      'tiles': ['T', 'H', 'A'],
      'correctAnswer': 'HAT',
    },
    {
      'word': 'BIG',
      'tiles': ['G', 'I', 'B'],
      'correctAnswer': 'BIG',
    },
    {
      'word': 'RUN',
      'tiles': ['N', 'R', 'U'],
      'correctAnswer': 'RUN',
    },
    {
      'word': 'BOX',
      'tiles': ['O', 'B', 'X'],
      'correctAnswer': 'BOX',
    },
    {
      'word': 'PEN',
      'tiles': ['N', 'E', 'P'],
      'correctAnswer': 'PEN',
    },
  ];

  static const Map<String, String> _letterSoundMap = {
    'A': 'aSound.m4a',
    'B': 'bSound.m4a',
    'C': 'cSound.m4a',
    'D': 'dSound.m4a',
    'E': 'eSound.m4a',
    'F': 'fSound.m4a',
    'G': 'gSound.m4a',
    'H': 'hSound.m4a',
    'I': 'iSound.m4a',
    'J': 'jSound.m4a',
    'K': 'kSound.m4a',
    'L': 'lSound.m4a',
    'M': 'mSound.m4a',
    'N': 'nSound.m4a',
    'O': 'oSound.m4a',
    'P': 'pSound.m4a',
    'Q': 'qSound.m4a',
    'R': 'rSound.m4a',
    'S': 'sSound.m4a',
    'T': 'tSound.m4a',
    'U': 'uSound.m4a',
    'V': 'vSound.m4a',
    'W': 'wSound.m4a',
    'X': 'xSound.m4a',
    'Y': 'ySound.m4a',
    'Z': 'zSound.m4a',
  };

  List<Map<String, dynamic>> _pickRandomQuestions() {
    final pool = List<Map<String, dynamic>>.from(allQuizData);
    pool.shuffle(Random());
    return pool.take(totalQuestions).toList();
  }

  Future<void> _restoreProgress() async {
    _progressManager.forceSetHighScore(
      'course_one',
      3,
      'Stage1_Exercise',
      _originalHighScore,
    );
    await _progressManager.updateExerciseCompletion(
      'course_one',
      3,
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
      3,
      'Stage1_Exercise',
    );
    _wasEverCompleted = _progressManager.isExerciseCompleted(
      'course_one',
      3,
      'Stage1_Exercise',
    );
    _originalHighScore = _highScore;
    _originalWasCompleted = _wasEverCompleted;

    sessionQuizData = _pickRandomQuestions();

    _dialogController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _dialogScaleAnimation = CurvedAnimation(
      parent: _dialogController,
      curve: Curves.elasticOut,
    );

    // Release sound lock when audio finishes
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted && !_disposed) {
        setState(() => _isSoundPlaying = false);
      }
    });

    _initializeTts().then((_) {
      if (_disposed) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed || !mounted) return;
        setState(() => _exerciseStarted = true);
        _speakIntro();
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

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(SettingsManager.speechOutputVolume);
      await _flutterTts.setPitch(1.0);

      // Release sound lock when TTS finishes
      _flutterTts.setCompletionHandler(() {
        if (!_disposed && mounted) {
          setState(() => _isSoundPlaying = false);
        }
      });
      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS error: $msg');
        if (!_disposed && mounted) setState(() => _isSoundPlaying = false);
      });
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  /// Speaks "Make the word: <WORD>" at the start of each question.
  Future<void> _speakIntro() async {
    if (_disposed || !mounted) return;
    if (currentQuestion > sessionQuizData.length) return;
    if (_isSoundPlaying) return;

    setState(() => _isSoundPlaying = true);
    try {
      await _flutterTts.stop();
      await _audioPlayer.stop();
      final word = sessionQuizData[currentQuestion - 1]['word'] as String;
      await _flutterTts.speak('Make the word. $word');
    } catch (e) {
      debugPrint('TTS speak error: $e');
      setState(() => _isSoundPlaying = false);
    }
  }

  /// Speaker button: speaks only the target word.
  Future<void> _speakWord() async {
    if (_disposed || !mounted) return;
    if (currentQuestion > sessionQuizData.length) return;
    if (_isSoundPlaying) return;

    setState(() => _isSoundPlaying = true);
    try {
      await _flutterTts.stop();
      final word = sessionQuizData[currentQuestion - 1]['word'] as String;
      await _flutterTts.speak(word);
    } catch (e) {
      debugPrint('TTS speak error: $e');
      setState(() => _isSoundPlaying = false);
    }
  }

  /// Play the sound for a letter tile.
  Future<void> _playLetterSound(String letter) async {
    final soundFile = _letterSoundMap[letter];
    if (soundFile == null) return;
    if (_isSoundPlaying) return;

    setState(() => _isSoundPlaying = true);
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(SettingsManager.speechOutputVolume);
      await _audioPlayer.play(AssetSource('sounds/$soundFile'));
      // onPlayerComplete releases the lock
    } catch (e) {
      debugPrint('Letter sound error: $e');
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

  // ─── Undo / clear are NOT part of sound lock ─────────────────────────────

  void addLetterToArrangement(String letter) {
    if (!_exerciseStarted || _isTransitioning || _answerRevealed) return;
    setState(() {
      for (int i = 0; i < arrangedLetters.length; i++) {
        if (arrangedLetters[i] == '') {
          arrangedLetters[i] = letter;
          break;
        }
      }
    });

    // ← Auto-validate once all 3 slots are filled.
    //   Wait 800 ms so the last letter's sound has time to play before
    //   the feedback sound and answer-reveal kick in.
    if (isArrangementComplete()) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (_disposed || !mounted) return;
        nextQuestion();
      });
    }
  }

  void undoLastLetter() {
    if (_answerRevealed) return;
    setState(() {
      for (int i = arrangedLetters.length - 1; i >= 0; i--) {
        if (arrangedLetters[i] != '') {
          arrangedLetters[i] = '';
          break;
        }
      }
    });
  }

  void clearAllLetters() {
    if (_answerRevealed) return;
    setState(() {
      arrangedLetters = ['', '', ''];
    });
  }

  bool isArrangementComplete() => !arrangedLetters.contains('');
  String getCurrentArrangement() => arrangedLetters.join('');

  List<bool> _computeUsedTiles() {
    final tiles = List<String>.from(
      sessionQuizData[currentQuestion - 1]['tiles'] as List,
    );
    final usedFlags = List<bool>.filled(tiles.length, false);
    final placed = List<String>.from(arrangedLetters);

    for (int p = 0; p < placed.length; p++) {
      if (placed[p] == '') continue;
      for (int t = 0; t < tiles.length; t++) {
        if (!usedFlags[t] && tiles[t] == placed[p]) {
          usedFlags[t] = true;
          break;
        }
      }
    }
    return usedFlags;
  }

  void nextQuestion() {
    if (!_exerciseStarted || _isTransitioning || _disposed) return;
    if (!isArrangementComplete()) return;

    setState(() => _isTransitioning = true);

    final questionData = sessionQuizData[currentQuestion - 1];
    final String correctAnswer = questionData['correctAnswer'] as String;
    final String userAnswer = getCurrentArrangement();
    final bool isCorrect = userAnswer == correctAnswer;

    _flutterTts.stop();

    // ── Reveal highlights before advancing ──
    setState(() {
      _answerRevealed = true;
      _lastAnswerCorrect = isCorrect;
    });

    if (isCorrect) {
      _playFeedbackSound(true);
      setState(() => currentScore++);
    } else {
      _playFeedbackSound(false);
    }

    _showAnswerSnackbar(isCorrect, correctAnswer);

    if (currentQuestion >= totalQuestions) {
      Timer(const Duration(seconds: 3), () {
        if (_disposed || !mounted) return;
        _dialogController.forward();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _buildCompletionDialog(),
        );
      });
    } else {
      Timer(const Duration(seconds: 3), () {
        if (_disposed || !mounted) return;
        setState(() {
          currentQuestion++;
          arrangedLetters = ['', '', ''];
          _answerRevealed = false;
          _lastAnswerCorrect = null;
          _isTransitioning = false;
        });
        _speakIntro();
      });
    }
  }

  void resetQuiz() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    sessionQuizData = _pickRandomQuestions();
    setState(() {
      currentScore = 0;
      currentQuestion = 1;
      arrangedLetters = ['', '', ''];
      _answerRevealed = false;
      _lastAnswerCorrect = null;
      _exerciseStarted = true;
      _isTransitioning = false;
      _isSoundPlaying = false;
    });
    _dialogController.reset();
    _speakIntro();
  }

  // ─── Slot color based on reveal state ────────────────────────────────────

  Color _slotBorderColor(int i) {
    if (!_answerRevealed) {
      return arrangedLetters[i] != '' ? Colors.orange : Colors.grey.shade400;
    }
    if (_lastAnswerCorrect == true) return const Color(0xFF4CAF50);
    return const Color(0xFFE53935);
  }

  Color _slotBgColor(int i) {
    if (!_answerRevealed) {
      return arrangedLetters[i] != ''
          ? Colors.orange.shade50
          : Colors.grey.shade200;
    }
    if (_lastAnswerCorrect == true) return const Color(0xFFE8F5E9);
    return const Color(0xFFFFEBEE);
  }

  Color _slotTextColor(int i) {
    if (!_answerRevealed) {
      return arrangedLetters[i] != ''
          ? Colors.orange.shade700
          : Colors.grey.shade400;
    }
    if (_lastAnswerCorrect == true) return const Color(0xFF2E7D32);
    return const Color(0xFFC62828);
  }

  void _showAnswerSnackbar(bool isCorrect, String correctAnswer) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor:
            isCorrect
                ? const Color.fromRGBO(76, 175, 80, 0.85)
                : const Color.fromRGBO(220, 50, 50, 0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(left: 36, right: 36, bottom: 120),
        content: Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isCorrect ? 'Correct! 🎉' : 'Wrong Answer 😞',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  if (!isCorrect)
                    Text.rich(
                      TextSpan(
                        text: 'Correct answer: ',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        children: [
                          TextSpan(
                            text: correctAnswer,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                              decorationThickness: 1.5,
                            ),
                          ),
                        ],
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

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _flutterTts.stop();
    _dialogController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── COMPLETION DIALOG ─────────────────────────────────────────────────────

  Widget _buildCompletionDialog() {
    String starImage;
    String message;
    if (currentScore >= 4) {
      starImage = 'assets/images/threeStar.png';
      message = "Excellent work! You're a word master!";
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
                            child: _AnimatedImageButton(
                              height: 50,
                              borderRadius: 14,
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset(
                                  'assets/images/closeButton.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _AnimatedImageButton(
                            width: 50,
                            height: 50,
                            borderRadius: 14,
                            onTap: () async {
                              await _saveProgress();
                              if (mounted) {
                                Navigator.of(context).pop();
                                resetQuiz();
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                'assets/images/restartButton.png',
                                fit: BoxFit.cover,
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

  Future<void> _saveProgress() async {
    final bool wasCompleted = _progressManager.isLessonFullyCompleted(
      'course_one',
      3,
    );

    if (currentScore > _highScore) {
      _highScore = currentScore;
      await _progressManager.updateExerciseHighScore(
        'course_one',
        3,
        'Stage1_Exercise',
        currentScore,
      );
    }
    final shouldMark = (currentScore >= 3) || _wasEverCompleted;
    if (shouldMark) {
      await _progressManager.updateExerciseCompletion(
        'course_one',
        3,
        'Stage1_Exercise',
        true,
      );
      _wasEverCompleted = true;
    }
    _originalHighScore = _highScore; // ← advance snapshot
    _originalWasCompleted = _wasEverCompleted;

    if (!wasCompleted &&
        _progressManager.isLessonFullyCompleted('course_one', 3)) {
      NotificationHelper.onLessonComplete(
        'course_one',
        3,
        'Blending Simple CVC Words',
      );
    } // ← advance snapshot
  }

  // ── EXIT DIALOG ───────────────────────────────────────────────────────────

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
                            child: _AnimatedImageButton(
                              height: 50,
                              borderRadius: 12,
                              onTap: () => Navigator.of(ctx).pop(false),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/images/cancelButton.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _AnimatedImageButton(
                              height: 50,
                              borderRadius: 12,
                              onTap: () => Navigator.of(ctx).pop(true),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
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

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double progress = currentQuestion / totalQuestions;
    final bool hasQuestion = currentQuestion <= sessionQuizData.length;
    final questionData =
        hasQuestion ? sessionQuizData[currentQuestion - 1] : null;
    final List<String> tiles =
        questionData != null
            ? List<String>.from(questionData['tiles'] as List)
            : [];
    final List<bool> usedFlags =
        hasQuestion ? _computeUsedTiles() : [false, false, false];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!_exerciseStarted) return;
        _flutterTts.stop();
        _audioPlayer.stop();
        final shouldExit = await _showExitWarningDialog();
        if (shouldExit && context.mounted) {
          await _restoreProgress();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const CourseOne()),
          );
        } else {
          _speakIntro();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFB6E8C1),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // ── HEADER ───────────────────────────────────────────────
                  // Replace the header Padding with:
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Back button ──
                        _AnimatedImageButton(
                          height: 54,
                          width: 54,
                          borderRadius: 12,
                          onTap: () async {
                            if (!_exerciseStarted) return;
                            _flutterTts.stop();
                            _audioPlayer.stop();
                            final shouldExit = await _showExitWarningDialog();
                            if (shouldExit && context.mounted) {
                              await _restoreProgress();
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const CourseOne(),
                                ),
                              );
                            } else {
                              if (mounted) {
                                setState(() => _isSoundPlaying = false);
                                _speakIntro();
                              }
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/backButton.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Score | Progress bar | Question counter ──
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

                  // ── WHITE CARD: instruction + answer slots + speaker ──────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 20,
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
                            '"Make the word."',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          // ── Answer slots with reveal colors ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (i) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: _slotBgColor(i),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _slotBorderColor(i),
                                    width: 2,
                                  ),
                                  boxShadow:
                                      arrangedLetters[i] != ''
                                          ? [
                                            BoxShadow(
                                              color: _slotBorderColor(
                                                i,
                                              ).withOpacity(0.20),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                          : null,
                                ),
                                child: Center(
                                  child: Text(
                                    arrangedLetters[i],
                                    style: TextStyle(
                                      fontFamily: 'Fredoka',
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                      color: _slotTextColor(i),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 10),
                          // ── Speaker button with bounce animation ──
                          _AnimatedSpeakerButton(
                            isSoundPlaying: _isSoundPlaying,
                            onTap: _speakWord,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── LETTER TILES ─────────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                      child:
                          hasQuestion
                              ? Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: List.generate(tiles.length, (i) {
                                  final letter = tiles[i];
                                  final isUsed = usedFlags[i];
                                  // Dim while sound is playing (non-used tiles)
                                  final bool dimmed =
                                      _isSoundPlaying && !isUsed;
                                  // Block tap: used, revealed, OR sound playing
                                  final bool locked =
                                      isUsed ||
                                      _answerRevealed ||
                                      _isSoundPlaying;

                                  return _AnimatedLetterTile(
                                    letter: letter,
                                    isUsed: isUsed,
                                    dimmed: dimmed,
                                    locked: locked,
                                    onTap: () {
                                      _playLetterSound(letter);
                                      addLetterToArrangement(letter);
                                    },
                                  );
                                }),
                              )
                              : const SizedBox.shrink(),
                    ),
                  ),

                  // ── UNDO / DELETE — not part of sound lock ────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 50),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _AnimatedIconButton(
                          color: const Color(0xFF577E5F),
                          icon: Icons.undo_rounded,
                          onTap: undoLastLetter,
                        ),
                        _AnimatedIconButton(
                          color: const Color(0xFFD94040),
                          icon: Icons.delete_rounded,
                          onTap: clearAllLetters,
                        ),
                      ],
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

// ── Animated letter tile ──────────────────────────────────────────────────────

class _AnimatedLetterTile extends StatefulWidget {
  final String letter;
  final bool isUsed;
  final bool dimmed;
  final bool locked;
  final VoidCallback onTap;

  const _AnimatedLetterTile({
    required this.letter,
    required this.isUsed,
    required this.dimmed,
    required this.locked,
    required this.onTap,
  });

  @override
  State<_AnimatedLetterTile> createState() => _AnimatedLetterTileState();
}

class _AnimatedLetterTileState extends State<_AnimatedLetterTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
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
    ]).animate(_scaleController);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.locked) return;
    _scaleController.forward(from: 0).then((_) => widget.onTap());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.isUsed ? 0.35 : (widget.dimmed ? 0.45 : 1.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 90,
            height: 110,
            decoration: BoxDecoration(
              color: widget.isUsed ? Colors.grey.shade200 : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    widget.isUsed ? Colors.grey.shade300 : Colors.grey.shade200,
                width: 2,
              ),
              boxShadow:
                  widget.isUsed
                      ? null
                      : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
            ),
            child: Center(
              child: Text(
                widget.letter,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 44,
                  fontWeight: FontWeight.w600,
                  color: widget.isUsed ? Colors.grey.shade400 : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animated speaker button ───────────────────────────────────────────────────

class _AnimatedSpeakerButton extends StatefulWidget {
  final bool isSoundPlaying;
  final VoidCallback onTap;

  const _AnimatedSpeakerButton({
    required this.isSoundPlaying,
    required this.onTap,
  });

  @override
  State<_AnimatedSpeakerButton> createState() => _AnimatedSpeakerButtonState();
}

class _AnimatedSpeakerButtonState extends State<_AnimatedSpeakerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.82,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.82,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_scaleController);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isSoundPlaying) return;
    _scaleController.forward(from: 0).then((_) => widget.onTap());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: 60,
          height: 60,
          child: Image.asset(
            'assets/images/soundButton.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

// ── Animated icon button (undo / delete) ─────────────────────────────────────

class _AnimatedIconButton extends StatefulWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _AnimatedIconButton({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.82,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.82,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_scaleController);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _scaleController.forward(from: 0).then((_) => widget.onTap());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 64,
          height: 54,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(widget.icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ── Animated image button (close / restart / cancel / exit / next) ────────────

class _AnimatedImageButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final double height;
  final double borderRadius;
  final double? width;
  final bool enabled;

  const _AnimatedImageButton({
    required this.onTap,
    required this.child,
    required this.height,
    required this.borderRadius,
    this.width,
    this.enabled = true,
  });

  @override
  State<_AnimatedImageButton> createState() => _AnimatedImageButtonState();
}

class _AnimatedImageButtonState extends State<_AnimatedImageButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.88,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.88,
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
    ]).animate(_scaleController);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.enabled) return;
    _scaleController.forward(from: 0).then((_) => widget.onTap());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.child,
        ),
      ),
    );
  }
}
