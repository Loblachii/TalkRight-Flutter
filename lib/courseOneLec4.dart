import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'courseOneLec4Exercise.dart';
import 'progress_manager.dart';
import 'settings_manager.dart';
import 'notification_helper.dart';

class CourseOneLec4 extends StatefulWidget {
  final bool showModal;

  const CourseOneLec4({super.key, this.showModal = false});

  @override
  State<CourseOneLec4> createState() => _CourseOneLec4State();
}

class _CourseOneLec4State extends State<CourseOneLec4>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _contentAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isNavigating = false;
  bool _gameDrillCompleted = false;
  bool _disposed = false;
  bool _ttsAlreadyStopped = false;
  final ProgressManager _progressManager = ProgressManager();
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ─── Sound-lock state ───
  bool _isSoundPlaying = false;
  String? _activeSoundFile;
  Timer? _soundLockTimer;

  static const String courseId = 'course_one';
  static const int lessonIndex = 3;

  late PageController _pageController;
  int _currentPage = 0;

  final Set<int> _tappedLetters = {};

  // ── Hint state ──────────────────────────────────────────────────────────────
  bool _hintPending = true;
  bool _isDragging = false;

  late AnimationController _hintVisibilityController;
  late AnimationController _swipeController;
  Timer? _showTimer;

  // ── Exercise button pulse (last page hint) ──────────────────────────────────
  late AnimationController _exercisePulseController;
  late Animation<double> _exercisePulseAnimation;

  // ── Page-3 tap-sequence hint ────────────────────────────────────────────────
  // Animates through highlighting each of the 3 letter buttons in order
  // before the swipe hint appears.
  late AnimationController _tapSequenceController;
  // 0 = none highlighted, 1/2/3 = that button highlighted
  int _tapSequenceActive = 0; // which button is currently pulsing (0 = off)
  bool _tapSequenceRunning = false;
  Timer? _tapSequenceTimer;

  static const List<String> _ttsPhrases = [
    "Let's blend sounds!",
    "Tap to hear the sound",
    "Blend the sound",
    "This is a cat",
  ];

  static const List<String> _pageTitles = [
    'Lesson Introduction',
    'Individual Sounds',
    'Blending Sounds',
    'Word Meaning',
  ];

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
    _tapSequenceTimer?.cancel();
    _tapSequenceRunning = false;
    _tapSequenceActive = 0;
    _tapSequenceController.stop();
    _tapSequenceController.value = 0;
    _swipeController.stop();
    _swipeController.dispose();
    _hintVisibilityController.stop();
    _hintVisibilityController.dispose();
    _initHintControllers();
  }

  /// Called after TTS finishes (or after audio completes on last page).
  /// - Page 0–1: swipe hint
  /// - Page 2: tap-sequence hint → then swipe hint
  /// - Page 3: exercise pulse
  void _startHint() {
    _showTimer?.cancel();

    final page = _currentPage;

    if (page == 3) {
      // Last page: pulse the exercise button
      _showTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) _playExerciseBounce();
      });
      return;
    }

    if (!_hintPending) return;

    if (page == 2) {
      // Page 3 (index 2): first run the 3-button tap sequence, then swipe hint
      _showTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted || !_hintPending) return;
        _runTapSequenceHint();
      });
      return;
    }

    // Pages 0–1: straight to swipe hint
    _showTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || !_hintPending) return;
      _updateSwipeDuration();
      _swipeController.repeat();
      _hintVisibilityController.forward();
    });
  }

  /// Pulses buttons 0→1→2 in order, then hands off to the swipe hint.
  void _runTapSequenceHint() {
    if (!mounted || _tapSequenceRunning) return;
    _tapSequenceRunning = true;

    const pulseDuration = Duration(milliseconds: 420);
    const pauseDuration = Duration(milliseconds: 160);
    const totalSteps = 3;

    int step = 0;

    void doStep() {
      if (!mounted || !_tapSequenceRunning) return;
      if (step >= totalSteps) {
        // All 3 done — brief pause then swipe hint
        setState(() => _tapSequenceActive = 0);
        _tapSequenceTimer = Timer(const Duration(milliseconds: 400), () {
          if (!mounted || !_hintPending) return;
          _tapSequenceRunning = false;
          _updateSwipeDuration();
          _swipeController.repeat();
          _hintVisibilityController.forward();
        });
        return;
      }

      setState(() => _tapSequenceActive = step + 1); // 1-based
      _tapSequenceController.forward(from: 0);

      _tapSequenceTimer = Timer(pulseDuration + pauseDuration, () {
        if (!mounted) return;
        step++;
        doStep();
      });
    }

    doStep();
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
    _tapSequenceTimer?.cancel();
    _tapSequenceRunning = false;
    if (_tapSequenceActive != 0) setState(() => _tapSequenceActive = 0);
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
                              color: const Color(0xFF577E5F).withOpacity(0.45),
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

    // Tap-sequence pulse controller (page 3 hint).
    _tapSequenceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _initHintControllers();
    _initializeTts();
    _loadExistingProgress();

    // Release sound lock and trigger hint on audio completion.
    _audioPlayer.onPlayerComplete.listen((_) {
      _releaseSoundLock();
      // On last page, audio completion triggers the exercise pulse.
      if (_currentPage == 3) _startHint();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakCurrentPhrase();
      // Hint triggered by TTS completion handler.
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Sound lock helpers
  // ──────────────────────────────────────────────────────────────────────────

  void _releaseSoundLock() {
    _soundLockTimer?.cancel();
    _soundLockTimer = null;
    if (mounted && !_disposed) {
      setState(() {
        _isSoundPlaying = false;
        _activeSoundFile = null;
      });
    }
  }

  void _acquireSoundLock({int timeoutSeconds = 8}) {
    _soundLockTimer?.cancel();
    if (mounted && !_disposed) setState(() => _isSoundPlaying = true);
    _soundLockTimer = Timer(Duration(seconds: timeoutSeconds), () {
      debugPrint('Sound lock timeout — force releasing');
      _releaseSoundLock();
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TTS
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(SettingsManager.speechOutputVolume);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setCompletionHandler(() {
        _releaseSoundLock();
        // Show the hint only after TTS has finished speaking.
        _startHint();
      });
      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS error: $msg');
        _releaseSoundLock();
      });
    } catch (e) {
      debugPrint('TTS initialization error: $e');
      _releaseSoundLock();
    }
  }

  Future<void> _speakCurrentPhrase() async {
    if (_disposed || _isSoundPlaying) return;
    if (_currentPage == 2 && _tappedLetters.length == 3) {
      await _speakWord('cat');
      return;
    }
    if (_currentPage >= 0 && _currentPage < _ttsPhrases.length) {
      _acquireSoundLock(timeoutSeconds: 6);
      try {
        await _flutterTts.stop();
        if (_disposed) {
          _releaseSoundLock();
          return;
        }
        await _flutterTts.speak(_ttsPhrases[_currentPage]);
      } catch (e) {
        debugPrint('TTS speak error: $e');
        _releaseSoundLock();
      }
    }
  }

  Future<void> _speakWord(String word) async {
    if (_disposed || _isSoundPlaying) return;
    _acquireSoundLock(timeoutSeconds: 6);
    try {
      await _flutterTts.stop();
      if (_disposed) {
        _releaseSoundLock();
        return;
      }
      await _flutterTts.speak(word);
    } catch (e) {
      debugPrint('TTS speak word error: $e');
      _releaseSoundLock();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Letter sound playback
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _playLetterSound(
    String soundFileName, {
    bool slowPlayback = false,
  }) async {
    if (_disposed || _isSoundPlaying) return;
    _acquireSoundLock(timeoutSeconds: 5);
    if (mounted && !_disposed) setState(() => _activeSoundFile = soundFileName);
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(SettingsManager.speechOutputVolume);
      await _audioPlayer.setPlaybackRate(slowPlayback ? 0.5 : 1.0);
      await _audioPlayer.play(AssetSource('sounds/$soundFileName'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
      _releaseSoundLock();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Progress
  // ──────────────────────────────────────────────────────────────────────────

  void _loadExistingProgress() {
    setState(() {
      _gameDrillCompleted = _progressManager.isExerciseCompleted(
        courseId,
        lessonIndex,
        'Stage1_Exercise',
      );
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Dispose
  // ──────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    _showTimer?.cancel();
    _soundLockTimer?.cancel();
    _tapSequenceTimer?.cancel();
    // NOTE: We intentionally do NOT call _flutterTts.stop() here.
    // On Infinix X6858, calling stop() in dispose() while TTS is mid-synthesis
    // causes a native SIGSEGV crash.
    _audioPlayer.dispose();
    _pageController.dispose();
    _animationController.dispose();
    _contentAnimationController.dispose();
    _swipeController.dispose();
    _hintVisibilityController.dispose();
    _exercisePulseController.dispose();
    _tapSequenceController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Navigation
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _navigateBack() async {
    if (_isNavigating || _isSoundPlaying) return;
    setState(() => _isNavigating = true);
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('TTS stop before back: $e');
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _startExercise() {
    if (_isNavigating || _isSoundPlaying) return;
    _stopExercisePulse();
    _navigateToExercise();
  }

  Future<void> _navigateToExercise() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    _releaseSoundLock();
    final bool wasCompleted = _progressManager.isLessonFullyCompleted(
      courseId,
      lessonIndex,
    );

    try {
      await _flutterTts.stop();
      _ttsAlreadyStopped = true;
    } catch (e) {
      debugPrint('TTS stop before navigation: $e');
    }

    if (!mounted) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CourseOneLec4Exercise()),
    );

    if (!mounted) return;

    _ttsAlreadyStopped = false;

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
        'Stage1_Exercise',
        result,
      );
      if (!wasCompleted &&
          result == true &&
          _progressManager.isLessonFullyCompleted(courseId, lessonIndex)) {
        NotificationHelper.onLessonComplete(
          courseId,
          lessonIndex,
          'LESSON NAME',
        );
      }
    }

    _speakCurrentPhrase();
  }

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
          backgroundColor: const Color(0xFFB6E8C1),
          body: SafeArea(
            child: Column(
              children: [
                // ─── HEADER ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      _AnimatedImageButton(
                        width: 54,
                        height: 54,
                        onTap: _navigateBack,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/backButton.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── BODY ──────────────────────────────────────────────────
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
                              fontStyle: FontStyle.normal,
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
                                  color: const Color(0xFF577E5F),
                                  width: 10,
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
                                                _tappedLetters.clear();
                                              });
                                              _flutterTts.stop();
                                              _speakCurrentPhrase();
                                              // Hint starts after TTS
                                              // completes via completion handler.
                                            },
                                            children: [
                                              _buildLessonIntroduction(),
                                              _buildIndividualSounds(),
                                              _buildBlendingSounds(),
                                              _buildWordMeaning(),
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
                            child: _AnimatedSpeakerButton(
                              isSoundPlaying: _isSoundPlaying,
                              onTap: _speakCurrentPhrase,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── BOTTOM ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Page dots
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
                                      ? const Color(0xFF577E5F)
                                      : Colors.white,
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
                              child: _AnimatedImageButton(
                                height: 54,
                                onTap: _startExercise,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    'assets/images/exerciseButton.png',
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

  // ─── SCREEN 1 ─────────────────────────────────────────────────────────────
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
                'assets/images/stage1Lesson4.png',
                fit: BoxFit.contain,
                errorBuilder:
                    (_, __, ___) =>
                        const Icon(Icons.image_not_supported, size: 200),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '"Let\'s put sounds together."',
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

  // ─── SCREEN 2 ─────────────────────────────────────────────────────────────
  Widget _buildIndividualSounds() {
    const blocks = [
      {'image': 'cBlock.png', 'sound': 'cSound.m4a'},
      {'image': 'aBlock.png', 'sound': 'aSound.m4a'},
      {'image': 'tBlock.png', 'sound': 'tSound.m4a'},
    ];
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w =
                    constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : 300.0;
                final h =
                    constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : 300.0;
                final blockSize = (w * 0.38).clamp(60.0, 140.0).toDouble();
                final vGap = (h * 0.04).clamp(4.0, 16.0).toDouble();
                return Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSoundButton(blocks[0], blockSize: blockSize),
                            _buildSoundButton(blocks[1], blockSize: blockSize),
                          ],
                        ),
                        SizedBox(height: vGap),
                        _buildSoundButton(blocks[2], blockSize: blockSize),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '"Listen to each sound."',
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

  // ─── SCREEN 3 ─────────────────────────────────────────────────────────────
  Widget _buildBlendingSounds() {
    const blocks = [
      {'image': 'cBlock.png', 'sound': 'cSound.m4a', 'letter': 'C'},
      {'image': 'aBlock.png', 'sound': 'aSound.m4a', 'letter': 'A'},
      {'image': 'tBlock.png', 'sound': 'tSound.m4a', 'letter': 'T'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 300.0;
          final h =
              constraints.maxHeight.isFinite ? constraints.maxHeight : 400.0;
          final blockSize = (w * 0.32).clamp(56.0, 120.0).toDouble();
          final vGap = (h * 0.04).clamp(4.0, 16.0).toDouble();
          final boxSize = (blockSize * 0.52).clamp(40.0, 60.0).toDouble();

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBlendSoundButton(
                      blocks[0],
                      0,
                      blockSize: blockSize,
                      // highlight index 1 = button 0 (1-based → 0-based)
                      hintHighlight: _tapSequenceActive == 1,
                    ),
                    _buildBlendSoundButton(
                      blocks[1],
                      1,
                      blockSize: blockSize,
                      hintHighlight: _tapSequenceActive == 2,
                    ),
                  ],
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: _buildBlendSoundButton(
                  blocks[2],
                  2,
                  blockSize: blockSize,
                  hintHighlight: _tapSequenceActive == 3,
                ),
              ),
              SizedBox(height: vGap * 1.5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final filled = _tappedLetters.contains(i);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: EdgeInsets.symmetric(horizontal: boxSize * 0.15),
                      width: boxSize,
                      height: boxSize,
                      decoration: BoxDecoration(
                        color:
                            filled
                                ? const Color(0xFF577E5F)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(boxSize * 0.22),
                        border: Border.all(
                          color: const Color(0xFF577E5F),
                          width: 2.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          filled ? blocks[i]['letter']! : '',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: boxSize * 0.48,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              SizedBox(height: vGap),
              const Text(
                '"Blend the sounds."',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── SCREEN 4 ─────────────────────────────────────────────────────────────
  Widget _buildWordMeaning() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: _AnimatedCatCard(
                isSoundPlaying: _isSoundPlaying,
                onTap: () => _speakWord('cat'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '"This is a cat."',
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

  // ─── Sound button (pages 1 & 2) ───────────────────────────────────────────
  Widget _buildSoundButton(
    Map<String, String> block, {
    required double blockSize,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: blockSize * 0.06),
      child: SizedBox(
        width: blockSize,
        height: blockSize,
        child: _AnimatedBlock(
          imageName: block['image']!,
          soundName: block['sound']!,
          isSoundPlaying: _isSoundPlaying,
          isActiveBlock: _activeSoundFile == block['sound'],
          onTap: () => _playLetterSound(block['sound']!),
        ),
      ),
    );
  }

  // ─── Blend sound button (page 3) ──────────────────────────────────────────
  Widget _buildBlendSoundButton(
    Map<String, String> block,
    int index, {
    required double blockSize,
    bool hintHighlight = false,
  }) {
    final bool alreadyTapped = _tappedLetters.contains(index);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: blockSize * 0.06),
      child: SizedBox(
        width: blockSize,
        height: blockSize,
        child: _AnimatedBlock(
          imageName: block['image']!,
          soundName: block['sound']!,
          isSoundPlaying: _isSoundPlaying,
          isActiveBlock: _activeSoundFile == block['sound'],
          forceOpacity: alreadyTapped ? 0.55 : null,
          hintHighlight: hintHighlight,
          hintPulseAnimation: _tapSequenceController,
          onTap: () async {
            if (alreadyTapped || _disposed) return;
            // User tapped — cancel any running hint sequence
            _tapSequenceTimer?.cancel();
            _tapSequenceRunning = false;
            if (_tapSequenceActive != 0) {
              setState(() => _tapSequenceActive = 0);
            }
            await _playLetterSound(block['sound']!);
            if (!mounted || _disposed) return;
            setState(() => _tappedLetters.add(index));
            if (_tappedLetters.length == 3) {
              await Future.delayed(const Duration(milliseconds: 2000));
              _speakWord('cat');
            }
          },
        ),
      ),
    );
  }
}

// ─── Glowing circle ───────────────────────────────────────────────────────────
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
        color: const Color(0xFF577E5F),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF577E5F).withOpacity(0.90),
            blurRadius: 6,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xFF577E5F).withOpacity(0.50),
            blurRadius: 14,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: const Color(0xFF577E5F).withOpacity(0.22),
            blurRadius: 28,
            spreadRadius: 8,
          ),
        ],
      ),
    );
  }
}

// ─── Animated image button (back / exercise) ─────────────────────────────────
class _AnimatedImageButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final double height;
  final double? width;

  const _AnimatedImageButton({
    required this.onTap,
    required this.child,
    required this.height,
    this.width,
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

// ─── Animated cat card widget ─────────────────────────────────────────────────
// speakerActive removed — no orange highlight on default TTS speak.
class _AnimatedCatCard extends StatefulWidget {
  final bool isSoundPlaying;
  final VoidCallback onTap;

  const _AnimatedCatCard({required this.isSoundPlaying, required this.onTap});

  @override
  State<_AnimatedCatCard> createState() => _AnimatedCatCardState();
}

class _AnimatedCatCardState extends State<_AnimatedCatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  static const _baseColor = Color(0xFFB0B8B0);

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
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.06,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: _baseColor,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Center(
                child: Text('🐱', style: TextStyle(fontSize: 80)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cat',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Standalone animated block widget ────────────────────────────────────────
class _AnimatedBlock extends StatefulWidget {
  final String imageName;
  final String soundName;
  final bool isSoundPlaying;
  final bool isActiveBlock;
  final double? forceOpacity;

  /// When true, renders a glowing ring around the block as a tap hint.
  final bool hintHighlight;

  /// The controller driving the hint pulse scale (passed from parent).
  final AnimationController? hintPulseAnimation;
  final VoidCallback onTap;

  const _AnimatedBlock({
    required this.imageName,
    required this.soundName,
    required this.isSoundPlaying,
    required this.isActiveBlock,
    required this.onTap,
    this.forceOpacity,
    this.hintHighlight = false,
    this.hintPulseAnimation,
  });

  @override
  State<_AnimatedBlock> createState() => _AnimatedBlockState();
}

class _AnimatedBlockState extends State<_AnimatedBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  // Hint ring pulse animation (driven by _tapSequenceController in parent)
  late Animation<double> _hintScaleAnim;

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

    _buildHintAnim();
  }

  void _buildHintAnim() {
    final ctrl = widget.hintPulseAnimation;
    if (ctrl != null) {
      _hintScaleAnim = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 1.0,
            end: 1.14,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: 1.14,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeIn)),
          weight: 50,
        ),
      ]).animate(ctrl);
    }
  }

  @override
  void didUpdateWidget(_AnimatedBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hintPulseAnimation != widget.hintPulseAnimation) {
      _buildHintAnim();
    }
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
    final double opacity =
        widget.forceOpacity ??
        (widget.isSoundPlaying && !widget.isActiveBlock ? 0.45 : 1.0);

    Widget image = AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 200),
      child: Image.asset(
        'assets/images/${widget.imageName}',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.crop_square, size: 100),
      ),
    );

    // Wrap with hint glow ring when hintHighlight is active
    if (widget.hintHighlight && widget.hintPulseAnimation != null) {
      image = AnimatedBuilder(
        animation: _hintScaleAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: _hintScaleAnim.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow ring
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF577E5F).withOpacity(0.55),
                        blurRadius: 18,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                ),
                child!,
              ],
            ),
          );
        },
        child: image,
      );
    }

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(scale: _scaleAnimation, child: image),
    );
  }
}

// ─── Animated speaker button ──────────────────────────────────────────────────
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
          width: 66,
          height: 66,
          child: Image.asset(
            'assets/images/soundButton.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
