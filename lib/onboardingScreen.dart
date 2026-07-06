import 'dart:async';
import 'package:flutter/material.dart';
import 'welcomeScreen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ── Hint state ─────────────────────────────────────────────────────────────
  bool _hintPending = true;
  bool _isDragging = false;

  late AnimationController _hintVisibilityController;
  late AnimationController _swipeController;

  Timer? _showTimer;

  // ── Tap bounce for the action button ──────────────────────────────────────
  late AnimationController _tapBounceController;
  late Animation<double> _tapBounceScale;

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

  void _startHint() {
    _showTimer?.cancel();
    final isLastPage = _currentPage == onboardingData.length - 1;

    // On the last page we show the tap-bounce on the button instead of the
    // overlay hint, so just trigger that and return early.
    if (isLastPage) {
      _showTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) _playButtonBounce();
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

  void _playButtonBounce() {
    if (!mounted) return;
    _tapBounceController.forward(from: 0);
  }

  void _updateSwipeDuration() {
    if (_currentPage == 0) {
      _swipeController.duration = const Duration(milliseconds: 2200);
    } else {
      _swipeController.duration = const Duration(milliseconds: 4500);
    }
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
  // ──────────────────────────────────────────────────────────────────────────

  late final AnimationController _exitController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  late final AnimationController _buttonController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  late final Animation<double> _exitFadeAnimation = Tween<double>(
    begin: 1.0,
    end: 0.0,
  ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeOut));

  late final Animation<double> _buttonWidthAnimation = Tween<double>(
    begin: 54.0,
    end: 131.0,
  ).animate(
    CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
  );

  late final Animation<double> _buttonScaleAnimation = Tween<double>(
    begin: 1.0,
    end: 0.95,
  ).animate(
    CurvedAnimation(
      parent: _buttonController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    ),
  );

  late final Animation<double> _buttonExpandAnimation = Tween<double>(
    begin: 0.95,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _buttonController,
      curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
    ),
  );

  bool _isExiting = false;

  final List<Map<String, dynamic>> onboardingImages = [
    {
      "path": 'assets/images/onboardingOne.png',
      "width": 329.0,
      "height": 323.0,
      "top": 20.0,
      "left": 12.0,
    },
    {
      "path": 'assets/images/onboardingTwo.png',
      "width": 329.0,
      "height": 329.0,
      "top": 20.0,
      "left": 80.0,
    },
    {
      "path": 'assets/images/onboardingThree.png',
      "width": 338.0,
      "height": 338.0,
      "top": 18.0,
      "left": 16.0,
    },
    {
      "path": 'assets/images/onboardingFour.png',
      "width": 304.0,
      "height": 301.0,
      "top": 38.0,
      "left": 100.0,
    },
    {
      "path": 'assets/images/onboardingFive.png',
      "width": 274.0,
      "height": 314.0,
      "top": 34.0,
      "left": 98.0,
    },
  ];

  final List<Map<String, String>> onboardingData = [
    {
      "title": "Listen First. Speak Better.",
      "description":
          "Learn English pronunciation through guided listening, sound awareness, and sentence flow.",
    },
    {
      "title": "Learn with Guidance",
      "description":
          "Follow step-by-step lessons that help you hear sounds, words, and sentences clearly before speaking.",
    },
    {
      "title": "Practice Without Pressure",
      "description":
          "Optional speaking practice helps build confidence. You can retry anytime—no penalties.",
    },
    {
      "title": "Track Real Progress",
      "description":
          "Unlock assessments after learning each course. Pass to move forward and show mastery.",
    },
    {
      "title": "Earn as You Learn",
      "description":
          "Complete lessons, unlock achievements, and earn badges as your skills grow.",
    },
  ];

  @override
  void initState() {
    super.initState();
    _initHintControllers();

    // ── Tap bounce animation (same sequence as HomeScreen's _TapAnimatedButton)
    _tapBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _tapBounceScale = TweenSequence<double>([
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
    ]).animate(_tapBounceController);

    _buttonController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startHint());
  }

  void _goToNextPage() {
    if (_currentPage < onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToWelcomeWithFadeOut();
    }
  }

  /// Fires the tap-bounce then navigates — same pattern as HomeScreen.
  void _handleActionButtonTap() {
    _tapBounceController.forward(from: 0).then((_) => _goToNextPage());
  }

  void _navigateToWelcomeWithFadeOut() async {
    setState(() => _isExiting = true);
    await _exitController.forward();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          pageBuilder:
              (context, animation, secondaryAnimation) => const WelcomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
        ),
      );
    }
  }

  void _goToFirstPage() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // ── Swipe hint widget ──────────────────────────────────────────────────────
  // NOTE: Last page no longer uses an overlay hint — the button itself bounces.
  Widget _buildSwipeHint(double areaWidth, double areaHeight) {
    final isLastPage = _currentPage == onboardingData.length - 1;

    // On the last page, return an empty widget — the button bounce handles it.
    if (isLastPage) return const SizedBox.shrink();

    const circleD = 36.0;
    const circleR = circleD / 2;
    final centerX = areaWidth / 2 - circleR;
    final rightEdge = areaWidth - circleD - 16.0;
    final leftEdge = 16.0;
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
                              color: const Color(0xFFFB8500).withOpacity(0.45),
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

  Widget _buildActionButton() {
    final isLastPage = _currentPage == onboardingData.length - 1;

    if (isLastPage && _buttonController.status != AnimationStatus.completed) {
      _buttonController.forward();
    } else if (!isLastPage &&
        _buttonController.status != AnimationStatus.dismissed) {
      _buttonController.reverse();
    }

    return GestureDetector(
      onTap: _handleActionButtonTap, // ← uses bounce-then-navigate
      child: AnimatedBuilder(
        // Listen to both the expand/collapse controller AND the bounce controller
        animation: Listenable.merge([_buttonController, _tapBounceController]),
        builder: (context, child) {
          final currentWidth = _buttonWidthAnimation.value;

          // Combine the expand animation scale with the tap-bounce scale.
          final expandScale =
              _buttonController.isAnimating
                  ? (_buttonController.value < 0.3
                      ? _buttonScaleAnimation.value
                      : _buttonExpandAnimation.value)
                  : 1.0;
          final combinedScale = expandScale * _tapBounceScale.value;

          return Transform.scale(
            scale: combinedScale,
            child: SizedBox(
              width: currentWidth,
              height: 54,
              child: Container(
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  transitionBuilder: (
                    Widget child,
                    Animation<double> animation,
                  ) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.3, 0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child:
                      isLastPage
                          ? Container(
                            key: const ValueKey('getStarted'),
                            width: 131,
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
                              'assets/images/startLearning.png',
                              fit: BoxFit.cover,
                            ),
                          )
                          : Container(
                            key: const ValueKey('next'),
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
                            child: Image.asset(
                              'assets/images/nextButton.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFirstPage = _currentPage == 0;
    final isLastPage = _currentPage == onboardingData.length - 1;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(255, 252, 244, 1),
      body: FadeTransition(
        opacity:
            _isExiting ? _exitFadeAnimation : const AlwaysStoppedAnimation(1.0),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    // Circles + image
                    SizedBox(
                      height: 380,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: 33.5,
                              left: (390 - 313) / 2,
                              child: Container(
                                width: 313,
                                height: 313,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color.fromRGBO(254, 228, 194, 1),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 71,
                              left: (390 - 238) / 2,
                              child: Container(
                                width: 238,
                                height: 238,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color.fromRGBO(251, 133, 0, 1),
                                ),
                              ),
                            ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                              top: onboardingImages[_currentPage]["top"],
                              left: onboardingImages[_currentPage]["left"],
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeIn,
                                switchOutCurve: Curves.easeOut,
                                transitionBuilder: (
                                  Widget child,
                                  Animation<double> animation,
                                ) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(
                                        begin: 0.9,
                                        end: 1.0,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeInOut,
                                        ),
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Image.asset(
                                  onboardingImages[_currentPage]["path"],
                                  key: ValueKey<int>(_currentPage),
                                  width:
                                      onboardingImages[_currentPage]["width"],
                                  height:
                                      onboardingImages[_currentPage]["height"],
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Page indicator dots
                    Padding(
                      padding: const EdgeInsets.only(top: 70),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          onboardingData.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: _currentPage == index ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color:
                                  _currentPage == index
                                      ? const Color(0xFFFB8500)
                                      : const Color.fromRGBO(159, 159, 159, 1),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // PageView + hint overlay
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final h = constraints.maxHeight;
                          return Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              GestureDetector(
                                onHorizontalDragStart: (_) => _onDragStart(),
                                onHorizontalDragEnd: (_) => _onDragEnd(),
                                onHorizontalDragCancel: _onDragEnd,
                                onLongPressStart: (_) => _onDragStart(),
                                onLongPressEnd: (_) => _onDragEnd(),
                                onLongPressCancel: _onDragEnd,
                                behavior: HitTestBehavior.translucent,
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: onboardingData.length,
                                  onPageChanged: (index) {
                                    _resetHintControllers();
                                    setState(() {
                                      _currentPage = index;
                                      _hintPending = true;
                                    });
                                    _startHint();
                                  },
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        40,
                                        20,
                                        40,
                                        0,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 20,
                                            ),
                                            child: Text(
                                              onboardingData[index]["title"]!,
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontFamily: "Fredoka",
                                                fontSize: 22,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            onboardingData[index]["description"]!,
                                            style: const TextStyle(
                                              color: Color(0xFF1D1D1D),
                                              fontFamily: 'Fredoka',
                                              fontSize: 18,
                                              fontWeight: FontWeight.w300,
                                              height: 1.4,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                              KeyedSubtree(
                                key: ValueKey<int>(_currentPage),
                                child: _buildSwipeHint(w, h),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom nav bar
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  20 + MediaQuery.of(context).padding.bottom,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isFirstPage)
                      const SizedBox(width: 80)
                    else if (isLastPage)
                      TextButton(
                        onPressed: _goToFirstPage,
                        child: const Text(
                          'Back',
                          style: TextStyle(
                            color: Color(0xFFFB8500),
                            fontFamily: 'Fredoka',
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: () {
                          _pageController.animateToPage(
                            onboardingData.length - 1,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: Color(0xFFFB8500),
                            fontFamily: 'Fredoka',
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),

                    _buildActionButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _pageController.dispose();
    _exitController.dispose();
    _buttonController.dispose();
    _swipeController.dispose();
    _hintVisibilityController.dispose();
    _tapBounceController.dispose();
    super.dispose();
  }
}

// ── Glowing circle ─────────────────────────────────────────────────────────────
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
        color: const Color(0xFFFB8500),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFB8500).withOpacity(0.90),
            blurRadius: 6,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xFFFB8500).withOpacity(0.50),
            blurRadius: 14,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: const Color(0xFFFB8500).withOpacity(0.22),
            blurRadius: 28,
            spreadRadius: 8,
          ),
        ],
      ),
    );
  }
}

// ── Painters (unchanged) ───────────────────────────────────────────────────────
class ChevronButtonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );
    final outerShadowPath = Path()..addRRect(rect);
    canvas.drawShadow(
      outerShadowPath,
      Colors.black.withOpacity(0.15),
      15.0,
      true,
    );
    paint.color = const Color(0xFFFB8500);
    canvas.drawRRect(rect, paint);
    paint.shader = RadialGradient(
      center: const Alignment(-0.7, -0.7),
      radius: 1.5,
      colors: [const Color.fromRGBO(65, 49, 32, 0.35), const Color(0xFFFB8500)],
      stops: const [0.0, 0.8],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(rect, paint);
    paint.shader = RadialGradient(
      center: const Alignment(0.7, 0.7),
      radius: 1.2,
      colors: [
        const Color.fromRGBO(254, 195, 129, 0.35),
        const Color(0xFFFB8500),
      ],
      stops: const [0.0, 0.6],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(rect, paint);
    paint.shader = null;
    paint.color = Colors.white;
    paint.strokeWidth = 2.5;
    paint.strokeCap = StrokeCap.round;
    paint.style = PaintingStyle.stroke;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    const double iconSize = 7.0;
    final chevronPath = Path();
    chevronPath.moveTo(centerX - iconSize * 0.5, centerY - iconSize);
    chevronPath.lineTo(centerX + iconSize * 0.5, centerY);
    chevronPath.lineTo(centerX - iconSize * 0.5, centerY + iconSize);
    canvas.drawPath(chevronPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GetStartedButtonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );
    final outerShadowPath = Path()..addRRect(rect);
    canvas.drawShadow(
      outerShadowPath,
      Colors.black.withOpacity(0.15),
      15.0,
      true,
    );
    paint.color = const Color(0xFFFB8500);
    canvas.drawRRect(rect, paint);
    paint.shader = RadialGradient(
      center: const Alignment(-0.7, -0.7),
      radius: 1.5,
      colors: [const Color.fromRGBO(65, 49, 32, 0.35), const Color(0xFFFB8500)],
      stops: const [0.0, 0.8],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(rect, paint);
    paint.shader = RadialGradient(
      center: const Alignment(0.7, 0.7),
      radius: 1.2,
      colors: [
        const Color.fromRGBO(254, 195, 129, 0.35),
        const Color(0xFFFB8500),
      ],
      stops: const [0.0, 0.6],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
