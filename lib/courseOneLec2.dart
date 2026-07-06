import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'courseOneLec2Exercise.dart';
import 'progress_manager.dart';
import 'settings_manager.dart';
import 'notification_helper.dart';

class CourseOneLec2 extends StatefulWidget {
  final bool showModal;

  const CourseOneLec2({super.key, this.showModal = false});

  @override
  State<CourseOneLec2> createState() => _CourseOneLec2State();
}

class _CourseOneLec2State extends State<CourseOneLec2>
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
  String? _activeTtsWord;

  // ── Chained audio flag (suppresses hint mid-chain on page 3) ──────────────
  bool _isChainedAudio = false;

  static const String courseId = 'course_one';
  static const int lessonIndex = 1;

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
    "Some sounds are short. Some are long.",
    "Short sound.",
    "Long sound.",
    "Listen and compare.",
  ];

  static const List<String> _pageTitles = [
    'Lesson Introduction',
    'Short Vowel Example',
    'Long Vowel Example',
    'Compare Sound',
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

  /// Called after TTS finishes speaking (or after audio playback completes on
  /// the last page). Shows the swipe hint on pages 0–2, pulses the exercise
  /// button on page 3.
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

    // FIX: Release lock when audio finishes and trigger hint for ALL pages
    // (not just page 3). The _isChainedAudio flag suppresses the hint
    // mid-chain on page 3 so it only fires after the final m4a completes.
    _audioPlayer.onPlayerComplete.listen((_) {
      _releaseSoundLock();
      if (!_isChainedAudio) _startHint();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playOnPageLoad();
      // Hint is triggered by the TTS/audio completion handler, NOT here.
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Sound lock helpers
  // ──────────────────────────────────────────────────────────────────────────

  void _releaseSoundLock() {
    if (mounted) {
      setState(() {
        _isSoundPlaying = false;
        _activeSoundFile = null;
        _activeTtsWord = null;
      });
    }
  }

  /// Re-registers TTS handlers fresh every time before speaking,
  /// so the exercise screen can never permanently steal our callbacks.
  void _registerTtsHandlers({VoidCallback? onComplete}) {
    _flutterTts.setCompletionHandler(() {
      _releaseSoundLock();
      onComplete?.call();
      // Show the hint only after TTS has finished speaking (no audio follows).
      if (onComplete == null) _startHint();
    });
    _flutterTts.setCancelHandler(() => _releaseSoundLock());
    _flutterTts.setErrorHandler((msg) {
      debugPrint('TTS error: $msg');
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
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Letter sound playback
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _playLetterSound(
    String soundFileName, {
    bool slowPlayback = false,
  }) async {
    // Stop the pulse while a sound is playing on the last page.
    _stopExercisePulse();

    try {
      if (mounted) {
        setState(() {
          _isSoundPlaying = true;
          _activeSoundFile = soundFileName;
        });
      }
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(SettingsManager.speechOutputVolume);
      await _audioPlayer.setPlaybackRate(slowPlayback ? 0.5 : 1.0);
      await _audioPlayer.play(AssetSource('sounds/$soundFileName'));
      // onPlayerComplete releases the lock and triggers hint (when not chained).
    } catch (e) {
      debugPrint('Error playing sound: $e');
      _releaseSoundLock();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Page audio sequencing
  // ──────────────────────────────────────────────────────────────────────────

  /// Called on page load → TTS first, then auto-plays m4a after TTS finishes.
  Future<void> _playOnPageLoad() async {
    if (_isSoundPlaying) return;
    await _flutterTts.stop();
    await _audioPlayer.stop();

    if (_currentPage == 0) {
      // Page 0: TTS only → hint fires from completion handler.
      _registerTtsHandlers();
      if (mounted) setState(() => _isSoundPlaying = true);
      await _flutterTts.speak(_ttsPhrases[0]);
    } else if (_currentPage == 1) {
      // Page 1: TTS → short vowel sound.
      // FIX: hint fires from onPlayerComplete (via _isChainedAudio = false).
      _registerTtsHandlers(
        onComplete: () async {
          await Future.delayed(const Duration(milliseconds: 300));
          _isChainedAudio = false; // single m4a — hint fires after it finishes
          await _playLetterSound('aSound.m4a');
        },
      );
      if (mounted) setState(() => _isSoundPlaying = true);
      await _flutterTts.speak(_ttsPhrases[1]);
    } else if (_currentPage == 2) {
      // Page 2: TTS → long vowel sound.
      // FIX: hint fires from onPlayerComplete (via _isChainedAudio = false).
      _registerTtsHandlers(
        onComplete: () async {
          await Future.delayed(const Duration(milliseconds: 300));
          _isChainedAudio = false; // single m4a — hint fires after it finishes
          await _playLetterSound('aeVowelTeam.m4a');
        },
      );
      if (mounted) setState(() => _isSoundPlaying = true);
      await _flutterTts.speak(_ttsPhrases[2]);
    } else if (_currentPage == 3) {
      // Page 3: TTS → short at 0.5x → long at 0.5x.
      // FIX: _isChainedAudio = true suppresses hint after first m4a.
      //      _isChainedAudio = false before last m4a lets hint fire after it.
      _registerTtsHandlers(
        onComplete: () async {
          await Future.delayed(const Duration(milliseconds: 300));
          _isChainedAudio = true; // mid-chain: suppress hint on first complete
          await _playLetterSound('aSound.m4a', slowPlayback: true);
          _audioPlayer.onPlayerComplete.first.then((_) async {
            await Future.delayed(const Duration(milliseconds: 400));
            _isChainedAudio = false; // last sound: allow hint to fire
            await _playLetterSound('aeVowelTeam.m4a', slowPlayback: true);
          });
        },
      );
      if (mounted) setState(() => _isSoundPlaying = true);
      await _flutterTts.speak(_ttsPhrases[3]);
    }
  }

  /// Called by the speaker button → re-plays the audio for the current page.
  Future<void> _playSpeakerForCurrentPage() async {
    if (_isSoundPlaying) return;
    await _flutterTts.stop();
    await _audioPlayer.stop();

    if (_currentPage == 0) {
      _registerTtsHandlers();
      if (mounted) setState(() => _isSoundPlaying = true);
      await _flutterTts.speak(_ttsPhrases[0]);
    } else if (_currentPage == 1) {
      // FIX: single m4a, hint fires normally after completion.
      _isChainedAudio = false;
      await _playLetterSound('aSound.m4a');
    } else if (_currentPage == 2) {
      // FIX: single m4a, hint fires normally after completion.
      _isChainedAudio = false;
      await _playLetterSound('aeVowelTeam.m4a');
    } else if (_currentPage == 3) {
      // FIX: chained sequence — suppress hint until final m4a completes.
      _isChainedAudio = true;
      await _playLetterSound('aSound.m4a', slowPlayback: true);
      _audioPlayer.onPlayerComplete.first.then((_) async {
        await Future.delayed(const Duration(milliseconds: 400));
        _isChainedAudio = false;
        await _playLetterSound('aeVowelTeam.m4a', slowPlayback: true);
      });
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
            builder: (context) => const CourseOneLec2Exercise(),
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
                'Short vs. Long Vowel Sounds',
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
                                        // PageView with drag gesture detectors
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
                                              // completes via completion handler.
                                            },
                                            children: [
                                              _buildLessonIntroduction(),
                                              _buildShortVowel(),
                                              _buildLongVowel(),
                                              _buildCompareSound(),
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
                'assets/images/stage1Lesson2.png',
                fit: BoxFit.contain,
                errorBuilder:
                    (_, __, ___) =>
                        const Icon(Icons.image_not_supported, size: 200),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '"Some sounds are short. Some are long."',
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

  Widget _buildEmojiCard({
    required String emoji,
    required String label,
    required String ttsWord,
    required String soundFile,
    required double emojiSize,
    required double fontSize,
    bool slowPlayback = false,
  }) {
    final bool isActiveCard =
        _activeTtsWord == ttsWord || _activeSoundFile == soundFile;
    final bool isM4aActive = _activeSoundFile == soundFile;

    return _AnimatedEmojiCard(
      emoji: emoji,
      label: label,
      soundFile: soundFile,
      emojiSize: emojiSize,
      fontSize: fontSize,
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
            _activeTtsWord = ttsWord;
          });
        }
        await _flutterTts.speak(ttsWord);
      },
    );
  }

  Widget _buildShortVowel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double h = constraints.maxHeight;
        final double emojiSize = (h * 0.30).clamp(48.0, 100.0);
        final double labelSize = (h * 0.07).clamp(14.0, 22.0);
        final double captionSize = (h * 0.055).clamp(13.0, 20.0);

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Center(
                  child: _buildEmojiCard(
                    emoji: '🐱',
                    label: 'Cat',
                    ttsWord: 'Cat',
                    soundFile: 'aSound.m4a',
                    emojiSize: emojiSize,
                    fontSize: labelSize,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '"Short sound."',
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

  Widget _buildLongVowel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double h = constraints.maxHeight;
        final double emojiSize = (h * 0.30).clamp(48.0, 100.0);
        final double labelSize = (h * 0.07).clamp(14.0, 22.0);
        final double captionSize = (h * 0.055).clamp(13.0, 20.0);

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Center(
                  child: _buildEmojiCard(
                    emoji: '🎂',
                    label: 'Cake',
                    ttsWord: 'Cake',
                    soundFile: 'aeVowelTeam.m4a',
                    emojiSize: emojiSize,
                    fontSize: labelSize,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '"Long sound."',
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

  Widget _buildCompareSound() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double h = constraints.maxHeight;
        final double emojiSize = (h * 0.25).clamp(40.0, 80.0);
        final double labelSize = (h * 0.07).clamp(14.0, 22.0);
        final double captionSize = (h * 0.055).clamp(13.0, 20.0);

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: _buildEmojiCard(
                            emoji: '🐱',
                            label: 'Cat',
                            ttsWord: 'Cat',
                            soundFile: 'aSound.m4a',
                            emojiSize: emojiSize,
                            fontSize: labelSize,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: _buildEmojiCard(
                            emoji: '🎂',
                            label: 'Cake',
                            ttsWord: 'Cake',
                            soundFile: 'aeVowelTeam.m4a',
                            emojiSize: emojiSize,
                            fontSize: labelSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '"Listen and compare."',
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

// ─── Standalone animated emoji card widget ───────────────────────────────────
class _AnimatedEmojiCard extends StatefulWidget {
  final String emoji;
  final String label;
  final String soundFile;
  final double emojiSize;
  final double fontSize;
  final bool isSoundPlaying;
  final bool isActiveCard;
  final bool isM4aActive;
  final VoidCallback onTap;

  const _AnimatedEmojiCard({
    required this.emoji,
    required this.label,
    required this.soundFile,
    required this.emojiSize,
    required this.fontSize,
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

  static const Color _baseColor = Color.fromARGB(255, 161, 161, 161);
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
    final opacity = widget.isSoundPlaying && !widget.isActiveCard ? 0.45 : 1.0;

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
                      decoration: BoxDecoration(
                        color: _colorAnimation.value,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: child,
                    ),
                child: Text(
                  widget.emoji,
                  style: TextStyle(fontSize: widget.emojiSize),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: widget.fontSize,
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
