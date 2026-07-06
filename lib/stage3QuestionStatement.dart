import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

class Stage3QuestionStatement extends StatefulWidget {
  const Stage3QuestionStatement({super.key});

  @override
  State<Stage3QuestionStatement> createState() =>
      _Stage3QuestionStatementState();
}

class _Stage3QuestionStatementState extends State<Stage3QuestionStatement>
    with TickerProviderStateMixin {
  int currentQuestion = 0;
  int correctAnswers = 0;
  int totalQuestions = 7;
  String? selectedType;
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

  final List<Map<String, dynamic>> _allQuestions = [
    {'sentence': 'Where is the cat?', 'type': 'question'},
    {'sentence': 'The cat is on the bed.', 'type': 'statement'},
    {'sentence': 'Do you like apples?', 'type': 'question'},
    {'sentence': 'I like apples very much.', 'type': 'statement'},
    {'sentence': 'What time is it?', 'type': 'question'},
    {'sentence': 'It is three o clock.', 'type': 'statement'},
    {'sentence': 'Can you help me?', 'type': 'question'},
    {'sentence': 'I can help you now.', 'type': 'statement'},
    {'sentence': 'How are you today?', 'type': 'question'},
    {'sentence': 'I am feeling happy today.', 'type': 'statement'},
    {'sentence': 'Is it raining outside?', 'type': 'question'},
    {'sentence': 'It is raining outside.', 'type': 'statement'},
    {'sentence': 'Who is your teacher?', 'type': 'question'},
    {'sentence': 'My teacher is Mrs. Smith.', 'type': 'statement'},
    {'sentence': 'Why are you sad?', 'type': 'question'},
    {'sentence': 'I lost my favorite toy.', 'type': 'statement'},
    {'sentence': 'When does school start?', 'type': 'question'},
    {'sentence': 'School starts at eight.', 'type': 'statement'},
    {'sentence': 'Did you eat breakfast?', 'type': 'question'},
    {'sentence': 'I ate toast for breakfast.', 'type': 'statement'},
  ];

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _initTts();
    _setupAnimations();
    _generateQuestions();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isAutoPlay = true;
      await _playCurrentSentence(withInstruction: true);
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
    });
    _audioPlayer.play(AssetSource('sounds/incorrectAnswer.wav'));

    Timer(const Duration(milliseconds: 2000), () {
      if (currentQuestion < totalQuestions - 1) {
        setState(() {
          currentQuestion++;
          selectedType = null;
          showFeedback = false;
          _remainingSeconds = 60;
          _playCount = 0;
        });
        _startTimer();
        _isAutoPlay = true;
        _playCurrentSentence(withInstruction: true);
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
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _generateQuestions() {
    _questions = List.from(_allQuestions)..shuffle(_random);
    _questions = _questions.take(totalQuestions).toList();
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
        'Listen to a sentence and identify if its a question or statement',
      );
      await ttsCompleter.future;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    String sentence = _questions[currentQuestion]['sentence'];
    String type = _questions[currentQuestion]['type'];

    // Adjust pitch for question (rising) vs statement (falling)
    if (type == 'question') {
      await _flutterTts.setPitch(1.2);
    } else {
      await _flutterTts.setPitch(1.0);
    }

    Completer<void> sentenceCompleter = Completer<void>();
    _flutterTts.setCompletionHandler(() {
      if (!sentenceCompleter.isCompleted) sentenceCompleter.complete();
    });
    await _flutterTts.speak(sentence);
    await sentenceCompleter.future;

    await Future.delayed(const Duration(milliseconds: 300));
    _bounceController.stop();
    _bounceController.reset();
    await _flutterTts.setPitch(1.0);
    if (mounted) {
      setState(() {
        isPlaying = false;
        _buttonsEnabled = true;
      });
    }
  }

  void _selectType(String type) {
    if (showFeedback || !_buttonsEnabled) return;
    setState(() {
      selectedType = type;
    });
  }

  void _checkAnswer() {
    if (selectedType == null) return;

    String correct = _questions[currentQuestion]['type'];

    setState(() {
      showFeedback = true;
      isCorrect = selectedType == correct;
      if (isCorrect) correctAnswers++;
    });

    _audioPlayer.play(
      AssetSource(
        isCorrect ? 'sounds/correctAnswer.wav' : 'sounds/incorrectAnswer.wav',
      ),
    );

    Timer(const Duration(milliseconds: 1500), () {
      if (currentQuestion < totalQuestions - 1) {
        _timer?.cancel();
        setState(() {
          currentQuestion++;
          selectedType = null;
          showFeedback = false;
          _remainingSeconds = 60;
          _playCount = 0;
        });
        _startTimer();
        _isAutoPlay = true;
        _playCurrentSentence(withInstruction: true);
      } else {
        _showCompletionDialog();
      }
    });
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('stage3_question_statement_high_score') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    if (correctAnswers > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'stage3_question_statement_high_score',
        correctAnswers,
      );
      _highScore = correctAnswers;
    }
  }

  String _getFeedbackMessage() {
    double percentage = correctAnswers / totalQuestions;
    if (percentage >= 0.9) return 'Amazing intonation skills!';
    if (percentage >= 0.7) return 'Great question detection!';
    if (percentage >= 0.5) return 'Good effort! Try again to improve!';
    return 'Keep trying! Practice makes perfect!';
  }

  Future<void> _showCompletionDialog() async {
    _timer?.cancel();
    await _saveHighScore();
    final prefs = await SharedPreferences.getInstance();
    bool passed = correctAnswers >= 4;
    int failedAttempts = prefs.getInt('stage3_question_statement_failed') ?? 0;
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
                          ? [const Color(0xFF9C27B0), const Color(0xFF8E24AA)]
                          : [const Color(0xFFEF9A9A), const Color(0xFFE57373)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    passed
                        ? Icons.question_answer
                        : Icons.sentiment_dissatisfied,
                    size: 70,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    passed ? 'Intonation Expert!' : 'Keep Practicing!',
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
                            selectedType = null;
                            showFeedback = false;
                            _remainingSeconds = 60;
                            _playCount = 0;
                          });
                          _generateQuestions();
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
                                  ? const Color(0xFF8E24AA)
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
                                  ? const Color(0xFF8E24AA)
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

    String correctType = _questions[currentQuestion]['type'];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _timer?.cancel();
        _flutterTts.stop();
        _audioPlayer.stop();
        final shouldExit = await _showExitWarningDialog();
        if (shouldExit && context.mounted) {
          Navigator.of(context).pop();
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
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              _timer?.cancel();
              _flutterTts.stop();
              _audioPlayer.stop();
              final shouldExit = await _showExitWarningDialog();
              if (shouldExit && context.mounted) {
                Navigator.of(context).pop();
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
            'Question or Statement?',
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
                                color: Colors.purple.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.hearing,
                                size: 28,
                                color: Color(0xFF9C27B0),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Listen to the intonation',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  letterSpacing: 0.2,
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Is it a question or a statement?',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  letterSpacing: 0.2,
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildTypeButtons(correctType),
                        if (showFeedback) ...[
                          const SizedBox(height: 16),
                          _buildSentenceReveal(),
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
                color: Color(0xFF9C27B0),
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
          const Icon(Icons.question_answer, color: Color(0xFFFFB300), size: 24),
          const SizedBox(width: 8),
          Text(
            'Score: $correctAnswers',
            style: const TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9C27B0),
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
                _remainingSeconds <= 15 ? Colors.red : const Color(0xFF9C27B0),
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
                      : const Color(0xFF9C27B0),
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
              width: MediaQuery.of(context).size.width * 0.24,
              height: MediaQuery.of(context).size.width * 0.24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      canPlay
                          ? [const Color(0xFF9C27B0), const Color(0xFF8E24AA)]
                          : [Colors.grey[400]!, Colors.grey[500]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF8E24AA,
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
                size: 50,
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

  Widget _buildTypeButtons(String correctType) {
    return Row(
      children: [
        Expanded(
          child: _buildTypeOption(
            'question',
            'Question',
            Icons.help_outline,
            '?',
            correctType,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTypeOption(
            'statement',
            'Statement',
            Icons.format_align_left,
            '.',
            correctType,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeOption(
    String type,
    String label,
    IconData icon,
    String punctuation,
    String correctType,
  ) {
    bool isSelected = selectedType == type;
    bool showWrong = showFeedback && isSelected && !isCorrect;

    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFFE0E0E0);
    Color iconColor = const Color(0xFF333333);

    if (isSelected && !showFeedback) {
      bgColor = const Color(0xFF9C27B0).withOpacity(0.2);
      borderColor = const Color(0xFF9C27B0);
      iconColor = const Color(0xFF8E24AA);
    } else if (showWrong) {
      bgColor = const Color(0xFFE57373).withOpacity(0.2);
      borderColor = const Color(0xFFE57373);
      iconColor = const Color(0xFFC62828);
    }

    return GestureDetector(
      onTap: () => _selectType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 3),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 36, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  punctuation,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    letterSpacing: 0.2,
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Fredoka',
                letterSpacing: 0.2,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              type == 'question' ? 'Voice goes UP ↑' : 'Voice goes DOWN ↓',
              style: TextStyle(
                fontFamily: 'Fredoka',
                letterSpacing: 0.2,
                fontSize: 12,
                color: iconColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentenceReveal() {
    String sentence = _questions[currentQuestion]['sentence'];
    String type = _questions[currentQuestion]['type'];

    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            sentence,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color:
                  isCorrect ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This is a ${type.toUpperCase()}',
            style: TextStyle(
              fontFamily: 'Fredoka',
              letterSpacing: 0.2,
              fontSize: 14,
              color:
                  isCorrect ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: selectedType != null && !showFeedback ? _checkAnswer : null,
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
              ? (isCorrect ? 'Great ear!' : 'Keep listening!')
              : 'Check Answer',
          style: TextStyle(
            fontFamily: 'Fredoka',
            letterSpacing: 0.2,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color:
                (selectedType != null || showFeedback)
                    ? Colors.white
                    : Colors.grey[500],
          ),
        ),
      ),
    );
  }
}
