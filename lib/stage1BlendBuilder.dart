import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

class Stage1BlendBuilder extends StatefulWidget {
  const Stage1BlendBuilder({super.key});

  @override
  State<Stage1BlendBuilder> createState() => _Stage1BlendBuilderState();
}

class _Stage1BlendBuilderState extends State<Stage1BlendBuilder>
    with TickerProviderStateMixin {
  int currentQuestion = 0;
  int correctAnswers = 0;
  int totalQuestions = 7;
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
  final FlutterTts _flutterTts = FlutterTts();
  late stt.SpeechToText _speech;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  final Random _random = Random();
  List<Map<String, dynamic>> _questions = [];
  int _blankIndex = 0;
  String _selectedLetter = '';
  List<String> _letterChoices = [];
  bool _awaitingPronunciation = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  bool _isTransitioning = false;

  final List<Map<String, dynamic>> _allQuestions = [
    {
      'word': 'cat',
      'letters': ['c', 'a', 't'],
    },
    {
      'word': 'dog',
      'letters': ['d', 'o', 'g'],
    },
    {
      'word': 'sun',
      'letters': ['s', 'u', 'n'],
    },
    {
      'word': 'bat',
      'letters': ['b', 'a', 't'],
    },
    {
      'word': 'pin',
      'letters': ['p', 'i', 'n'],
    },
    {
      'word': 'map',
      'letters': ['m', 'a', 'p'],
    },
    {
      'word': 'red',
      'letters': ['r', 'e', 'd'],
    },
    {
      'word': 'top',
      'letters': ['t', 'o', 'p'],
    },
    {
      'word': 'cup',
      'letters': ['c', 'u', 'p'],
    },
    {
      'word': 'hen',
      'letters': ['h', 'e', 'n'],
    },
    {
      'word': 'jam',
      'letters': ['j', 'a', 'm'],
    },
    {
      'word': 'leg',
      'letters': ['l', 'e', 'g'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
    _initializeSpeech();
    _setupAnimations();
    _generateQuestions();
    _setupCurrentQuestion();
    _loadHighScore();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isAutoPlay = true;
      await _playCurrentWord(withInstruction: true);
      if (mounted) _startTimer();
    });
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('stage1_blend_builder_high_score') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    if (correctAnswers > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('stage1_blend_builder_high_score', correctAnswers);
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
          showFeedback = false;
          _remainingSeconds = 35;
          _playCount = 0;
          _buttonsEnabled = false;
        });
        _startTimer();
        _setupCurrentQuestion();
        _isAutoPlay = true;
        _playCurrentWord(withInstruction: true);
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

  void _setupCurrentQuestion() {
    if (currentQuestion >= _questions.length) return;
    List<String> letters = List.from(_questions[currentQuestion]['letters']);
    // Pick a random blank position
    _blankIndex = _random.nextInt(letters.length);
    _selectedLetter = '';

    // Create choices: correct letter + decoys
    String correctLetter = letters[_blankIndex];
    Set<String> choices = {correctLetter};
    const allLetters = [
      'a',
      'b',
      'c',
      'd',
      'e',
      'f',
      'g',
      'h',
      'i',
      'j',
      'k',
      'l',
      'm',
      'n',
      'o',
      'p',
      'r',
      's',
      't',
      'u',
    ];
    while (choices.length < 4) {
      String decoy = allLetters[_random.nextInt(allLetters.length)];
      if (!letters.contains(decoy)) choices.add(decoy);
    }
    _letterChoices = choices.toList()..shuffle(_random);
  }

  Future<void> _playCurrentWord({bool withInstruction = false}) async {
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
    await _optionAudioPlayer.stop();
    _bounceController.repeat(reverse: true);

    // Play instruction via TTS only on first play of each question
    if (withInstruction) {
      Completer<void> ttsCompleter = Completer<void>();
      _flutterTts.setCompletionHandler(() {
        if (!ttsCompleter.isCompleted) ttsCompleter.complete();
      });
      await _flutterTts.speak('Fill in the missing letter');
      await ttsCompleter.future;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Play the word via TTS
    Completer<void> wordCompleter = Completer<void>();
    _flutterTts.setCompletionHandler(() {
      if (!wordCompleter.isCompleted) wordCompleter.complete();
    });
    String word = _questions[currentQuestion]['word'];
    await _flutterTts.speak(word);
    await wordCompleter.future;

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

  void _selectLetter(String letter) {
    if (showFeedback || !_buttonsEnabled || _awaitingPronunciation) return;

    _optionAudioPlayer.stop().then((_) {
      _optionAudioPlayer.play(
        AssetSource('sounds/${letter.toLowerCase()}Sound.m4a'),
      );
    });

    setState(() {
      _selectedLetter = letter;
    });
  }

  Future<void> _checkAnswer() async {
    if (_selectedLetter.isEmpty || showFeedback || _isTransitioning) return;
    _isTransitioning = true;

    String correctLetter = _questions[currentQuestion]['letters'][_blankIndex];
    String correctWord = _questions[currentQuestion]['word'];

    bool builtCorrectly = _selectedLetter == correctLetter;

    setState(() {
      showFeedback = true;
      isCorrect = builtCorrectly;
      _buttonsEnabled = false;
      // AWARD SCORE IMMEDIATELY UPON CORRECT LETTER SELECTION
      if (builtCorrectly) {
        correctAnswers++;
      }
    });

    await _optionAudioPlayer.stop();
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
    setState(() {
      _awaitingPronunciation = true;
      _buttonsEnabled = false;
      _recognizedText = '';
      _isListening = false;
    });
    await Future.delayed(const Duration(milliseconds: 250));
    await _flutterTts.speak('Now say the word $correctWord');
    _isTransitioning = false;
  }

  // UPDATED: Now uses the 4-second auto-advance logic from Course 3
  Future<void> _toggleListening() async {
    if (!_awaitingPronunciation || !_speechAvailable || _isListening) return;

    setState(() {
      _recognizedText = '';
      _isListening = true;
    });

    await _optionAudioPlayer.stop();
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

    // Wait exactly like Course 3
    await Future.delayed(const Duration(seconds: 4));

    if (mounted) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });

      // Small delay then automatically go to next question
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
      _optionAudioPlayer.stop();
      _audioPlayer.stop();
      _flutterTts.stop();
      setState(() {
        currentQuestion++;
        showFeedback = false;
        _remainingSeconds = 35;
        _playCount = 0;
        _buttonsEnabled = false;
        _awaitingPronunciation = false;
        _isListening = false;
        _recognizedText = '';
      });
      _isTransitioning = false;
      _setupCurrentQuestion();
      _startTimer();
      _isAutoPlay = true;
      _playCurrentWord(withInstruction: true);
    } else {
      _showCompletionDialog();
    }
  }

  Future<void> _showCompletionDialog() async {
    _timer?.cancel();
    await _saveHighScore();
    final prefs = await SharedPreferences.getInstance();
    bool passed = correctAnswers >= 4;
    int failedAttempts = prefs.getInt('stage1_blend_builder_failed') ?? 0;
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
                          ? [const Color(0xFF81C784), const Color(0xFF66BB6A)]
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
                    passed ? 'Well Done!' : 'Keep Practicing!',
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
                            showFeedback = false;
                            _remainingSeconds = 35;
                            _playCount = 0;
                            _buttonsEnabled = false;
                          });
                          _generateQuestions();
                          _setupCurrentQuestion();
                          _isAutoPlay = true;
                          _playCurrentWord(withInstruction: true);
                          _startTimer();
                        },
                        icon: const Icon(Icons.replay),
                        label: const Text('Play Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor:
                              passed
                                  ? const Color(0xFF66BB6A)
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
                                  ? const Color(0xFF66BB6A)
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
    if (percentage >= 0.9) return 'Amazing word builder!';
    if (percentage >= 0.7) return 'Great blending skills!';
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
    _audioPlayer.stop();
    _optionAudioPlayer.stop();

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
    _optionAudioPlayer.dispose();
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
          backgroundColor: const Color(0xFF81C784),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _onBackButtonTap,
          ),
          title: const Text(
            'Blend Builder',
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
                        Text(
                          'Fill in the missing letter',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            letterSpacing: 0.2,
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildWordSlots(),
                        const SizedBox(height: 12),
                        if (_awaitingPronunciation)
                          _buildPronunciationSection()
                        else
                          _buildAvailableLetters(),
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
              'Word ${currentQuestion + 1}',
              style: const TextStyle(
                fontFamily: 'Fredoka',
                letterSpacing: 0.2,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF66BB6A),
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
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF81C784)),
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
          const Icon(Icons.extension, color: Color(0xFFFFB300), size: 24),
          const SizedBox(width: 8),
          Text(
            'Built: $correctAnswers',
            style: const TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF66BB6A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay() {
    Color timerColor =
        _remainingSeconds <= 10 ? Colors.red : const Color(0xFF66BB6A);
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
            onTap: canPlay ? _playCurrentWord : null,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.25,
              height: MediaQuery.of(context).size.width * 0.25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      canPlay
                          ? [const Color(0xFF81C784), const Color(0xFF66BB6A)]
                          : [Colors.grey[400]!, Colors.grey[500]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF66BB6A,
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
                    size: 40,
                    color: Colors.white,
                  ),
                  Text(
                    isPlaying
                        ? 'Playing...'
                        : (_playCount >= _maxPlays ? 'No Plays' : 'Hear Word'),
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      letterSpacing: 0.2,
                      fontSize: 11,
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

  Widget _buildWordSlots() {
    List<String> letters = List.from(_questions[currentQuestion]['letters']);
    String correctWord = _questions[currentQuestion]['word'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            showFeedback
                ? (isCorrect
                    ? const Color(0xFF4CAF50).withOpacity(0.2)
                    : const Color(0xFFE57373).withOpacity(0.2))
                : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              showFeedback
                  ? (isCorrect
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE57373))
                  : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(letters.length, (index) {
              bool isBlank = index == _blankIndex;
              String displayLetter = isBlank ? _selectedLetter : letters[index];
              bool hasLetter = displayLetter.isNotEmpty;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 50,
                height: 60,
                decoration: BoxDecoration(
                  color:
                      isBlank
                          ? (hasLetter
                              ? const Color(0xFF81C784).withOpacity(0.2)
                              : Colors.orange.withOpacity(0.1))
                          : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isBlank
                            ? (hasLetter
                                ? const Color(0xFF81C784)
                                : Colors.orange)
                            : Colors.grey[300]!,
                    width: isBlank ? 2 : 1,
                  ),
                ),
                child: Center(
                  child:
                      isBlank && !hasLetter
                          ? Text(
                            '?',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              letterSpacing: 0.2,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[400],
                            ),
                          )
                          : Text(
                            displayLetter.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              letterSpacing: 0.2,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color:
                                  isBlank
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFF616161),
                            ),
                          ),
                ),
              );
            }),
          ),
          if (showFeedback) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.close,
                  color:
                      isCorrect
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE57373),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  isCorrect ? 'Perfect!' : 'The word is: $correctWord',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    letterSpacing: 0.2,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color:
                        isCorrect
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE57373),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailableLetters() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children:
          _letterChoices.map((letter) {
            bool isSelected = _selectedLetter == letter;
            final String correctLetter =
                _questions[currentQuestion]['letters'][_blankIndex];
            final bool showSelectedCorrect =
                showFeedback && isSelected && isCorrect;
            final bool showSelectedWrong =
                showFeedback && isSelected && !isCorrect;
            final bool showCorrectHint =
                showFeedback && !isCorrect && letter == correctLetter;

            Color chipColor =
                _buttonsEnabled ? Colors.white : Colors.grey[200]!;
            Color borderColor =
                _buttonsEnabled ? const Color(0xFF81C784) : Colors.grey[400]!;
            Color textColor =
                _buttonsEnabled ? const Color(0xFF4CAF50) : Colors.grey[400]!;

            if (isSelected && !showFeedback) {
              chipColor = const Color(0xFF81C784).withOpacity(0.3);
              borderColor = const Color(0xFF4CAF50);
            }
            if (showSelectedCorrect || showCorrectHint) {
              chipColor = const Color(0xFF4CAF50).withOpacity(0.2);
              borderColor = const Color(0xFF4CAF50);
              textColor = const Color(0xFF2E7D32);
            } else if (showSelectedWrong) {
              chipColor = const Color(0xFFE57373).withOpacity(0.2);
              borderColor = const Color(0xFFE57373);
              textColor = const Color(0xFFC62828);
            }

            return GestureDetector(
              onTap: _buttonsEnabled ? () => _selectLetter(letter) : null,
              child: Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: (isSelected || showCorrectHint) ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    letter.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      letterSpacing: 0.2,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildPronunciationSection() {
    final correctWord = _questions[currentQuestion]['word'] as String;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF81C784), width: 2),
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
            correctWord.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 28,
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
                        : const Color(0xFF66BB6A),
                boxShadow: [
                  BoxShadow(
                    color: (_isListening
                            ? const Color(0xFFE57373)
                            : const Color(0xFF66BB6A))
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

  Widget _buildCheckButton() {
    bool canCheck =
        _selectedLetter.isNotEmpty && !showFeedback && _buttonsEnabled;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canCheck ? _checkAnswer : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF81C784),
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Text(
          showFeedback
              ? (isCorrect ? 'Great job!' : 'Keep trying!')
              : 'Check Word',
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
}
