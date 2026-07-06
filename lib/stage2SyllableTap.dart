import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

class Stage2SyllableTap extends StatefulWidget {
  const Stage2SyllableTap({super.key});

  @override
  State<Stage2SyllableTap> createState() => _Stage2SyllableTapState();
}

class _Stage2SyllableTapState extends State<Stage2SyllableTap>
    with TickerProviderStateMixin {
  int currentQuestion = 0;
  int correctAnswers = 0;
  int totalQuestions = 7;
  int? selectedSyllable;
  bool showFeedback = false;
  bool isCorrect = false;
  bool isPlaying = false;
  bool _awaitingPronunciation = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  int _playCount = 0;
  final int _maxPlays = 4;
  bool _isAutoPlay = false;
  int _highScore = 0;
  Timer? _timer;
  int _remainingSeconds = 45;
  bool _buttonsEnabled = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  late stt.SpeechToText _speech;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  final Random _random = Random();
  List<Map<String, dynamic>> _questions = [];

  final List<Map<String, dynamic>> _allQuestions = [
    {
      'word': 'banana',
      'syllables': ['ba', 'NA', 'na'],
      'stressed': 1,
    },
    {
      'word': 'elephant',
      'syllables': ['EL', 'e', 'phant'],
      'stressed': 0,
    },
    {
      'word': 'computer',
      'syllables': ['com', 'PU', 'ter'],
      'stressed': 1,
    },
    {
      'word': 'butterfly',
      'syllables': ['BUT', 'ter', 'fly'],
      'stressed': 0,
    },
    {
      'word': 'umbrella',
      'syllables': ['um', 'BREL', 'la'],
      'stressed': 1,
    },
    {
      'word': 'beautiful',
      'syllables': ['BEAU', 'ti', 'ful'],
      'stressed': 0,
    },
    {
      'word': 'important',
      'syllables': ['im', 'POR', 'tant'],
      'stressed': 1,
    },
    {
      'word': 'family',
      'syllables': ['FAM', 'i', 'ly'],
      'stressed': 0,
    },
    {
      'word': 'together',
      'syllables': ['to', 'GET', 'her'],
      'stressed': 1,
    },
    {
      'word': 'animal',
      'syllables': ['AN', 'i', 'mal'],
      'stressed': 0,
    },
    {
      'word': 'remember',
      'syllables': ['re', 'MEM', 'ber'],
      'stressed': 1,
    },
    {
      'word': 'wonderful',
      'syllables': ['WON', 'der', 'ful'],
      'stressed': 0,
    },
    {
      'word': 'tomorrow',
      'syllables': ['to', 'MOR', 'row'],
      'stressed': 1,
    },
    {
      'word': 'Saturday',
      'syllables': ['SAT', 'ur', 'day'],
      'stressed': 0,
    },
    {
      'word': 'September',
      'syllables': ['sep', 'TEM', 'ber'],
      'stressed': 1,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _initializeSpeech();
    _initTts();
    _setupAnimations();
    _generateQuestions();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isAutoPlay = true;
      await _playCurrentWord(withInstruction: true);
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
      _buttonsEnabled = false;
    });
    _audioPlayer.play(AssetSource('sounds/incorrectAnswer.wav'));

    Timer(const Duration(milliseconds: 2000), () {
      _goToNextQuestion();
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
          setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isListening = false);
      },
    );
  }

  void _generateQuestions() {
    _questions = List.from(_allQuestions)..shuffle(_random);
    _questions = _questions.take(totalQuestions).toList();
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
    _bounceController.repeat(reverse: true);

    if (withInstruction) {
      Completer<void> ttsCompleter = Completer<void>();
      _flutterTts.setCompletionHandler(() {
        if (!ttsCompleter.isCompleted) ttsCompleter.complete();
      });
      await _flutterTts.speak('Tap the stressed syllable');
      await ttsCompleter.future;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Play only the stressed syllable with emphasis
    List<String> syllables = List<String>.from(
      _questions[currentQuestion]['syllables'],
    );
    int stressedIndex = _questions[currentQuestion]['stressed'];

    await _flutterTts.setPitch(1.35);
    await _flutterTts.setSpeechRate(0.25);
    await _flutterTts.setVolume(1.0);

    Completer<void> sylCompleter = Completer<void>();
    _flutterTts.setCompletionHandler(() {
      if (!sylCompleter.isCompleted) sylCompleter.complete();
    });
    await _flutterTts.speak(syllables[stressedIndex].toLowerCase());
    await sylCompleter.future;

    // Reset TTS to default settings
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.35);
    await _flutterTts.setVolume(1.0);

    await Future.delayed(const Duration(milliseconds: 800));
    _bounceController.stop();
    _bounceController.reset();
    if (mounted) {
      setState(() {
        isPlaying = false;
        _buttonsEnabled = true;
      });
    }
  }

  void _selectSyllable(int index) {
    if (showFeedback || !_buttonsEnabled || _awaitingPronunciation) return;
    setState(() {
      selectedSyllable = index;
    });
  }

  void _checkAnswer() {
    if (selectedSyllable == null) return;

    int correct = _questions[currentQuestion]['stressed'];
    final word = _questions[currentQuestion]['word'] as String;

    setState(() {
      showFeedback = true;
      isCorrect = selectedSyllable == correct;
      if (isCorrect) correctAnswers++;
    });

    _audioPlayer.play(
      AssetSource(
        isCorrect ? 'sounds/correctAnswer.wav' : 'sounds/incorrectAnswer.wav',
      ),
    );

    if (!isCorrect) {
      Timer(const Duration(milliseconds: 1500), () {
        _goToNextQuestion();
      });
      return;
    }

    _timer?.cancel();
    setState(() {
      _awaitingPronunciation = true;
      _buttonsEnabled = false;
      _recognizedText = '';
      _isListening = false;
    });
    _flutterTts.stop();
    _flutterTts.speak('Now say the word $word');
  }

  Future<void> _toggleListening() async {
    if (!_awaitingPronunciation || !_speechAvailable || _isListening) return;

    setState(() {
      _recognizedText = '';
      _isListening = true;
    });

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

    if (!mounted) return;
    await _speech.stop();
    setState(() => _isListening = false);

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _goToNextQuestion();
  }

  void _goToNextQuestion() {
    if (currentQuestion < totalQuestions - 1) {
      _timer?.cancel();
      _speech.stop();
      _audioPlayer.stop();
      _flutterTts.stop();
      setState(() {
        currentQuestion++;
        selectedSyllable = null;
        showFeedback = false;
        _remainingSeconds = 45;
        _playCount = 0;
        _awaitingPronunciation = false;
        _isListening = false;
        _recognizedText = '';
      });
      _startTimer();
      _isAutoPlay = true;
      _playCurrentWord(withInstruction: true);
    } else {
      _showCompletionDialog();
    }
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('stage2_syllable_tap_high_score') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    if (correctAnswers > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('stage2_syllable_tap_high_score', correctAnswers);
      _highScore = correctAnswers;
    }
  }

  String _getFeedbackMessage() {
    double percentage = correctAnswers / totalQuestions;
    if (percentage >= 0.9) return 'Amazing rhythm skills!';
    if (percentage >= 0.7) return 'Great syllable tapping!';
    if (percentage >= 0.5) return 'Good effort! Try again to improve!';
    return 'Keep trying! Practice makes perfect!';
  }

  Future<void> _showCompletionDialog() async {
    _timer?.cancel();
    await _saveHighScore();
    final prefs = await SharedPreferences.getInstance();
    bool passed = correctAnswers >= 4;
    int failedAttempts = prefs.getInt('stage2_syllable_tap_failed') ?? 0;
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
                          ? [const Color(0xFF2196F3), const Color(0xFF2196F3)]
                          : [const Color(0xFFEF9A9A), const Color(0xFFE57373)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    passed ? Icons.touch_app : Icons.sentiment_dissatisfied,
                    size: 70,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    passed ? 'Great Rhythm!' : 'Keep Practicing!',
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
                            selectedSyllable = null;
                            showFeedback = false;
                            _remainingSeconds = 45;
                            _playCount = 0;
                          });
                          _generateQuestions();
                          _isAutoPlay = true;
                          await _playCurrentWord(withInstruction: true);
                          if (mounted) _startTimer();
                        },
                        icon: const Icon(Icons.replay),
                        label: const Text('Play Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor:
                              passed
                                  ? const Color(0xFF64B5F6)
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
                                  ? const Color(0xFF64B5F6)
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
                      color: const Color(0xFF1976D2),
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
                                backgroundColor: const Color(0xFF1976D2),
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
                                foregroundColor: const Color(0xFF1976D2),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: Color(0xFF1976D2),
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
    _speech.stop();
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

    String word = _questions[currentQuestion]['word'];
    List<String> syllables = List<String>.from(
      _questions[currentQuestion]['syllables'],
    );
    int stressed = _questions[currentQuestion]['stressed'];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _timer?.cancel();
        _flutterTts.stop();
        _audioPlayer.stop();
        bool shouldExit = await _showExitWarningDialog();
        if (shouldExit && context.mounted) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            isPlaying = false;
          });
          if (!_buttonsEnabled) {
            _isAutoPlay = true;
            _playCurrentWord(withInstruction: true).then((_) {
              if (mounted) _startTimer();
            });
          } else {
            setState(() {
              _buttonsEnabled = true;
            });
            _startTimer();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE3F2FD),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2196F3),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              _timer?.cancel();
              _flutterTts.stop();
              _audioPlayer.stop();
              bool shouldExit = await _showExitWarningDialog();
              if (shouldExit && context.mounted) {
                Navigator.of(context).pop();
              } else {
                setState(() {
                  isPlaying = false;
                });
                if (!_buttonsEnabled) {
                  _isAutoPlay = true;
                  _playCurrentWord(withInstruction: true).then((_) {
                    if (mounted) _startTimer();
                  });
                } else {
                  setState(() {
                    _buttonsEnabled = true;
                  });
                  _startTimer();
                }
              }
            },
          ),
          title: const Text(
            'Syllable Tap',
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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2196F3).withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.music_note,
                                size: 28,
                                color: Color(0xFF64B5F6),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                word,
                                style: const TextStyle(
                                  fontFamily: 'Fredoka',
                                  letterSpacing: 0.2,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap the STRESSED syllable',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  letterSpacing: 0.2,
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSyllableButtons(syllables, stressed),
                        const Spacer(),
                        const SizedBox(height: 16),
                        if (_awaitingPronunciation)
                          _buildPronunciationSection()
                        else
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
              'Word ${currentQuestion + 1}',
              style: const TextStyle(
                fontFamily: 'Fredoka',
                letterSpacing: 0.2,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2196F3),
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
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
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
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app, color: Color(0xFFFFB300), size: 24),
          const SizedBox(width: 8),
          Text(
            'Score: $correctAnswers',
            style: const TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2196F3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay() {
    Color timerColor =
        _remainingSeconds <= 10 ? Colors.red : const Color(0xFF64B5F6);
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
              width: MediaQuery.of(context).size.width * 0.22,
              height: MediaQuery.of(context).size.width * 0.22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      canPlay
                          ? [const Color(0xFF2196F3), const Color(0xFF2196F3)]
                          : [Colors.grey[400]!, Colors.grey[500]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF90CAF9,
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

  Widget _buildSyllableButtons(List<String> syllables, int stressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(syllables.length, (index) {
        bool isSelected = selectedSyllable == index;
        bool showWrong = showFeedback && isSelected && !isCorrect;

        Color bgColor = Colors.white;
        Color borderColor = const Color(0xFFE0E0E0);
        Color textColor = const Color(0xFF333333);

        if (isSelected && !showFeedback) {
          bgColor = const Color(0xFFBBDEFB).withOpacity(0.3);
          borderColor = const Color(0xFF64B5F6);
          textColor = const Color(0xFF1976D2);
        } else if (showWrong) {
          bgColor = const Color(0xFFE57373).withOpacity(0.2);
          borderColor = const Color(0xFFE57373);
          textColor = const Color(0xFFC62828);
        }

        // Display syllable (capitalize for stressed)
        String displayText = syllables[index].toLowerCase();

        return GestureDetector(
          onTap: _buttonsEnabled ? () => _selectSyllable(index) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _buttonsEnabled ? bgColor : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
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
              children: [
                Text(
                  displayText,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    letterSpacing: 0.2,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: _buttonsEnabled ? textColor : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
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
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed:
            selectedSyllable != null && !showFeedback ? _checkAnswer : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Text(
          showFeedback
              ? (isCorrect ? 'Perfect beat!' : 'Keep the rhythm!')
              : 'Check Answer',
          style: TextStyle(
            fontFamily: 'Fredoka',
            letterSpacing: 0.2,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color:
                (selectedSyllable != null || showFeedback)
                    ? Colors.white
                    : Colors.grey[500],
          ),
        ),
      ),
    );
  }
}
