import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

class Stage1SoundMatch extends StatefulWidget {
  const Stage1SoundMatch({super.key});

  @override
  State<Stage1SoundMatch> createState() => _Stage1SoundMatchState();
}

class _Stage1SoundMatchState extends State<Stage1SoundMatch>
    with TickerProviderStateMixin {
  int currentQuestion = 0;
  int correctAnswers = 0;
  int totalQuestions = 7;
  int? selectedAnswer;
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
  final AudioPlayer _optionAudioPlayer = AudioPlayer();
  final AudioPlayer _instructionPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _feedbackController;
  late Animation<double> _feedbackAnimation;

  final Random _random = Random();
  List<Map<String, dynamic>> _questions = [];

  final List<Map<String, dynamic>> _allQuestions = [
    {
      'sound': '/b/',
      'correct': 'B',
      'options': ['B', 'P', 'D'],
    },
    {
      'sound': '/m/',
      'correct': 'M',
      'options': ['N', 'M', 'W'],
    },
    {
      'sound': '/s/',
      'correct': 'S',
      'options': ['S', 'Z', 'C'],
    },
    {
      'sound': '/t/',
      'correct': 'T',
      'options': ['D', 'T', 'K'],
    },
    {
      'sound': '/p/',
      'correct': 'P',
      'options': ['P', 'B', 'T'],
    },
    {
      'sound': '/k/',
      'correct': 'K',
      'options': ['G', 'C', 'K'],
    },
    {
      'sound': '/d/',
      'correct': 'D',
      'options': ['D', 'T', 'B'],
    },
    {
      'sound': '/n/',
      'correct': 'N',
      'options': ['M', 'N', 'L'],
    },
    {
      'sound': '/f/',
      'correct': 'F',
      'options': ['F', 'V', 'P'],
    },
    {
      'sound': '/l/',
      'correct': 'L',
      'options': ['R', 'L', 'W'],
    },
    {
      'sound': '/g/',
      'correct': 'G',
      'options': ['K', 'G', 'J'],
    },
    {
      'sound': '/h/',
      'correct': 'H',
      'options': ['H', 'K', 'W'],
    },
    {
      'sound': '/r/',
      'correct': 'R',
      'options': ['L', 'R', 'W'],
    },
    {
      'sound': '/w/',
      'correct': 'W',
      'options': ['W', 'V', 'R'],
    },
    {
      'sound': '/j/',
      'correct': 'J',
      'options': ['J', 'G', 'Y'],
    },
    {
      'sound': '/v/',
      'correct': 'V',
      'options': ['F', 'V', 'W'],
    },
    {
      'sound': '/z/',
      'correct': 'Z',
      'options': ['S', 'Z', 'X'],
    },
    {
      'sound': '/a/',
      'correct': 'A',
      'options': ['A', 'E', 'O'],
    },
    {
      'sound': '/e/',
      'correct': 'E',
      'options': ['I', 'E', 'A'],
    },
    {
      'sound': '/i/',
      'correct': 'I',
      'options': ['I', 'E', 'U'],
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
      await _playCurrentSound(withInstruction: true);
      if (mounted) _startTimer();
    });
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('stage1_sound_match_high_score') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    if (correctAnswers > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('stage1_sound_match_high_score', correctAnswers);
      _highScore = correctAnswers;
    }
  }

  // FIX 3: Cancel any existing timer before starting a new one.
  // Safe to call from anywhere without a prior manual cancel.
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
          _remainingSeconds = 35;
          _playCount = 0;
          _buttonsEnabled = false;
        });
        _startTimer();
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

    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _feedbackAnimation = CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.elasticOut,
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
      (q['options'] as List).shuffle(_random);
    }
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
    _bounceController.repeat(reverse: true);

    // Play instruction via TTS only on first play of each question
    if (withInstruction) {
      Completer<void> ttsCompleter = Completer<void>();
      _flutterTts.setCompletionHandler(() {
        if (!ttsCompleter.isCompleted) ttsCompleter.complete();
      });
      await _flutterTts.speak('Tap the letter that matches the sound');
      await ttsCompleter.future;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Play the phonetic m4a audio file
    String correct =
        _questions[currentQuestion]['correct'].toString().toLowerCase();
    Completer<void> audioCompleter = Completer<void>();
    StreamSubscription? sub;
    sub = _instructionPlayer.onPlayerComplete.listen((_) {
      if (!audioCompleter.isCompleted) audioCompleter.complete();
      sub?.cancel();
    });
    await _instructionPlayer.play(AssetSource('sounds/${correct}Sound.m4a'));
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

  void _selectAnswer(int index) {
    if (showFeedback || !_buttonsEnabled) return;

    final letter =
        _questions[currentQuestion]['options'][index].toString().toLowerCase();
    _optionAudioPlayer.stop().then((_) {
      _optionAudioPlayer.play(AssetSource('sounds/${letter}Sound.m4a'));
    });

    setState(() {
      selectedAnswer = index;
    });
  }

  void _checkAnswer() {
    if (selectedAnswer == null) return;

    String selected = _questions[currentQuestion]['options'][selectedAnswer!];
    String correct = _questions[currentQuestion]['correct'];

    setState(() {
      showFeedback = true;
      isCorrect = selected == correct;
      if (isCorrect) correctAnswers++;
    });

    _audioPlayer.play(
      AssetSource(
        isCorrect ? 'sounds/correctAnswer.wav' : 'sounds/incorrectAnswer.wav',
      ),
    );

    _feedbackController.forward();

    Timer(const Duration(milliseconds: 1500), () {
      _feedbackController.reset();
      if (currentQuestion < totalQuestions - 1) {
        _timer?.cancel();
        setState(() {
          currentQuestion++;
          selectedAnswer = null;
          showFeedback = false;
          _remainingSeconds = 35;
          _playCount = 0;
          _buttonsEnabled = false;
        });
        _startTimer();
        _isAutoPlay = true;
        _playCurrentSound(withInstruction: true);
      } else {
        _showCompletionDialog();
      }
    });
  }

  Future<void> _showCompletionDialog() async {
    _timer?.cancel();
    await _saveHighScore();
    final prefs = await SharedPreferences.getInstance();
    bool passed = correctAnswers >= 4;
    int failedAttempts = prefs.getInt('stage1_sound_match_failed') ?? 0;
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
                          ? [const Color(0xFF66BB6A), const Color(0xFF4CAF50)]
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
                    passed ? 'Great Job!' : 'Keep Practicing!',
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
                        // FIX 2: Play Again — removed standalone _startTimer() before
                        // _playCurrentSound(); _startTimer() now follows after, matching
                        // initState order. Also added withInstruction: true so TTS intro
                        // plays on replays. Double-timer risk eliminated because
                        // _startTimer() self-cancels (Fix 3).
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
                          _isAutoPlay = true;
                          _playCurrentSound(withInstruction: true).then((_) {
                            if (mounted) _startTimer();
                          });
                        },
                        icon: const Icon(Icons.replay),
                        label: const Text('Play Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor:
                              passed
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFE57373),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
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
    if (percentage >= 0.9) return 'Amazing! You\'re a sound master!';
    if (percentage >= 0.7) return 'Well done! Keep practicing!';
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

  // FIX 1: Timer is cancelled before showing the dialog. If the user taps
  // Cancel (shouldExit == false), _startTimer() is called in the else branch
  // to resume the countdown. Previously, cancelling without restarting left
  // the timer permanently frozen.
  Future<void> _onBackButtonTap() async {
    _timer?.cancel();
    _flutterTts.stop();
    _audioPlayer.stop();
    _optionAudioPlayer.stop();
    _instructionPlayer.stop();

    final shouldExit = await _showExitWarningDialog();
    if (shouldExit && context.mounted) {
      Navigator.of(context).pop();
      return;
    } else {
      if (!mounted) return;
      setState(() {
        isPlaying = false;
        _buttonsEnabled = true;
      });
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bounceController.dispose();
    _feedbackController.dispose();
    _audioPlayer.dispose();
    _optionAudioPlayer.dispose();
    _instructionPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onBackButtonTap();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE8F5E9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF66BB6A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _onBackButtonTap,
          ),
          title: const Text(
            'Sound Match',
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
                        const SizedBox(height: 20),
                        _buildSoundButton(),
                        const SizedBox(height: 12),
                        Text(
                          'Tap the letter that matches the sound',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            letterSpacing: 0.2,
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildAnswerOptions(),
                        const Spacer(),
                        const SizedBox(height: 16),
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
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF66BB6A)),
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
          const Icon(Icons.stars, color: Color(0xFFFFB300), size: 24),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _bounceAnimation,
          child: GestureDetector(
            onTap: canPlay ? _playCurrentSound : null,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.28,
              height: MediaQuery.of(context).size.width * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      canPlay
                          ? (isPlaying
                              ? [
                                const Color(0xFF81C784),
                                const Color(0xFF66BB6A),
                              ]
                              : [
                                const Color(0xFF66BB6A),
                                const Color(0xFF4CAF50),
                              ])
                          : [Colors.grey[400]!, Colors.grey[500]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF4CAF50,
                    ).withOpacity(canPlay ? 0.4 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPlaying
                        ? Icons.volume_up
                        : (_playCount >= _maxPlays
                            ? Icons.volume_off
                            : Icons.play_arrow),
                    size: 50,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPlaying
                        ? 'Playing...'
                        : (_playCount >= _maxPlays ? 'No Plays' : 'Play Sound'),
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      letterSpacing: 0.2,
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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

  Widget _buildAnswerOptions() {
    List<String> options = List<String>.from(
      _questions[currentQuestion]['options'],
    );
    String correctAnswer = _questions[currentQuestion]['correct'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(options.length, (index) {
        bool isSelected = selectedAnswer == index;
        bool showWrong = showFeedback && isSelected && !isCorrect;

        Color bgColor = Colors.white;
        Color borderColor = const Color(0xFFE0E0E0);
        Color textColor = const Color(0xFF333333);

        if (isSelected && !showFeedback) {
          bgColor = const Color(0xFF66BB6A).withOpacity(0.1);
          borderColor = const Color(0xFF66BB6A);
          textColor = const Color(0xFF4CAF50);
        } else if (showWrong) {
          bgColor = const Color(0xFFE57373).withOpacity(0.2);
          borderColor = const Color(0xFFE57373);
          textColor = const Color(0xFFC62828);
        }

        return ScaleTransition(
          scale: const AlwaysStoppedAnimation(1.0),
          child: GestureDetector(
            onTap: _buttonsEnabled ? () => _selectAnswer(index) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: MediaQuery.of(context).size.width * 0.2,
              height: MediaQuery.of(context).size.width * 0.2,
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
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  options[index],
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    letterSpacing: 0.2,
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: _buttonsEnabled ? textColor : Colors.grey[400],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCheckButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed:
            selectedAnswer != null && !showFeedback && _buttonsEnabled
                ? _checkAnswer
                : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF66BB6A),
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Text(
          showFeedback
              ? (isCorrect ? 'Correct!' : 'Try again next time!')
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
