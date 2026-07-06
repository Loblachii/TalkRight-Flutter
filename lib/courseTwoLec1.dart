import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'courseTwoLec1Exercise.dart';
import 'progress_manager.dart';
import 'settings_manager.dart';
import 'notification_helper.dart';

class CourseTwoLec1 extends StatefulWidget {
  final bool showModal;

  const CourseTwoLec1({super.key, this.showModal = false});

  @override
  State<CourseTwoLec1> createState() => _CourseTwoLec1State();
}

class _CourseTwoLec1State extends State<CourseTwoLec1>
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
  String? _activeSoundFile;
  String? _activeTtsWord;
  Timer? _soundLockTimer;

  // ── Chained audio flag (suppresses hint mid-chain) ────────────────────────
  bool _isChainedAudio = false;

  static const String courseId = 'course_two';
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

  static const List<String> _ttsPhrases = [
    "Some letters work together to make one sound.",
    "Listen to the sound",
    "Listen to the sound in the word",
    "Listen carefully.",
  ];

  static const List<String> _pageTitles = [
    'Lesson Introduction',
    'Digraph Sounds',
    'Digraphs in Words',
    'Sound Comparison',
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

  /// Called after TTS finishes speaking (or after audio completes on the last
  /// page). Shows the swipe hint on pages 0–2, pulses the exercise button on
  /// page 3.
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
                              // ── Blue palette ripple ──
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

    // Release lock when audio finishes; trigger hint only when NOT mid-chain.
    _audioPlayer.onPlayerComplete.listen((_) {
      _releaseSoundLock();
      if (!_isChainedAudio) _startHint();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playOnPageLoad();
      // Hint is triggered by the TTS/audio completion handlers, NOT here.
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Sound-lock helpers
  // ──────────────────────────────────────────────────────────────────────────

  void _releaseSoundLock() {
    _soundLockTimer?.cancel();
    _soundLockTimer = null;
    if (mounted) {
      setState(() {
        _isSoundPlaying = false;
        _activeSoundFile = null;
        _activeTtsWord = null;
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

  // ─── Re-registers TTS handlers fresh every time before speaking ──────────
  void _registerTtsHandlers({VoidCallback? onComplete}) {
    _flutterTts.setCompletionHandler(() {
      _releaseSoundLock();
      onComplete?.call();
      // Show hint only when TTS finishes with no chained audio following.
      // Pages with chained m4a audio will trigger the hint via onPlayerComplete
      // once _isChainedAudio is false (i.e. after the last m4a finishes).
      if (onComplete == null) _startHint();
    });
    _flutterTts.setCancelHandler(() => _releaseSoundLock());
    _flutterTts.setErrorHandler((msg) {
      debugPrint('TTS error: $msg');
      _releaseSoundLock();
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TTS / audio
  // ──────────────────────────────────────────────────────────────────────────

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

  Future<void> _playLetterSound(String soundFileName) async {
    // Stop exercise pulse while a sound plays on the last page.
    _stopExercisePulse();

    _acquireSoundLock(timeoutSeconds: 5);
    if (mounted) setState(() => _activeSoundFile = soundFileName);
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(SettingsManager.speechOutputVolume);
      await _audioPlayer.play(AssetSource('sounds/$soundFileName'));
      // onPlayerComplete listener calls _releaseSoundLock and _startHint
      // (when _isChainedAudio is false).
    } catch (e) {
      debugPrint('Error playing sound: $e');
      _releaseSoundLock();
    }
  }

  /// Same as _playLetterSound but sets playback rate to 0.6× for page 4.
  Future<void> _playLetterSoundSlow(String soundFileName) async {
    // Stop exercise pulse while a sound plays on the last page.
    _stopExercisePulse();

    _acquireSoundLock(timeoutSeconds: 5);
    if (mounted) setState(() => _activeSoundFile = soundFileName);
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(SettingsManager.speechOutputVolume);
      await _audioPlayer.setPlaybackRate(0.6);
      await _audioPlayer.play(AssetSource('sounds/$soundFileName'));
      // reset rate after this clip finishes so other pages aren't affected
      _audioPlayer.onPlayerComplete.first.then((_) async {
        await _audioPlayer.setPlaybackRate(1.0);
      });
      // lock released by the main onPlayerComplete listener
    } catch (e) {
      debugPrint('Error playing slow sound: $e');
      _releaseSoundLock();
    }
  }

  // ─── Page-load: TTS phrase → then auto-play m4a(s) on page 3 ─────────────
  Future<void> _playOnPageLoad() async {
    if (_isSoundPlaying) return;
    await _flutterTts.stop();
    await _audioPlayer.stop();

    if (_currentPage == 0) {
      // Page 1 — TTS only; hint fires via TTS completion handler.
      _registerTtsHandlers();
      _acquireSoundLock(timeoutSeconds: 6);
      await _flutterTts.speak(_ttsPhrases[0]);
    } else if (_currentPage == 1) {
      // Page 2 — TTS only; hint fires via TTS completion handler.
      _registerTtsHandlers();
      _acquireSoundLock(timeoutSeconds: 6);
      await _flutterTts.speak(_ttsPhrases[1]);
    } else if (_currentPage == 2) {
      // Page 3 — TTS → shDigraph (mid-chain) → th1Digraph (last).
      // Hint fires after th1Digraph completes via onPlayerComplete.
      _registerTtsHandlers(
        onComplete: () async {
          await Future.delayed(const Duration(milliseconds: 300));
          _isChainedAudio = true; // suppress hint after first m4a
          await _playLetterSound('shDigraph.m4a');
          _audioPlayer.onPlayerComplete.first.then((_) async {
            await Future.delayed(const Duration(milliseconds: 400));
            _isChainedAudio = false; // allow hint after last m4a
            await _playLetterSound('th1Digraph.m4a');
          });
        },
      );
      _acquireSoundLock(timeoutSeconds: 6);
      await _flutterTts.speak(_ttsPhrases[2]);
    } else if (_currentPage == 3) {
      // Page 4 — TTS only; hint fires via TTS completion handler.
      _registerTtsHandlers();
      _acquireSoundLock(timeoutSeconds: 6);
      await _flutterTts.speak(_ttsPhrases[3]);
    }
  }

  // ─── Speaker button: skip TTS, replay m4a(s) only ────────────────────────
  Future<void> _playSpeakerForCurrentPage() async {
    if (_isSoundPlaying) return;
    await _flutterTts.stop();
    await _audioPlayer.stop();

    if (_currentPage == 0) {
      _registerTtsHandlers();
      _acquireSoundLock(timeoutSeconds: 6);
      await _flutterTts.speak(_ttsPhrases[0]);
    } else if (_currentPage == 1) {
      _registerTtsHandlers();
      _acquireSoundLock(timeoutSeconds: 6);
      await _flutterTts.speak(_ttsPhrases[1]);
    } else if (_currentPage == 2) {
      // Replay chained m4a pair; hint fires after th1Digraph completes.
      _isChainedAudio = true; // suppress hint after first m4a
      await _playLetterSound('shDigraph.m4a');
      _audioPlayer.onPlayerComplete.first.then((_) async {
        await Future.delayed(const Duration(milliseconds: 400));
        _isChainedAudio = false; // allow hint after last m4a
        await _playLetterSound('th1Digraph.m4a');
      });
    } else if (_currentPage == 3) {
      // Page 4 speaker — replay TTS phrase only.
      _registerTtsHandlers();
      _acquireSoundLock(timeoutSeconds: 6);
      await _flutterTts.speak(_ttsPhrases[3]);
    }
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
    if (_isNavigating || _isSoundPlaying) return;
    _stopExercisePulse();
    _navigateToExercise2();
  }

  void _navigateToExercise2() async {
    setState(() => _isNavigating = true);

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => const CourseTwoLec1Exercise(),
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
            if (!wasCompleted &&
                result == true &&
                _progressManager.isLessonFullyCompleted(
                  courseId,
                  lessonIndex,
                )) {
              NotificationHelper.onLessonComplete(
                courseId,
                lessonIndex,
                'Compound Sounds',
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
          backgroundColor: const Color(0xFFB6DAE8),
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
                                              });
                                              _flutterTts.stop();
                                              _playOnPageLoad();
                                              // Hint starts after TTS/audio
                                              // completes via handlers.
                                            },
                                            children: [
                                              _buildLessonIntroduction(),
                                              _buildDigraphSounds(),
                                              _buildDigraphsInWords(),
                                              _buildSoundComparison(),
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
                'assets/images/stage2Lesson1.png',
                fit: BoxFit.contain,
                errorBuilder:
                    (_, __, ___) =>
                        const Icon(Icons.image_not_supported, size: 200),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '"Some Letters work together."',
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

  Widget _buildSoundBlock(
    String imageName,
    String soundName, {
    required double size,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: _AnimatedBlock(
        imageName: imageName,
        soundName: soundName,
        isSoundPlaying: _isSoundPlaying,
        isActiveBlock: _activeSoundFile == soundName,
        onTap: () => _playLetterSound(soundName),
      ),
    );
  }

  Widget _buildDigraphSounds() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double blockSize = (constraints.maxWidth * 0.38).clamp(
            80.0,
            160.0,
          );
          final double gap = (constraints.maxWidth * 0.12).clamp(16.0, 48.0);

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSoundBlock(
                            'shDigraph.png',
                            'shDigraph.m4a',
                            size: blockSize,
                          ),
                          SizedBox(width: gap),
                          _buildSoundBlock(
                            'thDigraph.png',
                            'thDigraph.m4a',
                            size: blockSize,
                          ),
                        ],
                      ),
                      SizedBox(height: gap),
                      _buildSoundBlock(
                        'chDigraph.png',
                        'chDigraph.m4a',
                        size: blockSize,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '"Listen to the sound."',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 20,
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

  Widget _buildEmojiWordButton({
    required String emoji,
    required String word,
    required String soundFile,
    required double boxSize,
  }) {
    final bool isM4aActive = _activeSoundFile == soundFile;
    final bool isActiveCard = _activeTtsWord == word || isM4aActive;

    return _AnimatedEmojiCard(
      emoji: emoji,
      label: word,
      soundFile: soundFile,
      boxSize: boxSize,
      isSoundPlaying: _isSoundPlaying,
      isActiveCard: isActiveCard,
      isM4aActive: isM4aActive,
      onTap: () async {
        if (_isSoundPlaying) return;
        await _audioPlayer.stop();
        await _flutterTts.stop();
        _registerTtsHandlers();
        if (mounted) {
          setState(() {
            _isSoundPlaying = true;
            _activeTtsWord = word;
          });
        }
        await _flutterTts.speak(word);
      },
    );
  }

  Widget _buildDigraphsInWords() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double boxSize = (constraints.maxWidth * 0.38).clamp(
            80.0,
            160.0,
          );
          final double gap = (constraints.maxWidth * 0.08).clamp(16.0, 40.0);

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildEmojiWordButton(
                        emoji: '🚢',
                        word: 'Ship',
                        soundFile: 'shDigraph.m4a',
                        boxSize: boxSize,
                      ),
                      SizedBox(width: gap),
                      _buildEmojiWordButton(
                        emoji: '👍',
                        word: 'Thumb',
                        soundFile: 'th1Digraph.m4a',
                        boxSize: boxSize,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '"Listen to the sound in the word."',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 20,
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

  Widget _buildSoundComparison() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double blockSize = (constraints.maxWidth * 0.38).clamp(
            80.0,
            160.0,
          );
          final double gap = (constraints.maxWidth * 0.12).clamp(16.0, 48.0);

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: blockSize,
                        height: blockSize,
                        child: _AnimatedBlock(
                          imageName: 'shDigraph.png',
                          soundName: 'shDigraph.m4a',
                          isSoundPlaying: _isSoundPlaying,
                          isActiveBlock: _activeSoundFile == 'shDigraph.m4a',
                          onTap: () => _playLetterSoundSlow('shDigraph.m4a'),
                        ),
                      ),
                      SizedBox(width: gap),
                      SizedBox(
                        width: blockSize,
                        height: blockSize,
                        child: _AnimatedBlock(
                          imageName: 'chDigraph.png',
                          soundName: 'chDigraph.m4a',
                          isSoundPlaying: _isSoundPlaying,
                          isActiveBlock: _activeSoundFile == 'chDigraph.m4a',
                          onTap: () => _playLetterSoundSlow('chDigraph.m4a'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '"Do the sounds match?"',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 20,
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

// ─── Standalone animated block widget ────────────────────────────────────────
class _AnimatedBlock extends StatefulWidget {
  final String imageName;
  final String soundName;
  final bool isSoundPlaying;
  final bool isActiveBlock;
  final VoidCallback onTap;

  const _AnimatedBlock({
    required this.imageName,
    required this.soundName,
    required this.isSoundPlaying,
    required this.isActiveBlock,
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
            width: 125,
            height: 125,
            fit: BoxFit.contain,
            errorBuilder:
                (_, __, ___) => const Icon(Icons.crop_square, size: 100),
          ),
        ),
      ),
    );
  }
}

// ─── Animated emoji card widget ───────────────────────────────────────────────
class _AnimatedEmojiCard extends StatefulWidget {
  final String emoji;
  final String label;
  final String soundFile;
  final double boxSize;
  final bool isSoundPlaying;
  final bool isActiveCard;
  final bool isM4aActive;
  final VoidCallback onTap;

  const _AnimatedEmojiCard({
    required this.emoji,
    required this.label,
    required this.soundFile,
    required this.boxSize,
    required this.isSoundPlaying,
    required this.isActiveCard,
    required this.isM4aActive,
    required this.onTap,
  });

  @override
  State<_AnimatedEmojiCard> createState() => _AnimatedEmojiCardState();
}

class _AnimatedEmojiCardState extends State<_AnimatedEmojiCard>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _colorController;
  late Animation<Color?> _colorAnimation;

  static const Color _baseColor = Color.fromARGB(255, 176, 184, 176);
  static const Color _activeColor = Color(0xFFFF9800);

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

    _colorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _colorAnimation = ColorTween(begin: _baseColor, end: _activeColor).animate(
      CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
    );

    if (widget.isM4aActive) _colorController.forward();
  }

  @override
  void didUpdateWidget(_AnimatedEmojiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isM4aActive && !oldWidget.isM4aActive) {
      _colorController.forward();
    } else if (!widget.isM4aActive && oldWidget.isM4aActive) {
      _colorController.reverse();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isSoundPlaying) return;
    _scaleController.forward(from: 0).then((_) => widget.onTap());
  }

  @override
  Widget build(BuildContext context) {
    final double opacity =
        widget.isSoundPlaying && !widget.isActiveCard ? 0.45 : 1.0;
    final double emojiSize = (widget.boxSize * 0.48).clamp(28.0, 64.0);
    final double fontSize = (widget.boxSize * 0.20).clamp(14.0, 26.0);
    final double radius = (widget.boxSize * 0.18).clamp(12.0, 24.0);

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _colorAnimation,
                builder:
                    (_, child) => Container(
                      width: widget.boxSize,
                      height: widget.boxSize,
                      decoration: BoxDecoration(
                        color: _colorAnimation.value,
                        borderRadius: BorderRadius.circular(radius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            offset: const Offset(0, 4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.emoji,
                          style: TextStyle(fontSize: emojiSize),
                        ),
                      ),
                    ),
              ),
              SizedBox(height: widget.boxSize * 0.10),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
