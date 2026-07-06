import 'package:flutter/material.dart';
import 'homeScreen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1200,
      ), // Slightly longer for smoother bounce
    );

    // Slide animation with bounce
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -2.0), // Start from above screen
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.bounceOut));

    // Fade animation for smoother appearance
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _startWelcomeSequence();
  }

  void _startWelcomeSequence() async {
    // Wait 1 second, then show and animate the text
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() {
      _isVisible = true;
    });

    // Start the animation
    await _controller.forward();

    // Wait 2 more seconds after animation completes, then navigate
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      _navigateToMainScreen();
    }
  }

  void _navigateToMainScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder:
            (context, animation, secondaryAnimation) => const HomeScreen(),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFB8500),
      body: Center(
        child:
            _isVisible
                ? FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: const Text(
                      "Talk Right",
                      style: TextStyle(
                        color: Color.fromRGBO(255, 252, 244, 1),
                        fontFamily: "PatrickHandSC",
                        fontSize: 64,
                        fontWeight: FontWeight.w400,
                        height:
                            1.2, // Fixed: Changed from 17/64 to 1.2 for proper text height
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 3),
                            blurRadius: 0,
                            color: Color.fromARGB(255, 0, 0, 0),
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
