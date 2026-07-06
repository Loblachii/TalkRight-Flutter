import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

class Stage1BeginEndSound extends StatefulWidget {
  const Stage1BeginEndSound({super.key});

  @override
  State<Stage1BeginEndSound> createState() => _Stage1BeginEndSoundState();
}

class _Stage1BeginEndSoundState extends State<Stage1BeginEndSound>
    with TickerProviderStateMixin {
  int currentQuestion = 0;
  int correctAnswers = 0;
  int totalQuestions = 7;
  String? selectedAnswer;
  bool showFeedback = false;
  bool isCorrect = false;
  bool isPlaying = false;
  bool _buttonsEnabled = false;
  int _playCount = 0;
  final int _maxPlays = 3;
  bool _isAutoPlay = false;
  Timer? _timer;
  int _remainingSeconds = 35;
  int _highScore = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _instructionPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  late stt.SpeechToText _speech;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  final Random _random = Random();
  List<Map<String, dynamic>> _questions = [];
  bool _awaitingPronunciation = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isTransitioning = false;
  String _recognizedText = '';

  final List<Map<String, dynamic>> _allQuestions = [
    {
      'word': 'cat',
      'sound': '/k/',
      'position': 'beginning',
      'soundFile': 'cSound.m4a',
    },
    {
      'word': 'dog',
      'sound': '/g/',
      'position': 'ending',
      'soundFile': 'gSound.m4a',
    },
    {
      'word': 'sun',
      'sound': '/s/',
      'position': 'beginning',
      'soundFile': 'sSound.m4a',
    },
    {
      'word': 'bed',
      'sound': '/d/',
      'position': 'ending',
      'soundFile': 'dSound.m4a',
    },
    {
      'word': 'map',
      'sound': '/m/',
      'position': 'beginning',
      'soundFile': 'mSound.m4a',
    },
    {
      'word': 'cup',
      'sound': '/p/',
      'position': 'ending',
      'soundFile': 'pSound.m4a',
    },
    {
      'word': 'fish',
      'sound': '/f/',
      'position': 'beginning',
      'soundFile': 'fSound.m4a',
    },
    {
      'word': 'pen',
      'sound': '/n/',
      'position': 'ending',
      'soundFile': 'nSound.m4a',
    },
    {
      'word': 'top',
      'sound': '/t/',
      'position': 'beginning',
      'soundFile': 'tSound.m4a',
    },
    {
      'word': 'bag',
      'sound': '/g/',
      'position': 'ending',
      'soundFile': 'gSound.m4a',
    },
    {
      'word': 'lamp',
      'sound': '/l/',
      'position': 'beginning',
      'soundFile': 'lSound.m4a',
    },
    {
      'word': 'hat',
      'sound': '/t/',
      'position': 'ending',
      'soundFile': 'tSound.m4a',
    },
    {
      'word': 'rain',
      'sound': '/r/',
      'position': 'beginning',
      'soundFile': 'rSound.m4a',
    },
    {
      'word': 'bus',
      'sound': '/s/',
      'position': 'ending',
      'soundFile': 'sSound.m4a',
    },
    {
      'word': 'nest',
      'sound': '/n/',
      'position': 'beginning',
      'soundFile': 'nSound.m4a',
    },
    {
      'word': 'leaf',
      'sound': '/f/',
      'position': 'ending',
      'soundFile': 'fSound.m4a',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
    _initializeSpeech();
    _setupAnimations();
    _generateQuestions();
    _loadHighScore();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isAutoPlay = true;
      await _playCurrentSound(withInstruction: true);
      if (mounted) _startTimer();
    });
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('stage1_begin_end_sound_high_score') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    if (correctAnswers > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('stage1_begin_end_sound_high_score', correctAnswers);
      _highScore = correctAnswers;
    }
  }

  void _startTimer() {
    _timer
        ?.cancel(); // FIX 3: Always cancel any existing timer before starting a new one
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
          _remainingSeconds = 35;
          _playCount = 0;
          _buttonsEnabled = false;
        });
        _startTimer(); // _startTimer() now cancels the old timer internally (Fix 3)
        _isAutoPlay = true;
        _playCurrentSound(withInstruction: true);
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
    await _flutterTts.setSpeechRate(0.35);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _initializeSpeech() async {
    _speech = stt.SpeechToText();
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (!mounted) return;
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
        });
      },
    );
  }

  void _generateQuestions() {
    _questions = List.from(_allQuestions)..shuffle(_random);
    _questions = _questions.take(totalQuestions).toList();
  }

  Future<void> _playCurrentSound({bool withInstruction = false}) async {
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
    await _audioPlayer.stop();
    _bounceController.repeat(reverse: true);

    String word = _questions[currentQuestion]['word'];
    String soundFile = _questions[currentQuestion]['soundFile'];

    // Play TTS instruction only on first play of each question
    if (withInstruction) {
      Completer<void> ttsCompleter = Completer<void>();
      _flutterTts.setCompletionHandler(() {
        if (!ttsCompleter.isCompleted) ttsCompleter.complete();
      });
      await _flutterTts.speak('Where is this sound in the word $word');
      await ttsCompleter.future;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Play the consonant sound via m4a file
    Completer<void> audioCompleter = Completer<void>();
    StreamSubscription? sub;
    sub = _instructionPlayer.onPlayerComplete.listen((_) {
      sub?.cancel();
      if (!audioCompleter.isCompleted) audioCompleter.complete();
    });
    await _instructionPlayer.play(AssetSource('sounds/$soundFile'));
    await audioCompleter.future;

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

  void _selectAnswer(String answer) {
    if (showFeedback || !_buttonsEnabled || _awaitingPronunciation) return;
    setState(() {
      selectedAnswer = answer;
    });
  }

  Future<void> _checkAnswer() async {
    if (selectedAnswer == null || showFeedback || _isTransitioning) return;
    _isTransitioning = true;

    String correct = _questions[currentQuestion]['position'];
    String targetWord = _questions[currentQuestion]['word'];
    final builtCorrectly = selectedAnswer == correct;

    setState(() {
      showFeedback = true;
      isCorrect = builtCorrectly;
      _buttonsEnabled = false;
      // Award score immediately
      if (builtCorrectly) {
        correctAnswers++;
      }
    });

    await _instructionPlayer.stop();
    await _flutterTts.stop();

    await _audioPlayer.play(
      AssetSource(
        isCorrect ? 'sounds/correctAnswer.wav' : 'sounds/incorrectAnswer.wav',
      ),
    );

    if (!builtCorrectly) {
      await Future.delayed(const Duration(milliseconds: 1200));
      _isTransitioning = false;
      _goToNextQuestion();
      return;
    }

    _timer?.cancel();
    if (mounted) {
      setState(() {
        _awaitingPronunciation = true;
        _recognizedText = '';
        _isListening = false;
      });
    }
    await Future.delayed(const Duration(milliseconds: 250));
    await _flutterTts.speak('Now say the word $targetWord');
    _isTransitioning = false;
  }

  Future<void> _toggleListening() async {
    if (!_awaitingPronunciation || !_speechAvailable || _isListening) return;

    setState(() {
      _recognizedText = '';
      _isListening = true;
    });

    await _instructionPlayer.stop();
    await _audioPlayer.stop();
    await _flutterTts.stop();

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _recognizedText = result.recognizedWords.toLowerCase();
        });
      },
      listenFor: const Duration(seconds: 4),
      pauseFor: const Duration(seconds: 2),
      localeId: 'en_US',
      cancelOnError: true,
      partialResults: true,
    );

    await Future.delayed(const Duration(seconds: 4));

    if (mounted) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _goToNextQuestion();
      }
    }
  }

  void _goToNextQuestion() {
    if (currentQuestion < totalQuestions - 1) {
      _timer?.cancel();
      _speech.stop();
      _instructionPlayer.stop();
      _audioPlayer.stop();
      _flutterTts.stop();
      setState(() {
        currentQuestion++;
        selectedAnswer = null;
        showFeedback = false;
        _remainingSeconds = 35;
        _playCount = 0;
        _buttonsEnabled = false;
        _awaitingPronunciation = false;
        _isListening = false;
        _recognizedText = '';
      });
      _isTransitioning = false;
      _startTimer();
      _isAutoPlay = true;
      _playCurrentSound(withInstruction: true);
    } else {
      _showCompletionDialog();
    }
  }

  Future<void> _showCompletionDialog() async {
    _timer?.cancel();
    await _saveHighScore();
    final prefs = await SharedPreferences.getInstance();
    bool passed = correctAnswers >= 4;
    int failedAttempts = prefs.getInt('stage1_begin_end_sound_failed') ?? 0;
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
                          ? [const Color(0xFF4CAF50), const Color(0xFF4CAF50)]
                          : [const Color(0xFFEF9A9A), const Color(0xFFE57373)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    passed ? Icons.celebration : Icons.sentiment_dissatisfied,
                    size: 70,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    passed ? 'Fantastic!' : 'Keep Practicing!',
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
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            currentQuestion = 0;
                            correctAnswers = 0;
                            selectedAnswer = null;
                            showFeedback = false;
                            _remainingSeconds = 35;
                            _playCount = 0;
                            _buttonsEnabled = false;
                          });
                          _generateQuestions();
                          // FIX 2: _startTimer() now internally cancels before starting,
                          // and withInstruction: true ensures TTS intro plays on replay
                          _isAutoPlay = true;
                          _playCurrentSound(withInstruction: true);
                          _startTimer();
                        },
                        icon: const Icon(Icons.replay),
                        label: const Text('Play Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor:
                              passed
                                  ? const Color(0xFF4CAF50)
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
                                  ? const Color(0xFF4CAF50)
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

  String _getFeedbackMessage() {
    double percentage = correctAnswers / totalQuestions;
    if (percentage >= 0.9) return 'Amazing sound detective!';
    if (percentage >= 0.7) return 'Great listening skills!';
    if (percentage >= 0.5) return 'Good effort! Try again to improve!';
    return 'Keep trying! Practice makes perfect!';
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
                                backgroundColor: const Color(0xFF4A7C59),
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
                                foregroundColor: const Color(0xFF4A7C59),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: Color(0xFF4A7C59),
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

  // FIX 1: Only cancel timer if the user confirms exit.
  // If they tap Cancel, restart the timer so the countdown resumes.
  Future<void> _onBackButtonTap() async {
    _timer?.cancel();
    _flutterTts.stop();
    _instructionPlayer.stop();
    _audioPlayer.stop();

    final shouldExit = await _showExitWarningDialog();
    if (shouldExit && context.mounted) {
      Navigator.of(context).pop();
      return;
    }

    if (!mounted) return;
    // User cancelled exit — restart the timer so the countdown resumes
    _startTimer();
    setState(() {
      isPlaying = false;
      _buttonsEnabled = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_isListening) {
      _speech.stop();
    }
    _bounceController.dispose();
    _audioPlayer.dispose();
    _instructionPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    String targetSound = _questions[currentQuestion]['sound'];
    String word = _questions[currentQuestion]['word'];
    String correctPosition = _questions[currentQuestion]['position'];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onBackButtonTap();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE8F5E9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF4CAF50),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _onBackButtonTap,
          ),
          title: const Text(
            'Beginning vs Ending',
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
                        _buildSoundButton(),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Word: "$word"',
                                style: const TextStyle(
                                  fontFamily: 'Fredoka',
                                  letterSpacing: 0.2,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Where is the sound $targetSound?',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  letterSpacing: 0.2,
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_awaitingPronunciation)
                          _buildPronunciationSection(word)
                        else
                          _buildAnswerButtons(correctPosition),
                        const Spacer(),
                        const SizedBox(height: 16),
                        if (!_awaitingPronunciation) _buildCheckButton(),
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
              'Question ${currentQuestion + 1}',
              style: const TextStyle(
                fontFamily: 'Fredoka',
                letterSpacing: 0.2,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4CAF50),
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
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
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
            color: Colors.green.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.compare_arrows, color: Color(0xFFFFB300), size: 24),
          const SizedBox(width: 8),
          Text(
            'Score: $correctAnswers',
            style: const TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay() {
    Color timerColor =
        _remainingSeconds <= 10 ? Colors.red : const Color(0xFF4CAF50);
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
      children: [
        ScaleTransition(
          scale: _bounceAnimation,
          child: GestureDetector(
            onTap: canPlay ? _playCurrentSound : null,
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
                          ? [const Color(0xFF4CAF50), const Color(0xFF4CAF50)]
                          : [Colors.grey[400]!, Colors.grey[500]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.4),
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
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerButtons(String correctPosition) {
    return Row(
      children: [
        Expanded(
          child: _buildPositionButton(
            'beginning',
            'Beginning',
            Icons.first_page,
            correctPosition,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPositionButton(
            'ending',
            'Ending',
            Icons.last_page,
            correctPosition,
          ),
        ),
      ],
    );
  }

  Widget _buildPositionButton(
    String value,
    String label,
    IconData icon,
    String correct,
  ) {
    bool isSelected = selectedAnswer == value;
    bool showWrong = showFeedback && isSelected && !isCorrect;

    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFFE0E0E0);
    Color iconColor = const Color(0xFF4CAF50);

    if (isSelected && !showFeedback) {
      bgColor = const Color(0xFF4CAF50).withOpacity(0.2);
      borderColor = const Color(0xFF4CAF50);
    } else if (showWrong) {
      bgColor = const Color(0xFFE57373).withOpacity(0.2);
      borderColor = const Color(0xFFE57373);
      iconColor = const Color(0xFFC62828);
    }

    return GestureDetector(
      onTap: _buttonsEnabled ? () => _selectAnswer(value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: MediaQuery.of(context).size.height * 0.13,
        decoration: BoxDecoration(
          color: _buttonsEnabled ? bgColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _buttonsEnabled ? borderColor : Colors.grey[300]!,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: _buttonsEnabled ? iconColor : Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Fredoka',
                letterSpacing: 0.2,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _buttonsEnabled ? iconColor : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckButton() {
    bool canCheck = selectedAnswer != null && !showFeedback && _buttonsEnabled;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canCheck ? _checkAnswer : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Text(
          showFeedback
              ? (isCorrect ? 'Correct!' : 'Not quite!')
              : 'Check Answer',
          style: TextStyle(
            fontFamily: 'Fredoka',
            letterSpacing: 0.2,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: (canCheck || showFeedback) ? Colors.white : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _buildPronunciationSection(String word) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50), width: 2),
      ),
      child: Column(
        children: [
          Text(
            'Practice saying this word aloud:',
            style: TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            word.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _toggleListening,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    _isListening
                        ? const Color(0xFFE57373)
                        : const Color(0xFF4CAF50),
                boxShadow: [
                  BoxShadow(
                    color: (_isListening
                            ? const Color(0xFFE57373)
                            : const Color(0xFF4CAF50))
                        .withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isListening ? 'Listening...' : 'Tap mic and pronounce the word',
            style: TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          if (_recognizedText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Heard: $_recognizedText',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Fredoka',
                letterSpacing: 0.2,
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
