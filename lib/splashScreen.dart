import 'package:flutter/material.dart';
import 'onboardingScreen.dart';
import 'homeScreen.dart';
import 'settings_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _exitController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _entryFadeAnimation;
  late Animation<double> _exitFadeAnimation;

  bool _showContent = false;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startSplashSequence();
  }

  void _initializeAnimations() {
    // Entry animations
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Exit animation controller
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -2.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.bounceOut),
    );

    _entryFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Exit fade animation
    _exitFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeOut));
  }

  void _startSplashSequence() async {
    // Initial delay
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // Show and animate entry
    setState(() => _showContent = true);
    await _entryController.forward();

    // Display time
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // Start exit animation and navigate
    _navigateWithFadeOut();
  }

  void _navigateWithFadeOut() async {
    setState(() => _isExiting = true);

    // Start exit animation
    await _exitController.forward();

    if (mounted) {
      // Check if onboarding is enabled
      final shouldShowOnboarding = SettingsManager.onboardingEnabled;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder:
              (context, animation, secondaryAnimation) =>
                  shouldShowOnboarding
                      ? const OnboardingScreen()
                      : const HomeScreen(),
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

  @override
  void dispose() {
    _entryController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(255, 252, 244, 1),
      body: Center(
        child:
            _showContent
                ? FadeTransition(
                  opacity:
                      _isExiting ? _exitFadeAnimation : _entryFadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: const Text(
                      "Talk Right",
                      style: TextStyle(
                        color: Color(0xFFFB8500),
                        fontFamily: "PatrickHandSC",
                        fontSize: 64,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 3),
                            blurRadius: 0,
                            color: Color(0xFF8D4D05),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                : const SizedBox.shrink(),
      ),
    );
  }
}
