import 'package:capstone_project/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'courseOneLec1Exercise.dart';
import 'progress_manager.dart';
import 'settings_manager.dart';
import 'notification_helper.dart';

class CourseOneLec1 extends StatefulWidget {
  final bool showModal;

  const CourseOneLec1({super.key, this.showModal = false});

  @override
  State<CourseOneLec1> createState() => _CourseOneLec1State();
}

class _CourseOneLec1State extends State<CourseOneLec1>
    with TickerProviderStateMixin {
  // ── Slide / fade entrance animations ──────────────────────────────────────
  late AnimationController _animationController;
  late AnimationController _contentAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // ── Navigation / sound guards ──────────────────────────────────────────────
  bool _isNavigating = false;
  bool _gameDrillCompleted = false;
  final ProgressManager _progressManager = ProgressManager();
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isSoundPlaying = false;
  String? _activeSoundFile;
  Timer? _soundLockTimer;

  static const String courseId = 'course_one';
  static const int lessonIndex = 0;

  late PageController _pageController;
  int _currentPage = 0;

  // ── Hint state ─────────────────────────────────────────────────────────────
  bool _hintPending = true;
  bool _isDragging = false;

  late AnimationController _hintVisibilityController;
  late AnimationController _swipeController;
  Timer? _showTimer;

  // ── Exercise button pulse (last page hint) ─────────────────────────────────
  late AnimationController _exercisePulseController;
  late Animation<double> _exercisePulseAnimation;

  // ── TTS phrases per page ───────────────────────────────────────────────────
  static const List<String> _ttsPhrases = [
    "Letters make sounds. Let's listen",
    "Each tap plays vowel sound.",
    "Each tap plays a consonant sound",
    "Slow repetition of target sound",
  ];

  static const List<String> _pageTitles = [
    'Lesson Introduction',
    'Vowel Sounds',
    'Consonant Sounds',
    'Sound Recognition',
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
    _swipeController.stop();
    _swipeController.dispose();
    _hintVisibilityController.stop();
    _hintVisibilityController.dispose();
    _initHintControllers();
  }

  /// Called after TTS finishes speaking (or after letter-sound completes on
  /// the last page). Shows the swipe hint on pages 0-2, pulses the exercise
  /// button on page 3.
  void _startHint() {
    _showTimer?.cancel();

    final isLastPage = _currentPage == 3;

    if (isLastPage) {
      // Bounce the exercise button once (same pattern as onboarding).
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

    _initHintControllers();
    _initializeTts();
    _loadExistingProgress();

    _audioPlayer.onPlayerComplete.listen((_) {
      _releaseSoundLock();
      // After a letter sound finishes, start the hint if on the last page.
      if (_currentPage == 3) _startHint();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakCurrentPhrase();
      // Hint is triggered by the TTS completion handler, NOT here.
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Sound lock helpers
  // ──────────────────────────────────────────────────────────────────────────

  void _releaseSoundLock() {
    _soundLockTimer?.cancel();
    _soundLockTimer = null;
    if (mounted) {
      setState(() {
        _isSoundPlaying = false;
        _activeSoundFile = null;
      });
    }
  }

  void _acquireSoundLock({int timeoutSeconds = 8}) {
    _soundLockTimer?.cancel();
    if (mounted) setState(() => _isSoundPlaying = true);
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
    if (_isSoundPlaying) return;
    if (_currentPage >= 0 && _currentPage < _ttsPhrases.length) {
      _acquireSoundLock(timeoutSeconds: 6);
      try {
        await _flutterTts.stop();
        await _flutterTts.speak(_ttsPhrases[_currentPage]);
      } catch (e) {
        debugPrint('TTS speak error: $e');
        _releaseSoundLock();
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Letter sound playback
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _playLetterSound(
    String soundFileName, {
    bool slowPlayback = false,
  }) async {
    if (_isSoundPlaying) return;

    // Stop the pulse while a sound is playing on the last page.
    _stopExercisePulse();

    _acquireSoundLock(timeoutSeconds: 5);
    if (mounted) setState(() => _activeSoundFile = soundFileName);
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
    if (_isNavigating || _isSoundPlaying) return;
    _stopExercisePulse();
    _navigateToExercise();
  }

  void _navigateToExercise() async {
    setState(() => _isNavigating = true);

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => const CourseOneLec1Exercise(),
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
              'Stage1_Exercise',
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
                'Introduction to Phonemes',
              );
            }
          }
        });
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
                                              });
                                              _flutterTts.stop();
                                              _speakCurrentPhrase();
                                              // Hint starts after TTS
                                              // completes via completion
                                              // handler.
                                            },
                                            children: [
                                              _buildLessonIntroduction(),
                                              _buildVowelSounds(),
                                              _buildConsonantSounds(),
                                              _buildSoundRecognition(),
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
                            child: _TapAnimatedButton(
                              onTap: _speakCurrentPhrase,
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
                              child: _TapAnimatedButton(
                                onTap: _startExercise,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  clipBehavior: Clip.hardEdge,
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
                'assets/images/stage1Lesson1.png',
                fit: BoxFit.contain,
                errorBuilder:
                    (_, __, ___) =>
                        const Icon(Icons.image_not_supported, size: 200),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '"Letter make sounds."',
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

  Widget _buildBlock(Map<String, String> block, {bool slowPlayback = false}) {
    return _AnimatedBlock(
      imageName: block['image']!,
      soundName: block['sound']!,
      isSoundPlaying: _isSoundPlaying,
      isActiveBlock: _activeSoundFile == block['sound'],
      slowPlayback: slowPlayback,
      onTap:
          () => _playLetterSound(block['sound']!, slowPlayback: slowPlayback),
    );
  }

  Widget _buildBlockGrid(
    List<Map<String, String>> blocks, {
    bool slowPlayback = false,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 2; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: _buildBlock(blocks[i], slowPlayback: slowPlayback),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 2; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: _buildBlock(blocks[i], slowPlayback: slowPlayback),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: _buildBlock(blocks[4], slowPlayback: slowPlayback),
          ),
        ],
      ),
    );
  }

  Widget _buildVowelSounds() {
    const blocks = [
      {'image': 'aBlock.png', 'sound': 'aSound.m4a'},
      {'image': 'eBlock.png', 'sound': 'eSound.m4a'},
      {'image': 'iBlock.png', 'sound': 'iSound.m4a'},
      {'image': 'oBlock.png', 'sound': 'oSound.m4a'},
      {'image': 'uBlock.png', 'sound': 'uSound.m4a'},
    ];
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder:
                  (context, constraints) =>
                      Center(child: _buildBlockGrid(blocks)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '"Listen to the vowel sound."',
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

  Widget _buildConsonantSounds() {
    const blocks = [
      {'image': 'bBlock.png', 'sound': 'bSound.m4a'},
      {'image': 'cBlock.png', 'sound': 'cSound.m4a'},
      {'image': 'dBlock.png', 'sound': 'dSound.m4a'},
      {'image': 'mBlock.png', 'sound': 'mSound.m4a'},
      {'image': 'sBlock.png', 'sound': 'sSound.m4a'},
    ];
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Center(child: _buildBlockGrid(blocks))),
          const SizedBox(height: 16),
          const Text(
            '"Tap to hear the sound."',
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

  Widget _buildSoundRecognition() {
    const blocks = [
      {'image': 'aBlock.png', 'sound': 'aSound.m4a'},
      {'image': 'iBlock.png', 'sound': 'iSound.m4a'},
      {'image': 'uBlock.png', 'sound': 'uSound.m4a'},
      {'image': 'bBlock.png', 'sound': 'bSound.m4a'},
      {'image': 'sBlock.png', 'sound': 'sSound.m4a'},
    ];
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(child: _buildBlockGrid(blocks, slowPlayback: true)),
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

// ─── Tap-bounce button wrapper ────────────────────────────────────────────────
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

// ─── Animated letter block ────────────────────────────────────────────────────
class _AnimatedBlock extends StatefulWidget {
  final String imageName;
  final String soundName;
  final bool isSoundPlaying;
  final bool isActiveBlock;
  final bool slowPlayback;
  final VoidCallback onTap;

  const _AnimatedBlock({
    required this.imageName,
    required this.soundName,
    required this.isSoundPlaying,
    required this.isActiveBlock,
    required this.slowPlayback,
    required this.onTap,
  });

  @override
  State<_AnimatedBlock> createState() => _AnimatedBlockState();
}

class _AnimatedBlockState extends State<_AnimatedBlock>
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
    final opacity = widget.isSoundPlaying && !widget.isActiveBlock ? 0.45 : 1.0;

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 200),
          child: Image.asset(
            'assets/images/${widget.imageName}',
            width: 115,
            height: 115,
            fit: BoxFit.contain,
            errorBuilder:
                (_, __, ___) => const Icon(Icons.crop_square, size: 100),
          ),
        ),
      ),
    );
  }
}
