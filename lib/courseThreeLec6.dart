import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'courseThreeLec6Exercise.dart';
import 'progress_manager.dart';
import 'settings_manager.dart';
import 'notification_helper.dart';

class CourseThreeLec6 extends StatefulWidget {
  final bool showModal;
  const CourseThreeLec6({super.key, this.showModal = false});
  @override
  State<CourseThreeLec6> createState() => _CourseThreeLec6State();
}

class _CourseThreeLec6State extends State<CourseThreeLec6>
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

  static const String courseId = 'course_three';
  static const int lessonIndex = 5;

  late PageController _pageController;
  int _currentPage = 0;

  // Screen 3 quiz
  static const int _correctAnswerIndex = 2;
  int? _tappedAnswerIndex;

  static const String _targetSentence = 'The girl is washing her hands.';

  static const List<String> _captionPhrases = [
    'Listen carefully.',
    'Listen to the sentence.',
    'Tap the correct picture.',
    'You may listen again.',
  ];

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

    // Don't show swipe hint on the quiz page (page 2) — user needs to tap
    if (_currentPage == 2) return;

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

  // ── Swipe hint overlay — Course Three palette (0xFF9D5C5D) ────────────────
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
                              color: const Color(0xFF9D5C5D).withOpacity(0.45),
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _playOnPageLoad());
  }

  // ─── Sound-lock helpers ───────────────────────────────────────────────────

  void _releaseSoundLock() {
    _soundLockTimer?.cancel();
    _soundLockTimer = null;
    _flutterTts.setSpeechRate(0.5);
    if (mounted) setState(() => _isSoundPlaying = false);
  }

  void _acquireSoundLock({int timeoutSeconds = 10}) {
    _soundLockTimer?.cancel();
    if (mounted) setState(() => _isSoundPlaying = true);
    _soundLockTimer = Timer(Duration(seconds: timeoutSeconds), () {
      debugPrint('Sound lock timeout — force releasing');
      _releaseSoundLock();
    });
  }

  void _registerTtsHandlers({VoidCallback? onComplete}) {
    _flutterTts.setCompletionHandler(() {
      _releaseSoundLock();
      onComplete?.call();
    });
    _flutterTts.setCancelHandler(() => _releaseSoundLock());
    _flutterTts.setErrorHandler((msg) {
      debugPrint('TTS error: $msg');
      _releaseSoundLock();
    });
  }

  // ─── TTS init ────────────────────────────────────────────────────────────

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(SettingsManager.speechOutputVolume);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  Future<void> _playOnPageLoad() async {
    if (_isSoundPlaying) return;
    await _flutterTts.stop();
    await _audioPlayer.stop();

    if (_currentPage == 0) {
      _registerTtsHandlers(onComplete: _startHint);
      _acquireSoundLock();
      await _flutterTts.speak(_captionPhrases[0]);
    } else if (_currentPage == 1) {
      _acquireSoundLock(timeoutSeconds: 12);
      final c = Completer<void>();
      _flutterTts.setCompletionHandler(() => c.complete());
      _flutterTts.setCancelHandler(() {
        if (!c.isCompleted) c.complete();
        _releaseSoundLock();
      });
      _flutterTts.setErrorHandler((msg) {
        if (!c.isCompleted) c.complete();
        _releaseSoundLock();
      });
      await _flutterTts.speak(_captionPhrases[1]);
      await c.future;
      if (!mounted || !_isSoundPlaying) return;
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted || !_isSoundPlaying) return;
      _registerTtsHandlers(onComplete: _startHint);
      await _flutterTts.speak(_targetSentence);
    } else if (_currentPage == 2) {
      // Skip auto-play if the user has already answered on this page
      if (_tappedAnswerIndex != null) return;
      _acquireSoundLock(timeoutSeconds: 12);
      final c = Completer<void>();
      _flutterTts.setCompletionHandler(() => c.complete());
      _flutterTts.setCancelHandler(() {
        if (!c.isCompleted) c.complete();
        _releaseSoundLock();
      });
      _flutterTts.setErrorHandler((msg) {
        if (!c.isCompleted) c.complete();
        _releaseSoundLock();
      });
      await _flutterTts.speak(_targetSentence);
      await c.future;
      if (!mounted || !_isSoundPlaying) return;
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted || !_isSoundPlaying) return;
      // No hint on quiz page — _startHint guards this already,
      // but we pass it anyway for consistency.
      _registerTtsHandlers(onComplete: _startHint);
      await _flutterTts.speak(_captionPhrases[2]);
    } else if (_currentPage == 3) {
      _registerTtsHandlers(onComplete: _startHint);
      _acquireSoundLock();
      await _flutterTts.speak(_captionPhrases[3]);
    }
  }

  Future<void> _playSpeakerForCurrentPage() async {
    if (_isSoundPlaying) return;
    await _flutterTts.stop();
    await _audioPlayer.stop();

    // Speaker button does NOT re-trigger the hint.
    if (_currentPage == 0) {
      _registerTtsHandlers();
      _acquireSoundLock();
      await _flutterTts.speak(_captionPhrases[0]);
    } else if (_currentPage == 2) {
      _acquireSoundLock(timeoutSeconds: 12);
      final c = Completer<void>();
      _flutterTts.setCompletionHandler(() => c.complete());
      _flutterTts.setCancelHandler(() {
        if (!c.isCompleted) c.complete();
        _releaseSoundLock();
      });
      _flutterTts.setErrorHandler((msg) {
        if (!c.isCompleted) c.complete();
        _releaseSoundLock();
      });
      await _flutterTts.speak(_targetSentence);
      await c.future;
      if (!mounted || !_isSoundPlaying) return;
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted || !_isSoundPlaying) return;
      _registerTtsHandlers();
      await _flutterTts.speak(_captionPhrases[2]);
    } else if (_currentPage == 3) {
      _registerTtsHandlers();
      _acquireSoundLock();
      await _flutterTts.speak(_targetSentence);
    }
  }

  void _loadExistingProgress() {
    setState(() {
      _gameDrillCompleted = _progressManager.isExerciseCompleted(
        courseId,
        lessonIndex,
        'Stage3_Exercise',
      );
    });
  }

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

  void _navigateBack() {
    if (_isNavigating || _isSoundPlaying) return;
    setState(() => _isNavigating = true);
    Navigator.of(context).pop();
  }

  void _startExercise() {
    if (_isNavigating || _isSoundPlaying) return;
    _stopExercisePulse();
    setState(() => _isNavigating = true);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => const CourseThreeLec6Exercise(),
          ),
        )
        .then((result) async {
          await _flutterTts.stop();
          _releaseSoundLock();

          final bool wasCompleted = _progressManager.isLessonFullyCompleted(
            courseId,
            lessonIndex,
          );

          setState(() {
            _isNavigating = false;
            if (result != null && result is bool) _gameDrillCompleted = result;
          });
          if (result != null && result is bool) {
            await _progressManager.updateExerciseCompletion(
              courseId,
              lessonIndex,
              'Stage3_Exercise',
              result,
            );
            if (!wasCompleted &&
                result == true &&
                _progressManager.isLessonFullyCompleted(
                  courseId,
                  lessonIndex,
                )) {
              NotificationHelper.onLessonComplete(
                courseId,
                lessonIndex,
                'Listening & Comprehension Practice',
              );
            }
          }
        });
  }

  static const List<String> _pageTitles = [
    'Lesson Introduction',
    'Short Spoken Sentence',
    'Meaning Recognition',
    'Sentence Replay',
  ];

  bool get _showSpeakerButton => _currentPage != 1 && _currentPage != 2;

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
          backgroundColor: const Color(0xFFE8B6B7),
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
                                  color: const Color(0xFF9D5C5D),
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
                                        // PageView with drag gesture detection
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

                                              // Stop exercise pulse when leaving last page.
                                              if (_currentPage == 3) {
                                                _stopExercisePulse();
                                              }

                                              _resetHintControllers();
                                              setState(() {
                                                _currentPage = page;
                                                _hintPending = true;
                                              });
                                              _flutterTts.stop();
                                              _audioPlayer.stop();
                                              _playOnPageLoad();
                                            },
                                            children: [
                                              _buildLessonIntroduction(),
                                              _buildShortSpokenSentence(),
                                              _buildMeaningRecognition(),
                                              _buildSentenceReplay(),
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
                          Center(
                            child:
                                _showSpeakerButton
                                    ? _TapAnimatedButton(
                                      onTap: _playSpeakerForCurrentPage,
                                      child: SizedBox(
                                        width: 66,
                                        height: 66,
                                        child: Image.asset(
                                          'assets/images/soundButton.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    )
                                    : const SizedBox(width: 66, height: 66),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── BOTTOM ───
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
                                      ? const Color(0xFF9D5C5D)
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
                      SizedBox(
                        width: 120,
                        child: Opacity(
                          opacity: isLastPage ? 1.0 : 0.0,
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
                                    'assets/images/exercise3Button.png',
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

  // ── PAGE 1: Lesson Introduction ────────────────────────────────────────────
  Widget _buildLessonIntroduction() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/stage3Lesson6.png',
                fit: BoxFit.contain,
                errorBuilder:
                    (_, __, ___) =>
                        const Icon(Icons.image_not_supported, size: 200),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '"Listen carefully."',
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

  // ── Shared layout builder for pages 2, 3, 4 ──────────────────────────────
  Widget _buildImageGrid({
    required String caption,
    required Widget Function(String path, double w, double h) imageBuilder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availW = constraints.maxWidth;
        final double availH = constraints.maxHeight;

        final double hPad = availW * 0.06;
        final double vPad = availH * 0.05;
        final double gap = availW * 0.04;

        final double imgW = (availW - hPad * 2 - gap) / 2;
        final double imgH = imgW * 0.75;

        final double captionSize = (availH * 0.055).clamp(14.0, 22.0);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          imageBuilder('assets/images/boyBall.png', imgW, imgH),
                          SizedBox(width: gap),
                          imageBuilder(
                            'assets/images/catSleep.png',
                            imgW,
                            imgH,
                          ),
                        ],
                      ),
                      SizedBox(height: gap),
                      imageBuilder('assets/images/girlWash.png', imgW, imgH),
                    ],
                  ),
                ),
              ),
              SizedBox(height: availH * 0.03),
              Text(
                caption,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: captionSize,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── PAGE 2: Short Spoken Sentence ─────────────────────────────────────────
  Widget _buildShortSpokenSentence() {
    return _buildImageGrid(
      caption: '"Listen to the sentence."',
      imageBuilder: (path, w, h) => _displayImage(path, w, h),
    );
  }

  // ── PAGE 3: Meaning Recognition ───────────────────────────────────────────
  Widget _buildMeaningRecognition() {
    return _buildImageGrid(
      caption: '"Tap the correct picture."',
      imageBuilder: (path, w, h) {
        final index =
            {
              'assets/images/boyBall.png': 0,
              'assets/images/catSleep.png': 1,
              'assets/images/girlWash.png': 2,
            }[path]!;
        return _answerImage(assetPath: path, index: index, imgW: w, imgH: h);
      },
    );
  }

  // ── PAGE 4: Sentence Replay ───────────────────────────────────────────────
  Widget _buildSentenceReplay() {
    return _buildImageGrid(
      caption: '"You may listen again."',
      imageBuilder: (path, w, h) => _displayImage(path, w, h),
    );
  }

  // ── Non-interactive image ─────────────────────────────────────────────────
  Widget _displayImage(String assetPath, double w, double h) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        assetPath,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) => Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.image_not_supported, size: 40),
            ),
      ),
    );
  }

  // ── Tappable answer image with green/red feedback ─────────────────────────
  Widget _answerImage({
    required String assetPath,
    required int index,
    required double imgW,
    required double imgH,
  }) {
    final bool hasAnswered = _tappedAnswerIndex != null;
    final bool isCorrect = index == _correctAnswerIndex;
    final bool tappedCorrectly = _tappedAnswerIndex == _correctAnswerIndex;
    final bool isDimmed = _isSoundPlaying && !hasAnswered;

    final bool showGreen = hasAnswered && isCorrect;
    final bool showRed = hasAnswered && !isCorrect && !tappedCorrectly;

    Color borderColor = Colors.transparent;
    double borderWidth = 0;
    if (showGreen) {
      borderColor = const Color(0xFF4CAF50);
      borderWidth = 5;
    } else if (showRed) {
      borderColor = const Color(0xFFE53935);
      borderWidth = 5;
    }

    return AnimatedOpacity(
      opacity: isDimmed ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap:
            hasAnswered || _isSoundPlaying
                ? null
                : () async {
                  setState(() => _tappedAnswerIndex = index);
                  try {
                    await _audioPlayer.stop();
                    await _audioPlayer.setVolume(
                      SettingsManager.speechOutputVolume,
                    );
                    final sound =
                        (index == _correctAnswerIndex)
                            ? 'sounds/correctAnswer.wav'
                            : 'sounds/incorrectAnswer.wav';
                    await _audioPlayer.play(AssetSource(sound));
                  } catch (e) {
                    debugPrint('Answer sound error: $e');
                  }
                },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: imgW,
          height: imgH,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow:
                (showGreen || showRed)
                    ? [
                      BoxShadow(
                        color: borderColor.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                    : [],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  (showGreen || showRed) ? 10 : 14,
                ),
                child: Image.asset(
                  assetPath,
                  width: imgW,
                  height: imgH,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Container(
                        width: imgW,
                        height: imgH,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.image_not_supported, size: 40),
                      ),
                ),
              ),
              if (showGreen)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              if (showRed)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Glowing circle (Course Three palette) ───────────────────────────────────
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
        color: const Color(0xFF9D5C5D),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9D5C5D).withOpacity(0.90),
            blurRadius: 6,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xFF9D5C5D).withOpacity(0.50),
            blurRadius: 14,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: const Color(0xFF9D5C5D).withOpacity(0.22),
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
