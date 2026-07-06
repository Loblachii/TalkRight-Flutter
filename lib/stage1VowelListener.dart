import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

class Stage1VowelListener extends StatefulWidget {
  const Stage1VowelListener({super.key});

  @override
  State<Stage1VowelListener> createState() => _Stage1VowelListenerState();
}

class _Stage1VowelListenerState extends State<Stage1VowelListener>
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
  String _pronunciationTarget = '';

  // Short vs Long vowel sounds with word examples
  final List<Map<String, dynamic>> _allQuestions = [
    {
      'vowelType': 'short a',
      'targetWord': 'cat',
      'options': ['cat', 'cake', 'car'],
      'correct': 0,
      'soundFile': 'aSound.m4a',
      'phoneme': 'ah',
    },
    {
      'vowelType': 'long a',
      'targetWord': 'cake',
      'options': ['cap', 'cake', 'call'],
      'correct': 1,
      'soundFile': 'auVowelTeam.m4a',
      'phoneme': 'ay',
    },
    {
      'vowelType': 'short e',
      'targetWord': 'bed',
      'options': ['bed', 'bead', 'bird'],
      'correct': 0,
      'soundFile': 'eSound.m4a',
    },
    {
      'vowelType': 'long e',
      'targetWord': 'feet',
      'options': ['pet', 'feet', 'fat'],
      'correct': 1,
      'soundFile': 'eaVowelTeam.m4a',
      'phoneme': 'ee',
    },
    {
      'vowelType': 'short i',
      'targetWord': 'sit',
      'options': ['site', 'sat', 'sit'],
      'correct': 2,
      'soundFile': 'iSound.m4a',
    },
    {
      'vowelType': 'long i',
      'targetWord': 'bike',
      'options': ['bike', 'bit', 'bet'],
      'correct': 0,
      'soundFile': 'ieVowelTeam.m4a',
      'phoneme': 'eye',
    },
    {
      'vowelType': 'short o',
      'targetWord': 'hot',
      'options': ['hope', 'hot', 'hut'],
      'correct': 1,
      'soundFile': 'oSound.m4a',
    },
    {
      'vowelType': 'long o',
      'targetWord': 'home',
      'options': ['hop', 'home', 'ham'],
      'correct': 1,
      'soundFile': 'oo1VowelTeam.m4a',
      'phoneme': 'oh',
    },
    {
      'vowelType': 'short u',
      'targetWord': 'cup',
      'options': ['cup', 'cape', 'cube'],
      'correct': 0,
      'soundFile': 'uSound.m4a',
    },
    {
      'vowelType': 'long u',
      'targetWord': 'cube',
      'options': ['cub', 'cab', 'cube'],
      'correct': 2,
      'soundFile': 'ueVowelTeam.m4a',
      'phoneme': 'you',
    },
    {
      'vowelType': 'short a',
      'targetWord': 'hat',
      'options': ['hate', 'hat', 'heat'],
      'correct': 1,
      'soundFile': 'aSound.m4a',
    },
    {
      'vowelType': 'long e',
      'targetWord': 'team',
      'options': ['ten', 'team', 'tan'],
      'correct': 1,
      'soundFile': 'eaVowelTeam.m4a',
      'phoneme': 'ee',
    },
  ];

  String _formatVowelLabel(String vowelType) {
    if (vowelType.isEmpty) return '';
    return '${vowelType[0].toUpperCase()}${vowelType.substring(1)}';
  }

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
      _highScore = prefs.getInt('stage1_vowel_listener_high_score') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    if (correctAnswers > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('stage1_vowel_listener_high_score', correctAnswers);
      _highScore = correctAnswers;
    }
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
          // No evaluation here — auto-advance is handled by the timer in _toggleListening
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
    for (var q in _questions) {
      List<String> options = List.from(q['options']);
      String correctOption = options[q['correct']];
      options.shuffle(_random);
      q['options'] = options;
      q['correct'] = options.indexOf(correctOption);
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
    await _audioPlayer.stop();
    _bounceController.repeat(reverse: true);

    String? soundFile = _questions[currentQuestion]['soundFile'];
    String? phoneme = _questions[currentQuestion]['phoneme'];

    // Play TTS instruction with vowel type only on first play of each question
    if (withInstruction) {
      Completer<void> ttsCompleter = Completer<void>();
      _flutterTts.setCompletionHandler(() {
        if (!ttsCompleter.isCompleted) ttsCompleter.complete();
      });
      await _flutterTts.speak('Tap the word with this vowel sound');
      await ttsCompleter.future;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Play the vowel sound via m4a file or TTS
    if (soundFile != null) {
      Completer<void> audioCompleter = Completer<void>();
      StreamSubscription? sub;
      sub = _instructionPlayer.onPlayerComplete.listen((_) {
        sub?.cancel();
        if (!audioCompleter.isCompleted) audioCompleter.complete();
      });
      await _instructionPlayer.play(AssetSource('sounds/$soundFile'));
      await audioCompleter.future;
    } else if (phoneme != null) {
      Completer<void> ttsPhonemeCompleter = Completer<void>();
      _flutterTts.setCompletionHandler(() {
        if (!ttsPhonemeCompleter.isCompleted) ttsPhonemeCompleter.complete();
      });
      await _flutterTts.speak(phoneme.toLowerCase());
      await ttsPhonemeCompleter.future;
    }

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

  Future<void> _playWordAudio(String word) async {
    Completer<void> ttsCompleter = Completer<void>();
    _flutterTts.setCompletionHandler(() {
      if (!ttsCompleter.isCompleted) ttsCompleter.complete();
    });
    await _flutterTts.speak(word);
    await ttsCompleter.future;
  }

  void _selectAnswer(int index) {
    if (showFeedback || !_buttonsEnabled || _awaitingPronunciation) return;
    setState(() {
      selectedAnswer = index;
      _buttonsEnabled = false;
    });
    // Play the word audio when tapped
    List<String> options = List<String>.from(
      _questions[currentQuestion]['options'],
    );
    _playWordAudio(options[index]).then((_) {
      if (mounted) {
        setState(() {
          _buttonsEnabled = true;
        });
      }
    });
  }

  void _checkAnswer() {
    if (selectedAnswer == null || showFeedback || _isTransitioning) return;
    _isTransitioning = true;

    List<String> options = List<String>.from(
      _questions[currentQuestion]['options'],
    );
    int correct = _questions[currentQuestion]['correct'];
    final selectedCorrectly = selectedAnswer == correct;
    final correctWord = options[correct];

    setState(() {
      showFeedback = true;
      isCorrect = selectedCorrectly;
      _buttonsEnabled = false;
      // AWARD SCORE IMMEDIATELY UPON CORRECT ANSWER SELECTION (matches BlendBuilder)
      if (selectedCorrectly) {
        correctAnswers++;
      }
    });

    _instructionPlayer.stop();
    _flutterTts.stop();

    _audioPlayer.play(
      AssetSource(
        isCorrect ? 'sounds/correctAnswer.wav' : 'sounds/incorrectAnswer.wav',
      ),
    );

    if (!selectedCorrectly) {
      Timer(const Duration(milliseconds: 1200), () {
        _isTransitioning = false;
        _goToNextQuestion();
      });
      return;
    }

    // Correct answer: cancel timer and go to pronunciation phase
    _timer?.cancel();
    setState(() {
      _awaitingPronunciation = true;
      _recognizedText = '';
      _isListening = false;
      _pronunciationTarget = correctWord;
    });

    Future.delayed(const Duration(milliseconds: 250), () async {
      await _flutterTts.speak('Now say the word $correctWord');
      _isTransitioning = false;
    });
  }

  // Matches BlendBuilder exactly: listen for 4s then auto-advance, no evaluation
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

    // Wait exactly 4 seconds then auto-advance (same as BlendBuilder)
    await Future.delayed(const Duration(seconds: 4));

    if (mounted) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });

      // Small delay for visual feedback then go to next question
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
        _pronunciationTarget = '';
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
    int failedAttempts = prefs.getInt('stage1_vowel_listener_failed') ?? 0;
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
                          ? [const Color(0xFF4CAF50), const Color(0xFFA5D6A7)]
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
                    passed ? 'Excellent!' : 'Keep Practicing!',
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
    if (percentage >= 0.9) return 'Amazing vowel listener!';
    if (percentage >= 0.7) return 'Great ear for vowel sounds!';
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
    setState(() {
      isPlaying = false;
      _buttonsEnabled = true;
    });
    _startTimer();
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

    String vowelType = _questions[currentQuestion]['vowelType'];
    List<String> options = List<String>.from(
      _questions[currentQuestion]['options'],
    );

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
            'Vowel Listener',
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.music_note,
                                    color: Color(0xFF4CAF50),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatVowelLabel(vowelType),
                                    style: const TextStyle(
                                      fontFamily: 'Fredoka',
                                      letterSpacing: 0.2,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4CAF50),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap the word with this vowel sound',
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
                        const SizedBox(height: 20),
                        if (_awaitingPronunciation)
                          _buildPronunciationSection()
                        else
                          _buildWordOptions(options),
                        const Spacer(),
                        const SizedBox(height: 12),
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
          const Icon(Icons.audiotrack, color: Color(0xFFFFB300), size: 24),
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
              width: MediaQuery.of(context).size.width * 0.22,
              height: MediaQuery.of(context).size.width * 0.22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      canPlay
                          ? [const Color(0xFF4CAF50), const Color(0xFFA5D6A7)]
                          : [Colors.grey[400]!, Colors.grey[500]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFA5D6A7,
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

  Widget _buildWordOptions(List<String> options) {
    int correct = _questions[currentQuestion]['correct'];

    return Column(
      children: List.generate(options.length, (index) {
        bool isSelected = selectedAnswer == index;
        bool showWrong = showFeedback && isSelected && !isCorrect;

        Color bgColor = Colors.white;
        Color borderColor = const Color(0xFFE0E0E0);
        Color textColor = const Color(0xFF333333);

        if (isSelected && !showFeedback) {
          bgColor = const Color(0xFF4CAF50).withOpacity(0.3);
          borderColor = const Color(0xFF4CAF50);
          textColor = const Color(0xFF4CAF50);
        } else if (showWrong) {
          bgColor = const Color(0xFFE57373).withOpacity(0.2);
          borderColor = const Color(0xFFE57373);
          textColor = const Color(0xFFC62828);
        }

        return GestureDetector(
          onTap: _buttonsEnabled ? () => _selectAnswer(index) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: _buttonsEnabled ? bgColor : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _buttonsEnabled ? borderColor : Colors.grey[300]!,
                width: 2,
              ),
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
                    shape: BoxShape.circle,
                    color: borderColor.withOpacity(0.3),
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index),
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        letterSpacing: 0.2,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _buttonsEnabled ? textColor : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  options[index],
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    letterSpacing: 0.2,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _buttonsEnabled ? textColor : Colors.grey[400],
                  ),
                ),
                const Spacer(),
                if (showWrong)
                  const Icon(Icons.cancel, color: Color(0xFFE57373), size: 24),
              ],
            ),
          ),
        );
      }),
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
              ? (isCorrect ? 'Correct!' : 'Try again!')
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

  Widget _buildPronunciationSection() {
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
            _pronunciationTarget.toUpperCase(),
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
