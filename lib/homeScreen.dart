import 'package:flutter/material.dart';
import 'courseOne.dart';
import 'courseTwo.dart';
import 'courseThree.dart';
import 'assessmentScreen.dart';
import 'profileScreen.dart';
import 'settingsScreen.dart';
import 'aboutScreen.dart';
import 'notificationScreen.dart';
import 'notification_manager.dart';
import 'notification_helper.dart';
import 'progress_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final NotificationManager _notificationManager = NotificationManager();

  @override
  void initState() {
    super.initState();
    // ── Run retroactive achievement checks (including Star Collector)
    //    every time HomeScreen is loaded so already-earned progress
    //    is always evaluated.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationHelper.runRetroactiveCheck();
      setState(() {}); // refresh notification badge if new ones were added
    });
  }

  bool _isCourseUnlocked(String title) {
    final pm = ProgressManager();
    switch (title) {
      case 'Basic Sound & Blending':
        return true; // always unlocked
      case 'Word Formation':
        // unlock when all course_one lessons complete
        for (int i = 0; i < 6; i++) {
          if (!pm.isLessonFullyCompleted('course_one', i)) return false;
        }
        return true;
      case 'Sentence, Phrases & Comprehension':
        // unlock when all course_two lessons complete
        for (int i = 0; i < 6; i++) {
          if (!pm.isLessonFullyCompleted('course_two', i)) return false;
        }
        return true;
      default:
        return false;
    }
  }

  void _showCourseLockedSnackBar(String title) {
    String message;
    if (title == 'Word Formation') {
      message = 'Complete Basic Sound & Blending to unlock this!';
    } else {
      message = 'Complete Word Formation to unlock this!';
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        backgroundColor: const Color(0xFFFB8500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.lock, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isCourseUnlocked(title) ? 'Start' : 'Locked 🔒',
                style: const TextStyle(
                  color: Color(0xFFFFFCF2),
                  fontFamily: 'Fredoka',
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const AssessmentScreen();
      case 2:
        return const ProfileScreen();
      case 3:
        return const SettingsScreen();
      case 4:
        return const AboutScreen();
      default:
        return _buildHomeContent();
    }
  }

  void _openNotifications() {
    showDialog(
      context: context,
      builder: (context) => const NotificationScreen(),
    ).then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(255, 252, 244, 1),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── 1. HEADER: shown only on home tab ───
            if (_selectedIndex == 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Learning Path!',
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'Fredoka',
                        fontSize: 26,
                        fontStyle: FontStyle.normal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // ─── Notification button with tap animation ───
                    _TapAnimatedButton(
                      onTap: _openNotifications,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFB8500),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          if (_notificationManager.hasUnreadNotifications)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color.fromRGBO(
                                      255,
                                      252,
                                      244,
                                      1,
                                    ),
                                    width: 2,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                child: Center(
                                  child: Text(
                                    _notificationManager.unreadCount > 9
                                        ? '9+'
                                        : '${_notificationManager.unreadCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Fredoka',
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

            // ─── 2. BODY ───
            Expanded(child: _getCurrentScreen()),

            // ─── 3. BOTTOM NAV ───
            Container(
              height: 70 + MediaQuery.of(context).padding.bottom,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomNavItem(Icons.home, 0),
                  _buildBottomNavItem(Icons.grid_view, 1),
                  _buildBottomNavItem(Icons.person, 2),
                  _buildBottomNavItem(Icons.settings, 3),
                  _buildBottomNavItem(Icons.info, 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Home tab body ───

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _buildLearningCard(
            title: 'Basic Sound & Blending',
            description:
                "Make letters pop and zip! Let's blend sounds to build words.",
            imagePath: 'assets/images/course1.png',
          ),
          const SizedBox(height: 16),
          _buildLearningCard(
            title: 'Word Formation',
            description: "Mix sounds! Make bigger, cooler words. Abracadabra!",
            imagePath: 'assets/images/course2.png',
            placeholderColor: const Color.fromRGBO(182, 218, 232, 1),
          ),
          const SizedBox(height: 16),
          _buildLearningCard(
            title: 'Sentence, Phrases & Comprehension',
            description:
                "Build word trains! Make stories come alive. Choo-choo!",
            imagePath: 'assets/images/course3.png',
            placeholderColor: const Color.fromRGBO(232, 182, 183, 1),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLearningCard({
    required String title,
    required String description,
    required String imagePath,
    Color? placeholderColor,
  }) {
    final bool unlocked = _isCourseUnlocked(title);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: unlocked ? 1.0 : 0.6,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Character image
            Container(
              width: 118,
              height: 200,
              decoration: BoxDecoration(
                color: placeholderColor ?? const Color(0xFFB6E8C1),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(-1, -1),
                    blurRadius: 6,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(1, 1),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: placeholderColor ?? const Color(0xFFB6E8C1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.image, size: 40),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Title + description + start button
            Expanded(
              child: SizedBox(
                height: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.black,
                            fontFamily: 'Fredoka',
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontFamily: 'Fredoka',
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: _TapAnimatedButton(
                        onTap: () {
                          if (!_isCourseUnlocked(title)) {
                            _showCourseLockedSnackBar(title);
                            return;
                          }
                          if (title == 'Basic Sound & Blending') {
                            Navigator.of(
                              context,
                            ).push(_createRouteToCourseOne());
                          } else if (title == 'Word Formation') {
                            Navigator.of(
                              context,
                            ).push(_createRouteToCourseTwo());
                          } else if (title ==
                              'Sentence, Phrases & Comprehension') {
                            Navigator.of(
                              context,
                            ).push(_createRouteToCourseThree());
                          }
                        },
                        child: Container(
                          width: 110,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFB8500),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                offset: const Offset(-1, -1),
                                blurRadius: 6,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                offset: const Offset(1, 1),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Text(
                            'Start',
                            style: TextStyle(
                              color: Color(0xFFFFFCF2),
                              fontFamily: 'Fredoka',
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom nav ───

  Widget _buildBottomNavItem(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    return _TapAnimatedButton(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          size: 28,
          color: isSelected ? const Color(0xFFFFB703) : const Color(0xFFBFBFBF),
        ),
      ),
    );
  }

  // ─── Route transitions ───

  Route _createRouteToCourseOne() {
    return PageRouteBuilder(
      pageBuilder:
          (context, animation, secondaryAnimation) => const CourseOne(),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  Route _createRouteToCourseTwo() {
    return PageRouteBuilder(
      pageBuilder:
          (context, animation, secondaryAnimation) => const CourseTwo(),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  Route _createRouteToCourseThree() {
    return PageRouteBuilder(
      pageBuilder:
          (context, animation, secondaryAnimation) => const CourseThree(),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }
}

// ─── Reusable tap-bounce button wrapper ─────────────────────────────────────
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
