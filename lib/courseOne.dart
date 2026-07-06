import 'package:flutter/material.dart';
import 'homeScreen.dart';
import 'courseOneLec1.dart';
import 'courseOneLec2.dart';
import 'courseOneLec3.dart';
import 'courseOneLec4.dart';
import 'courseOneLec5.dart';
import 'courseOneLec6.dart';
import 'progress_manager.dart';
import 'notification_helper.dart';

class CourseOne extends StatefulWidget {
  const CourseOne({super.key});

  @override
  State<CourseOne> createState() => CourseOneState();
}

class CourseOneState extends State<CourseOne> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _tabAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  int _selectedTab = 0;
  bool _isNavigating = false;
  bool _isWhyExpanded = false;
  bool _isLessonUnlocked(int lessonIndex) {
    if (lessonIndex == 0) return true; // first lesson always unlocked
    return _isLessonCompleted(lessonIndex - 1); // unlock when previous is done
  }

  final ProgressManager _progressManager = ProgressManager();

  final Map<int, bool> _previousCompletionStates = {};

  static const String courseId = 'course_one';
  static const int totalLessons = 6;
  static const int tasksPerLesson = 1;
  static const int totalActivities = totalLessons * tasksPerLesson;

  void _showLockedSnackBar() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        backgroundColor: const Color(0xFF577E5F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
        content: Row(
          children: const [
            Icon(Icons.lock, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Complete the previous lesson to unlock this!',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final List<LessonItem> _lessons = [
    LessonItem(
      title: "Introduction to Phonemes",
      imagePath: "assets/images/g1PlayButton.png",
    ),
    LessonItem(
      title: "Short vs. Long Vowel Sounds",
      imagePath: "assets/images/g1PlayButton.png",
    ),
    LessonItem(
      title: "Consonant Sounds",
      imagePath: "assets/images/g1PlayButton.png",
    ),
    LessonItem(
      title: "Blending Simple CVC Words",
      imagePath: "assets/images/g1PlayButton.png",
    ),
    LessonItem(
      title: "Beginning Consonant Blends",
      imagePath: "assets/images/g1PlayButton.png",
    ),
    LessonItem(
      title: "Ending Consonant Blends",
      imagePath: "assets/images/g1PlayButton.png",
    ),
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _tabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tabAnimationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _tabAnimationController.forward();

    _initializePreviousStates();
  }

  void _initializePreviousStates() {
    for (int i = 0; i < totalLessons; i++) {
      _previousCompletionStates[i] = _isLessonCompleted(i);
    }
  }

  void _checkForNewCompletions() {
    for (int i = 0; i < totalLessons; i++) {
      bool wasCompleted = _previousCompletionStates[i] ?? false;
      bool isNowCompleted = _isLessonCompleted(i);

      if (!wasCompleted && isNowCompleted) {
        NotificationHelper.onLessonComplete(courseId, i, _lessons[i].title);
        _previousCompletionStates[i] = true;
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabAnimationController.dispose();
    super.dispose();
  }

  // ── Returns the star asset path based on the lesson's exercise high score ──
  String _getStarImageForLesson(int lessonIndex) {
    final int highScore = _progressManager.getExerciseHighScore(
      courseId,
      lessonIndex,
      'Stage1_Exercise',
    );
    if (highScore >= 4) return 'assets/images/threeStar.png';
    if (highScore >= 3) return 'assets/images/twoStar.png';
    if (highScore >= 2) return 'assets/images/oneStar.png';
    return 'assets/images/zeroStar.png';
  }

  double _calculateOverallProgress() {
    int totalCompleted = _progressManager.getTotalCompletedActivities(courseId);
    return totalActivities > 0 ? totalCompleted / totalActivities : 0.0;
  }

  bool _isLessonCompleted(int lessonIndex) {
    return _progressManager.isLessonFullyCompleted(courseId, lessonIndex);
  }

  int _getTotalCompletedActivities() {
    return _progressManager.getTotalCompletedActivities(courseId);
  }

  String _getLessonProgressString(int lessonIndex) {
    return _progressManager.getProgressString(
      courseId,
      lessonIndex,
      tasksPerLesson,
    );
  }

  void _navigateBack() {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(-1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var slideAnimation = animation.drive(tween);

          var fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
            ),
          );

          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(opacity: fadeAnimation, child: child),
          );
        },
      ),
    );
  }

  void _switchTab(int newTab) async {
    if (newTab != _selectedTab) {
      await _tabAnimationController.reverse();
      setState(() {
        _selectedTab = newTab;
      });
      _tabAnimationController.forward();
    }
  }

  void _navigateToLesson(int lessonIndex) {
    if (_isNavigating) return;
    if (!_isLessonUnlocked(lessonIndex)) {
      _showLockedSnackBar();
      return;
    }
    setState(() => _isNavigating = true);

    Widget targetPage;
    switch (lessonIndex) {
      case 0:
        targetPage = const CourseOneLec1();
        break;
      case 1:
        targetPage = const CourseOneLec2();
        break;
      case 2:
        targetPage = const CourseOneLec3();
        break;
      case 3:
        targetPage = const CourseOneLec4();
        break;
      case 4:
        targetPage = const CourseOneLec5();
        break;
      case 5:
        targetPage = const CourseOneLec6();
        break;
      default:
        targetPage = const Placeholder();
        break;
    }

    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => targetPage,
            transitionDuration: const Duration(milliseconds: 400),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;

              var tween = Tween(
                begin: begin,
                end: end,
              ).chain(CurveTween(curve: curve));
              var slideAnimation = animation.drive(tween);

              var fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
                ),
              );

              return SlideTransition(
                position: slideAnimation,
                child: FadeTransition(opacity: fadeAnimation, child: child),
              );
            },
          ),
        )
        .then((_) {
          _checkForNewCompletions();
          setState(() => _isNavigating = false);
        });
  }

  @override
  Widget build(BuildContext context) {
    double currentProgress = _calculateOverallProgress();
    int progressPercentage = (currentProgress * 100).round();

    return PopScope(
      canPop: !_isNavigating,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _navigateBack();
        }
      },
      child: SlideTransition(
        position: _slideAnimation,
        child: Scaffold(
          backgroundColor: const Color(0xFFB6E8C1),
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── GREEN SECTION ───
                Container(
                  width: double.infinity,
                  color: const Color(0xFFB6E8C1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── HEADER: Back button ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          children: [
                            // ─── Back button with tap animation ───
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

                      // ── BODY: Course title + subtitle + decorative image ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  right: -width * 0.74,
                                  top: -width * 0.27,
                                  child: SizedBox(
                                    width: width * 0.85,
                                    height: width * 0.72,
                                    child: Image.asset(
                                      'assets/images/g1Course.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.3,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              width * 0.2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.rocket_launch,
                                            size: 80,
                                            color: Color(0xFF577E5F),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Listen & Blend',
                                      style: TextStyle(
                                        color: Color(0xFF000000),
                                        fontFamily: 'Fredoka',
                                        fontSize: 26,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 24),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),
                      Container(
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFFCF2),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(22),
                            topRight: Radius.circular(22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── BOTTOM SECTION ───
                Expanded(
                  child: Container(
                    color: const Color(0xFFFFFCF2),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        4 + MediaQuery.of(context).padding.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Learning Progress',
                                style: TextStyle(
                                  color: Color(0xFF000000),
                                  fontFamily: 'Fredoka',
                                  fontSize: 22,
                                  fontStyle: FontStyle.normal,
                                  fontWeight: FontWeight.w500,
                                  height: 17 / 22,
                                ),
                              ),
                              Text(
                                '$progressPercentage%',
                                style: const TextStyle(
                                  color: Color(0xFF577E5F),
                                  fontFamily: 'Fredoka',
                                  fontSize: 16,
                                  fontStyle: FontStyle.normal,
                                  fontWeight: FontWeight.w600,
                                  height: 17 / 22,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          Container(
                            width: double.infinity,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: currentProgress,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF577E5F),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ─── Tab buttons with tap animation ───
                          Row(
                            children: [
                              Expanded(child: _buildImageTabButton(0)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildImageTabButton(1)),
                            ],
                          ),
                          const SizedBox(height: 20),

                          Expanded(
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child:
                                  _selectedTab == 0
                                      ? _buildLessonsContent()
                                      : _buildOverviewContent(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageTabButton(int index) {
    bool isSelected = _selectedTab == index;

    String imagePath;
    if (index == 0) {
      imagePath =
          isSelected
              ? 'assets/images/g1AcademicActiveButton.png'
              : 'assets/images/g1AcademicInactiveButton.png';
    } else {
      imagePath =
          isSelected
              ? 'assets/images/g1OverviewActiveButton.png'
              : 'assets/images/g1OverviewInactiveButton.png';
    }

    return _TapAnimatedButton(
      onTap: () => _switchTab(index),
      child: Container(
        height: 50,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.hardEdge,
        child: Center(
          child: Image.asset(
            imagePath,
            height: 54,
            width: 172,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 50,
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? const Color(0xFF577E5F)
                          : const Color(0xFFB6E8C1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      isSelected
                          ? Border.all(color: const Color(0xFF577E5F), width: 2)
                          : null,
                ),
                child: Center(
                  child: Icon(
                    index == 0 ? Icons.book : Icons.info_outline,
                    size: 30,
                    color: isSelected ? Colors.white : const Color(0xFF577E5F),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLessonsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Column(
        children:
            _lessons.asMap().entries.map((entry) {
              int index = entry.key;
              LessonItem lesson = entry.value;

              String progressString = _getLessonProgressString(index);
              bool isCompleted = _isLessonCompleted(index);
              final String starImage = _getStarImageForLesson(index);

              return _TapAnimatedButton(
                onTap: () => _navigateToLesson(index),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isLessonUnlocked(index) ? 1.0 : 0.5,
                  child: Container(
                    margin: EdgeInsets.only(
                      bottom: index == _lessons.length - 1 ? 0 : 12,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      // ── No green border for completed lessons ──
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Play / Done / Lock icon ──
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Image.asset(
                            !_isLessonUnlocked(index)
                                ? 'assets/images/g1LockButton.png'
                                : _progressManager.getExerciseHighScore(
                                      courseId,
                                      index,
                                      'Stage1_Exercise',
                                    ) >=
                                    3
                                ? 'assets/images/g1DoneButton.png'
                                : lesson.imagePath ??
                                    'assets/images/g1PlayButton.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // ── Title + progress string ──
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lesson.title,
                                style: const TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w400,
                                  height: 1.1,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isLessonUnlocked(index)
                                    ? progressString
                                    : 'Complete previous lesson to unlock',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w300,
                                  color:
                                      _isLessonUnlocked(index)
                                          ? Colors.black87
                                          : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // ── Star image (reflects high score) ──
                        SizedBox(
                          width: 64,
                          height: 32,
                          child: Image.asset(starImage, fit: BoxFit.contain),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildOverviewContent() {
    double overallProgress = _calculateOverallProgress();
    int completedLessons = 0;
    for (int i = 0; i < totalLessons; i++) {
      if (_isLessonCompleted(i)) completedLessons++;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF577E5F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF577E5F).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Completed Lessons',
                  '$completedLessons/$totalLessons',
                ),
                _buildStatItem(
                  'Total Activities',
                  '${_getTotalCompletedActivities()}/$totalActivities',
                ),
                _buildStatItem(
                  'Overall Progress',
                  '${(overallProgress * 100).round()}%',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildOverviewSectionHeader('What learners will gain'),
          const SizedBox(height: 10),
          const Text(
            'Stage 1 builds the foundation for reading.',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: Color(0xFF1D1D1D),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Learners will:',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 17,
              fontWeight: FontWeight.w300,
              color: Color(0xFF1D1D1D),
            ),
          ),
          const SizedBox(height: 4),
          _buildBullet('Hear and recognize basic sounds'),
          _buildBullet('Understand how letters connect to sounds'),
          _buildBullet('Blend sounds to read simple words'),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFDDDDDD)),
          const SizedBox(height: 16),

          _buildOverviewSectionHeader('Skills covered in this stage'),
          const SizedBox(height: 14),

          _buildSkillGroup('Phoneme Awareness', [
            'Vowel and consonant sounds',
            'Short and long vowels',
          ]),
          const SizedBox(height: 14),
          _buildSkillGroup('Sound Patterns', [
            'Different consonant sounds',
            'Beginning and ending blends',
          ]),
          const SizedBox(height: 14),
          _buildSkillGroup('Early Reading', [
            'Blending simple CVC words',
            'Building reading confidence',
          ]),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFDDDDDD)),
          const SizedBox(height: 16),

          // ─── "Why this matters" toggle with tap animation ───
          _TapAnimatedButton(
            onTap: () => setState(() => _isWhyExpanded = !_isWhyExpanded),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _isWhyExpanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF577E5F),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Why this stage matters',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF000000),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Expanded Academic Explanation',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF577E5F),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Stage 1 is the foundational level of phonics and reading, designed to help young learners build a strong understanding of basic sounds, letter combinations, and how to blend them to form simple words. This stage focuses on developing phonemic awareness—the ability to recognize and manipulate sounds in spoken and written language—which is essential for early reading and writing development. Mastery of these skills prepares learners for reading fluency and comprehension in later stages.',
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 17,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF1D1D1D),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState:
                _isWhyExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOverviewSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: Color(0xFF577E5F),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF000000),
          ),
        ),
      ],
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontSize: 16, color: Color(0xFF1D1D1D)),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 17,
                fontWeight: FontWeight.w300,
                color: Color(0xFF1D1D1D),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillGroup(String groupTitle, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          groupTitle,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1D1D1D),
          ),
        ),
        const SizedBox(height: 4),
        ...items.map((item) => _buildBullet(item)),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF577E5F),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1D1D1D),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewSection(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          textAlign: TextAlign.justify,
          title,
          style: const TextStyle(
            color: Color(0xFF000000),
            fontFamily: 'Fredoka',
            fontSize: 20,
            fontWeight: FontWeight.w400,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          textAlign: TextAlign.justify,
          description,
          style: const TextStyle(
            color: Color(0xFF1D1D1D),
            fontFamily: 'Fredoka',
            fontSize: 18,
            fontWeight: FontWeight.w300,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class LessonItem {
  final String title;
  final String? imagePath;

  LessonItem({
    required this.title,
    this.imagePath = "assets/images/g1PlayButton.png",
  });
}

// ─── Reusable tap-bounce button wrapper ─────────────────────────────────────
/// Wraps any widget with a bounce animation on tap.
/// Shrinks → overshoots → settles back to normal scale.
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
    // Shrink → overshoot → settle
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
    // Play bounce, then fire the callback once animation completes
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
