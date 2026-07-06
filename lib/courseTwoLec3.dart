import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'courseTwoLec3Exercise.dart';
import 'progress_manager.dart';
import 'settings_manager.dart';
import 'notification_helper.dart';

class CourseTwoLec3 extends StatefulWidget {
  final bool showModal;

  const CourseTwoLec3({super.key, this.showModal = false});

  @override
  State<CourseTwoLec3> createState() => _CourseTwoLec3State();
}

class _CourseTwoLec3State extends State<CourseTwoLec3>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _contentAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isNavigating = false;
  bool _gameDrillCompleted = false;
  final ProgressManager _progressManager = ProgressManager();
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ─── Sound-lock state ───
  bool _isSoundPlaying = false;
  Timer? _soundLockTimer;

  static const String courseId = 'course_two';
  static const int lessonIndex = 2;

  late PageController _pageController;
  int _currentPage = 0;
  int _highlightedWordIndex = -1;

  // ── Hint state ─────────────────────────────────────────────────────────────
  bool _hintPending = true;
  bool _isDragging = false;

  late AnimationController _hintVisibilityController;
  late AnimationController _swipeController;
  Timer? _showTimer;

  // ── Exercise button pulse (last page hint) ─────────────────────────────────
  late AnimationController _exercisePulseController;
  late Animation<double> _exercisePulseAnimation;

  // ──────────────────────────────────────────────────────────────────────────
  // Hint helpers
  // ──────────────────────────────────────────────────────────────────────────

  void _initHintControllers() {
    _hintVisibilityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0.0,
    );
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  void _resetHintControllers() {
    _showTimer?.cancel();
    _swipeController.stop();
    _swipeController.dispose();
    _hintVisibilityController.stop();
    _hintVisibilityController.dispose();
    _initHintControllers();
  }

  /// Called after TTS finishes speaking. Shows the swipe hint on pages 0–2,
  /// pulses the exercise button on page 3.
  void _startHint() {
    _showTimer?.cancel();

    final isLastPage = _currentPage == 3;

    if (isLastPage) {
      _showTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) _playExerciseBounce();
      });
      return;
    }

    if (!_hintPending) return;

    _showTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || !_hintPending) return;
      _updateSwipeDuration();
      _swipeController.repeat();
      _hintVisibilityController.forward();
    });
  }

  void _stopExercisePulse() {
    _exercisePulseController.stop();
    _exercisePulseController.value = 1.0;
  }

  void _playExerciseBounce() {
    if (!mounted) return;
    _exercisePulseController.forward(from: 0);
  }

  void _updateSwipeDuration() {
    _swipeController.duration =
        _currentPage == 0
            ? const Duration(milliseconds: 2200)
            : const Duration(milliseconds: 4500);
  }

  void _onHintCycleComplete() {
    if (!mounted) return;
    setState(() => _hintPending = false);
    _swipeController.stop();
    _hintVisibilityController.reverse();
  }

  void _onDragStart() {
    _showTimer?.cancel();
    _isDragging = true;
    _swipeController.stop();
    _hintVisibilityController.reverse();
  }

  void _onDragEnd() {
    _isDragging = false;
    if (_hintPending && !_swipeController.isAnimating) {
      _showTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted && !_isDragging && _hintPending) {
          _updateSwipeDuration();
          _swipeController.repeat();
          _hintVisibilityController.forward();
        }
      });
    }
  }

  // ── Swipe hint overlay ─────────────────────────────────────────────────────
  Widget _buildSwipeHint(double areaWidth, double areaHeight) {
    if (_currentPage == 3) return const SizedBox.shrink();

    const circleD = 36.0;
    const circleR = circleD / 2;
    final centerX = areaWidth / 2 - circleR;
    final rightEdge = areaWidth - circleD - 16.0;
    const leftEdge = 16.0;
    final circleY = areaHeight * 0.50;
    final isFirstPage = _currentPage == 0;

    return Positioned.fill(
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _hintVisibilityController,
          child: AnimatedBuilder(
            animation: _swipeController,
            builder: (context, _) {
              final t = _swipeController.value;
              double circleX = centerX;
              double circleOpacity = 0.0;
              double rippleOpacity = 0.0;
              double rippleScale = 1.0;
              bool cycleComplete = false;

              if (isFirstPage) {
                if (t < 0.07) {
                  circleOpacity = t / 0.07;
                  circleX = centerX;
                } else if (t < 0.55) {
                  final p = (t - 0.07) / 0.48;
                  circleOpacity = 1.0;
                  circleX =
                      centerX -
                      (centerX - leftEdge) * Curves.easeInOut.transform(p);
                } else if (t < 0.65) {
                  circleOpacity = 1.0 - ((t - 0.55) / 0.10);
                  circleX = leftEdge;
                } else {
                  circleOpacity = 0.0;
                  circleX = centerX;
                  cycleComplete = true;
                }
              } else {
                if (t < 0.06) {
                  circleOpacity = t / 0.06;
                  circleX = centerX;
                  rippleOpacity = (1.0 - t / 0.06) * 0.5;
                  rippleScale = 1.0 + (t / 0.06) * 0.8;
                } else if (t < 0.38) {
                  final p = (t - 0.06) / 0.32;
                  circleOpacity = 1.0;
                  circleX =
                      centerX -
                      (centerX - leftEdge) * Curves.easeInOut.transform(p);
                } else if (t < 0.46) {
                  circleOpacity = 1.0 - ((t - 0.38) / 0.08);
                  circleX = leftEdge;
                } else if (t < 0.50) {
                  circleOpacity = 0.0;
                  circleX = centerX;
                } else if (t < 0.56) {
                  final p = (t - 0.50) / 0.06;
                  circleOpacity = p;
                  circleX = centerX;
                  rippleOpacity = (1.0 - p) * 0.5;
                  rippleScale = 1.0 + p * 0.8;
                } else if (t < 0.88) {
                  final p = (t - 0.56) / 0.32;
                  circleOpacity = 1.0;
                  circleX =
                      centerX +
                      (rightEdge - centerX) * Curves.easeInOut.transform(p);
                } else if (t < 0.96) {
                  circleOpacity = 1.0 - ((t - 0.88) / 0.08);
                  circleX = rightEdge;
                } else {
                  circleOpacity = 0.0;
                  circleX = centerX;
                  cycleComplete = true;
                }
              }

              if (cycleComplete) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _hintPending) _onHintCycleComplete();
                });
              }

              circleOpacity = circleOpacity.clamp(0.0, 1.0);

              return Stack(
                children: [
                  if (!isFirstPage && rippleOpacity > 0)
                    Positioned(
                      left: centerX + circleR - circleR * rippleScale,
                      top: circleY + circleR - circleR * rippleScale,
                      child: Opacity(
                        opacity: rippleOpacity.clamp(0.0, 1.0),
                        child: Container(
                          width: circleD * rippleScale,
                          height: circleD * rippleScale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF41596D).withOpacity(0.45),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: circleX,
                    top: circleY,
                    child: Opacity(
                      opacity: circleOpacity,
                      child: _GlowCircle(diameter: circleD),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
    _contentAnimationController.forward();

    // Exercise pulse controller (last-page hint).
    _exercisePulseController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _exercisePulseAnimation = TweenSequence<double>([
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
    ]).animate(_exercisePulseController);

    _initHintControllers();
    _initializeTts();
    _loadExistingProgress();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playOnPageLoad();
      // Hint is triggered by the TTS completion handler, NOT here.
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Sound-lock helpers
  // ──────────────────────────────────────────────────────────────────────────

  void _releaseSoundLock() {
    _soundLockTimer?.cancel();
    _soundLockTimer = null;
    if (mounted) setState(() => _isSoundPlaying = false);
  }

  void _acquireSoundLock({int timeoutSeconds = 12}) {
    _soundLockTimer?.cancel();
    if (mounted) setState(() => _isSoundPlaying = true);
    _soundLockTimer = Timer(Duration(seconds: timeoutSeconds), () {
      debugPrint('Sound lock timeout — force releasing');
      _releaseSoundLock();
    });
  }

  // ─── TTS helpers ─────────────────────────────────────────────────────────

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(SettingsManager.speechOutputVolume);
      await _flutterTts.setPitch(1.0);
      _flutterTts.setCompletionHandler(() {});
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  /// Speaks a single utterance and waits for completion.
  Future<void> _speakAndWait(String text) async {
    final completer = Completer<void>();
    _flutterTts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    await _flutterTts.speak(text);
    await completer.future;
  }

  // ─── Page-load ────────────────────────────────────────────────────────────

  Future<void> _playOnPageLoad() async {
    if (_isSoundPlaying) return;
    _acquireSoundLock();
    await _flutterTts.stop();
    await _audioPlayer.stop();
    if (mounted) setState(() => _highlightedWordIndex = -1);

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) {
      _releaseSoundLock();
      return;
    }

    switch (_currentPage) {
      case 0:
        await _speakAndWait("Words have beats.");
        break;
      case 1:
        await _speakAndWait("Listen to each beat.");
        break;
      case 2:
        await _speakAndWait("One beat sounds stronger.");
        break;
      case 3:
        await _speakAndWait("Listen again.");
        break;
    }

    _releaseSoundLock();
    _startHint(); // fires after TTS completes on every page
  }

  // ─── Speaker button ───────────────────────────────────────────────────────

  Future<void> _playSpeakerForCurrentPage() async {
    if (_isSoundPlaying) return;
    _acquireSoundLock();
    await _flutterTts.stop();
    await _audioPlayer.stop();
    if (mounted) setState(() => _highlightedWordIndex = -1);

    switch (_currentPage) {
      case 0:
        await _speakAndWait("Words have beats.");
        break;
      case 1:
        await _speakSyllableBreakdown();
        break;
      case 2:
        await _speakStressAwareness();
        break;
      case 3:
        await _speakPage4WithHighlight();
        break;
    }

    _releaseSoundLock();
    // Do NOT call _startHint() for the speaker button — hint only fires
    // on the auto page-load TTS, matching Lec2 behaviour.
  }

  /// Screen 2: "bas" → pause → "ket" → pause → "basket"
  Future<void> _speakSyllableBreakdown() async {
    if (!mounted) return;
    await _flutterTts.setSpeechRate(0.35);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(SettingsManager.speechOutputVolume);

    await _speakAndWait("bus");
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    await _speakAndWait("ket");
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    await _flutterTts.setSpeechRate(0.5);
    await _speakAndWait("basket");

    await _flutterTts.setSpeechRate(0.5);
  }

  /// Screen 3: "TA" (stressed) → pause → "ble" (normal) → pause → "table"
  Future<void> _speakStressAwareness() async {
    if (!mounted) return;

    await _flutterTts.setSpeechRate(0.25);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(
      (SettingsManager.speechOutputVolume).clamp(0.0, 1.0),
    );
    await _speakAndWait("TAY");
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(SettingsManager.speechOutputVolume);
    await _speakAndWait("bul");
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    await _speakAndWait("table");

    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
  }

  /// Screen 4: same as screen 3 with word highlighting
  Future<void> _speakPage4WithHighlight() async {
    if (!mounted) return;

    // "TA" — stressed, highlight index 0
    setState(() => _highlightedWordIndex = 0);
    await _flutterTts.setSpeechRate(0.25);
    await _flutterTts.setPitch(1);
    await _flutterTts.setVolume(
      (SettingsManager.speechOutputVolume).clamp(0.0, 1.0),
    );
    await _speakAndWait("TAY");
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // "ble" — unstressed, highlight index 2
    setState(() => _highlightedWordIndex = 2);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(SettingsManager.speechOutputVolume);
    await _speakAndWait("bul");
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    // "(table)" — full word, highlight index 3
    setState(() => _highlightedWordIndex = 3);
    await _speakAndWait("table");
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) setState(() => _highlightedWordIndex = -1);

    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
  }

  void _loadExistingProgress() {
    setState(() {
      _gameDrillCompleted = _progressManager.isExerciseCompleted(
        courseId,
        lessonIndex,
        'Stage2_Exercise',
      );
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Dispose
  // ──────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _showTimer?.cancel();
    _soundLockTimer?.cancel();
    _flutterTts.stop();
    _audioPlayer.dispose();
    _pageController.dispose();
    _animationController.dispose();
    _contentAnimationController.dispose();
    _swipeController.dispose();
    _hintVisibilityController.dispose();
    _exercisePulseController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Navigation
  // ──────────────────────────────────────────────────────────────────────────

  void _navigateBack() {
    if (_isNavigating) return;
    if (_isSoundPlaying) return;
    setState(() => _isNavigating = true);
    Navigator.of(context).pop();
  }

  void _startExercise() {
    if (_isNavigating) return;
    if (_isSoundPlaying) return;
    _stopExercisePulse();
    _navigateToExercise2();
  }

  void _navigateToExercise2() async {
    setState(() => _isNavigating = true);

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => const CourseTwoLec3Exercise(),
          ),
        )
        .then((result) async {
          _releaseSoundLock();

          final bool wasCompleted = _progressManager.isLessonFullyCompleted(
            courseId,
            lessonIndex,
          );

          setState(() {
            _isNavigating = false;
            if (result != null && result is bool) {
              _gameDrillCompleted = result;
            }
          });

          if (result != null && result is bool) {
            await _progressManager.updateExerciseCompletion(
              courseId,
              lessonIndex,
              'Stage2_Exercise',
              result,
            );
          }
          if (!wasCompleted &&
              result == true &&
              _progressManager.isLessonFullyCompleted(courseId, lessonIndex)) {
            NotificationHelper.onLessonComplete(
              courseId,
              lessonIndex,
              'Syllables and Stress',
            );
          }
        });
  }

  static const List<String> _pageTitles = [
    'Lesson Introduction',
    'Syllable breakdown',
    'Stress Awareness',
    'Listening Pattern',
  ];

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == 3;

    return PopScope(
      canPop: !_isNavigating,
      onPopInvoked: (didPop) {
        if (!didPop) _navigateBack();
      },
      child: SlideTransition(
        position: _slideAnimation,
        child: Scaffold(
          backgroundColor: const Color(0xFFB6DAE8),
          body: SafeArea(
            child: Column(
              children: [
                // ─── HEADER ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      _TapAnimatedButton(
                        onTap: _navigateBack,
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
                    ],
                  ),
                ),

                // ─── BODY ───
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            _pageTitles[_currentPage],
                            style: const TextStyle(
                              color: Color(0xFF000000),
                              fontFamily: 'Fredoka',
                              fontSize: 26,
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 36),
                          Expanded(
                            flex: 4,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  width: 10,
                                  color: const Color(0xFF41596D),
                                ),
                                color: const Color(0xFFFFFCF2),
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    offset: const Offset(2, -2),
                                    blurRadius: 4,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    offset: const Offset(-2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final w = constraints.maxWidth;
                                  final h = constraints.maxHeight;
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: Stack(
                                      clipBehavior: Clip.hardEdge,
                                      children: [
                                        // PageView
                                        GestureDetector(
                                          onHorizontalDragStart:
                                              (_) => _onDragStart(),
                                          onHorizontalDragEnd:
                                              (_) => _onDragEnd(),
                                          onHorizontalDragCancel: _onDragEnd,
                                          onLongPressStart:
                                              (_) => _onDragStart(),
                                          onLongPressEnd: (_) => _onDragEnd(),
                                          onLongPressCancel: _onDragEnd,
                                          behavior: HitTestBehavior.translucent,
                                          child: PageView(
                                            controller: _pageController,
                                            physics:
                                                _isSoundPlaying
                                                    ? const NeverScrollableScrollPhysics()
                                                    : const PageScrollPhysics(),
                                            onPageChanged: (int page) {
                                              if (_isSoundPlaying) return;

                                              // Stop exercise pulse when
                                              // leaving the last page.
                                              if (_currentPage == 3) {
                                                _stopExercisePulse();
                                              }

                                              _resetHintControllers();
                                              setState(() {
                                                _currentPage = page;
                                                _hintPending = true;
                                                _highlightedWordIndex = -1;
                                              });
                                              _playOnPageLoad();
                                              // Hint starts after TTS
                                              // completes via _playOnPageLoad.
                                            },
                                            children: [
                                              _buildLessonIntroduction(),
                                              _buildSentenceListening(),
                                              _buildExpandedSentence(),
                                              _buildSentenceFlow(),
                                            ],
                                          ),
                                        ),

                                        // Swipe hint overlay
                                        KeyedSubtree(
                                          key: ValueKey<int>(_currentPage),
                                          child: _buildSwipeHint(w, h),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          // ─── Speaker button ───
                          Center(
                            child: _TapAnimatedButton(
                              onTap: _playSpeakerForCurrentPage,
                              child: SizedBox(
                                width: 66,
                                height: 66,
                                child: Image.asset(
                                  'assets/images/soundButton.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── BOTTOM: Page dots + Exercise button ───────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: _currentPage == index ? 24 : 10,
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color:
                                  _currentPage == index
                                      ? const Color(0xFF41596D)
                                      : const Color.fromARGB(
                                        255,
                                        255,
                                        255,
                                        255,
                                      ),
                            ),
                          );
                        }),
                      ),

                      // Exercise button (visible + pulsing on last page)
                      SizedBox(
                        width: 120,
                        child: Opacity(
                          opacity: isLastPage ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: !isLastPage,
                            child: AnimatedBuilder(
                              animation: _exercisePulseController,
                              builder:
                                  (context, child) => Transform.scale(
                                    scale: _exercisePulseAnimation.value,
                                    child: child,
                                  ),
                              child: _TapAnimatedButton(
                                onTap: _startExercise,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: Image.asset(
                                    'assets/images/exercise2Button.png',
                                    height: 54,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
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

  // ──────────────────────────────────────────────────────────────────────────
  // Page content builders
  // ──────────────────────────────────────────────────────────────────────────

  // ─── PAGE 1: Lesson Introduction ───
  Widget _buildLessonIntroduction() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/stage2Lesson3.png',
                fit: BoxFit.contain,
                errorBuilder:
                    (_, __, ___) =>
                        const Icon(Icons.image_not_supported, size: 200),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '"Words have beats."',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── PAGE 2: Syllable Breakdown ───
  Widget _buildSentenceListening() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF41596D), width: 6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/basKet.png',
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) =>
                            const Icon(Icons.image_not_supported, size: 120),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF41596D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'bas - ket (basket)',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color.fromARGB(221, 255, 255, 255),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '"Listen to each beat."',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── PAGE 3: Stress Awareness ───
  Widget _buildExpandedSentence() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF41596D), width: 6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/taBle.png',
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) =>
                            const Icon(Icons.image_not_supported, size: 120),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF41596D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'TA - ble (table)',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color.fromARGB(221, 255, 255, 255),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '"One beat sounds stronger."',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── PAGE 4: Listening Pattern — highlighted tokens ───
  Widget _buildSentenceFlow() {
    final List<Map<String, dynamic>> tokens = [
      {'text': 'TA', 'highlightIndex': 0},
      {'text': '-', 'highlightIndex': -1},
      {'text': 'ble', 'highlightIndex': 2},
      {'text': '(table)', 'highlightIndex': 3},
    ];

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF41596D), width: 6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/taBle.png',
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) =>
                            const Icon(Icons.image_not_supported, size: 120),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF41596D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children:
                  tokens.map((token) {
                    final int hi = token['highlightIndex'] as int;
                    final bool isHighlighted =
                        hi != -1 && _highlightedWordIndex == hi;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isHighlighted
                                  ? Colors.white.withOpacity(0.25)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          token['text'] as String,
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: isHighlighted ? 22 : 18,
                            fontWeight:
                                isHighlighted
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                            color:
                                isHighlighted ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '"Listen again."',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Glowing circle (blue palette) ───────────────────────────────────────────
class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.diameter});
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF41596D),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF41596D).withOpacity(0.90),
            blurRadius: 6,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xFF41596D).withOpacity(0.50),
            blurRadius: 14,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: const Color(0xFF41596D).withOpacity(0.22),
            blurRadius: 28,
            spreadRadius: 8,
          ),
        ],
      ),
    );
  }
}

// ─── Reusable tap-bounce button wrapper ──────────────────────────────────────
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
