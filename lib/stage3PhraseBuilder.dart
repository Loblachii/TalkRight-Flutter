import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

class Stage3PhraseBuilder extends StatefulWidget {
  const Stage3PhraseBuilder({super.key});

  @override
  State<Stage3PhraseBuilder> createState() => _Stage3PhraseBuilderState();
}

class _Stage3PhraseBuilderState extends State<Stage3PhraseBuilder>
    with TickerProviderStateMixin {
  int currentQuestion = 0;
  int correctAnswers = 0;
  int totalQuestions = 7;
  bool showFeedback = false;
  bool isCorrect = false;
  bool isPlaying = false;
  int _playCount = 0;
  final int _maxPlays = 5;
  bool _isAutoPlay = false;
  int _highScore = 0;
  bool _buttonsEnabled = false;

  Timer? _timer;
  int _remainingSeconds = 60;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  final Random _random = Random();
  List<Map<String, dynamic>> _questions = [];
  int _blankPhraseIndex = 0;
  String _selectedPhrase = '';
  List<String> _phraseChoices = [];

  final List<Map<String, dynamic>> _allQuestions = [
    {
      'sentence': 'The big dog runs fast.',
      'phrases': ['The big dog', 'runs fast'],
    },
    {
      'sentence': 'I like to eat apples.',
      'phrases': ['I like', 'to eat apples'],
    },
    {
      'sentence': 'She went to the store.',
      'phrases': ['She went', 'to the store'],
    },
    {
      'sentence': 'The cat is sleeping now.',
      'phrases': ['The cat', 'is sleeping now'],
    },
    {
      'sentence': 'We play in the park.',
      'phrases': ['We play', 'in the park'],
    },
    {
      'sentence': 'He reads books every day.',
      'phrases': ['He reads books', 'every day'],
    },
    {
      'sentence': 'The bird flies in the sky.',
      'phrases': ['The bird flies', 'in the sky'],
    },
    {
      'sentence': 'My mom cooks dinner for us.',
      'phrases': ['My mom', 'cooks dinner', 'for us'],
    },
    {
      'sentence': 'The children are playing outside.',
      'phrases': ['The children', 'are playing outside'],
    },
    {
      'sentence': 'I see a beautiful flower.',
      'phrases': ['I see', 'a beautiful flower'],
    },
    {
      'sentence': 'The sun shines very brightly.',
      'phrases': ['The sun', 'shines very brightly'],
    },
    {
      'sentence': 'They went home after school.',
      'phrases': ['They went home', 'after school'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _initTts();
    _setupAnimations();
    _generateQuestions();
    _setupCurrentQuestion();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isAutoPlay = true;
      await _playCurrentSentence(withInstruction: true);
      if (mounted) _startTimer();
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
          _remainingSeconds = 60;
          _playCount = 0;
        });
        _startTimer();
        _setupCurrentQuestion();
        _isAutoPlay = true;
        _playCurrentSentence(withInstruction: true);
      } else {
        _showCompletionDialog();
      }
    });
  }

  void _generateQuestions() {
    _questions = List.from(_allQuestions)..shuffle(_random);
    _questions = _questions.take(totalQuestions).toList();
  }

  void _setupCurrentQuestion() {
    if (currentQuestion >= _questions.length) return;

    List<String> phrases = List.from(_questions[currentQuestion]['phrases']);
    // Pick a random phrase to blank out
    _blankPhraseIndex = _random.nextInt(phrases.length);
    _selectedPhrase = '';

    // Create choices: correct phrase + decoys from other questions
    String correctPhrase = phrases[_blankPhraseIndex];
    Set<String> choices = {correctPhrase};

    // Gather decoy phrases from other questions
    List<String> allDecoys = [];
    for (var q in _allQuestions) {
      for (String p in q['phrases']) {
        if (p != correctPhrase) allDecoys.add(p);
      }
    }
    allDecoys.shuffle(_random);
    for (String decoy in allDecoys) {
      if (choices.length >= 4) break;
      choices.add(decoy);
    }
    _phraseChoices = choices.toList()..shuffle(_random);
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
        'Listen to a sentence and select the missing phrase',
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

  void _selectPhrase(String phrase) {
    if (showFeedback || !_buttonsEnabled) return;
    setState(() {
      _selectedPhrase = phrase;
    });
  }

  void _checkAnswer() {
    if (_selectedPhrase.isEmpty) return;

    String correctPhrase =
        _questions[currentQuestion]['phrases'][_blankPhraseIndex];
    bool correct = _selectedPhrase == correctPhrase;

    setState(() {
      showFeedback = true;
      isCorrect = correct;
      if (isCorrect) correctAnswers++;
    });

    _audioPlayer.play(
      AssetSource(
        isCorrect ? 'sounds/correctAnswer.wav' : 'sounds/incorrectAnswer.wav',
      ),
    );

    Timer(const Duration(milliseconds: 2000), () {
      if (currentQuestion < totalQuestions - 1) {
        _timer?.cancel();
        setState(() {
          currentQuestion++;
          showFeedback = false;
          _remainingSeconds = 60;
          _playCount = 0;
        });
        _startTimer();
        _setupCurrentQuestion();
        _isAutoPlay = true;
        _playCurrentSentence();
      } else {
        _showCompletionDialog();
      }
    });
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('stage3_phrase_builder_high_score') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    if (correctAnswers > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('stage3_phrase_builder_high_score', correctAnswers);
      _highScore = correctAnswers;
    }
  }

  String _getFeedbackMessage() {
    double percentage = correctAnswers / totalQuestions;
    if (percentage >= 0.9) return 'Amazing building skills!';
    if (percentage >= 0.7) return 'Great phrase building!';
    if (percentage >= 0.5) return 'Good effort! Try again to improve!';
    return 'Keep trying! Practice makes perfect!';
  }

  Future<void> _showCompletionDialog() async {
    _timer?.cancel();
    await _saveHighScore();
    final prefs = await SharedPreferences.getInstance();
    bool passed = correctAnswers >= 4;
    int failedAttempts = prefs.getInt('stage3_phrase_builder_failed') ?? 0;
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
                          ? [const Color(0xFF9C27B0), const Color(0xFF7E57C2)]
                          : [const Color(0xFFEF9A9A), const Color(0xFFE57373)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    passed ? Icons.construction : Icons.sentiment_dissatisfied,
                    size: 70,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    passed ? 'Building Expert!' : 'Keep Practicing!',
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
                            showFeedback = false;
                            _remainingSeconds = 60;
                            _playCount = 0;
                          });
                          _generateQuestions();
                          _setupCurrentQuestion();
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
                                  ? const Color(0xFF7E57C2)
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
                                  ? const Color(0xFF7E57C2)
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
                      color: const Color(0xFF7E57C2),
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
                                backgroundColor: const Color(0xFF7E57C2),
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
                                foregroundColor: const Color(0xFF7E57C2),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: Color(0xFF7E57C2),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _timer?.cancel();
        _flutterTts.stop();
        _audioPlayer.stop();
        final shouldExit = await _showExitWarningDialog();
        if (shouldExit) {
          if (context.mounted) Navigator.of(context).pop();
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
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              _timer?.cancel();
              _flutterTts.stop();
              _audioPlayer.stop();
              final shouldExit = await _showExitWarningDialog();
              if (shouldExit) {
                if (context.mounted) Navigator.of(context).pop();
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
            'Phrase Builder',
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
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
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
                          'Fill in the missing phrase',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            letterSpacing: 0.2,
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildArrangementArea(),
                        const SizedBox(height: 12),
                        _buildAvailablePhrases(),
                        if (showFeedback) ...[
                          const SizedBox(height: 12),
                          _buildFeedback(),
                        ],
                        const Spacer(),
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
                color: Color(0xFF7E57C2),
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
          const Icon(Icons.construction, color: Color(0xFFFFB300), size: 24),
          const SizedBox(width: 8),
          Text(
            'Built: $correctAnswers',
            style: const TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7E57C2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _remainingSeconds <= 15 ? Colors.red[50] : Colors.white,
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
          Icon(
            Icons.timer,
            color:
                _remainingSeconds <= 15 ? Colors.red : const Color(0xFF7E57C2),
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            '${_remainingSeconds}s',
            style: TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color:
                  _remainingSeconds <= 15
                      ? Colors.red
                      : const Color(0xFF7E57C2),
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
              width: MediaQuery.of(context).size.width * 0.18,
              height: MediaQuery.of(context).size.width * 0.18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      canPlay
                          ? [const Color(0xFF9C27B0), const Color(0xFF7E57C2)]
                          : [Colors.grey[400]!, Colors.grey[500]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF7E57C2,
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
                size: 36,
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

  Widget _buildArrangementArea() {
    List<String> phrases = List.from(_questions[currentQuestion]['phrases']);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              showFeedback
                  ? (isCorrect
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE57373))
                  : const Color(0xFFE0E0E0),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: List.generate(phrases.length, (index) {
          bool isBlank = index == _blankPhraseIndex;
          String displayText = isBlank ? _selectedPhrase : phrases[index];
          bool hasFill = displayText.isNotEmpty;

          if (isBlank) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              constraints: const BoxConstraints(minWidth: 80),
              decoration: BoxDecoration(
                color:
                    hasFill
                        ? (showFeedback
                            ? (isCorrect
                                ? const Color(0xFF4CAF50).withOpacity(0.2)
                                : const Color(0xFFE57373).withOpacity(0.2))
                            : const Color(0xFF9C27B0).withOpacity(0.2))
                        : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      hasFill
                          ? (showFeedback
                              ? (isCorrect
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFE57373))
                              : const Color(0xFF7E57C2))
                          : Colors.orange,
                  width: 2,
                  style: hasFill ? BorderStyle.solid : BorderStyle.none,
                ),
              ),
              child: Text(
                hasFill ? displayText : '________',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  letterSpacing: 0.2,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      hasFill
                          ? (showFeedback
                              ? (isCorrect
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828))
                              : const Color(0xFF673AB7))
                          : Colors.orange[400],
                ),
              ),
            );
          }

          // Pre-filled phrase
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              phrases[index],
              style: const TextStyle(
                fontFamily: 'Fredoka',
                letterSpacing: 0.2,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF616161),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAvailablePhrases() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            _phraseChoices.map((phrase) {
              bool isSelected = _selectedPhrase == phrase;
              return GestureDetector(
                onTap: () => _selectPhrase(phrase),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? const Color(0xFF9C27B0).withOpacity(0.3)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected
                              ? const Color(0xFF7E57C2)
                              : const Color(0xFF9C27B0),
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    phrase,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      letterSpacing: 0.2,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF673AB7),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildFeedback() {
    String sentence = _questions[currentQuestion]['sentence'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isCorrect
                ? const Color(0xFF4CAF50).withOpacity(0.1)
                : const Color(0xFFE57373).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.info,
                color:
                    isCorrect
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFE57373),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct!' : 'Correct sentence:',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  letterSpacing: 0.2,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color:
                      isCorrect
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE57373),
                ),
              ),
            ],
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 8),
            Text(
              sentence,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                letterSpacing: 0.2,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckButton() {
    bool canCheck = _selectedPhrase.isNotEmpty && !showFeedback;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canCheck ? _checkAnswer : null,
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
              ? (isCorrect ? 'Well built!' : 'Keep building!')
              : 'Check Phrase',
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
