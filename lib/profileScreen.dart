import 'package:flutter/material.dart';
import 'progress_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isAchievementsActive = true;
  final ProgressManager _progressManager = ProgressManager();

  static const int totalLessonsPerCourse = 6;
  static const int tasksPerLesson = 1;
  static const int totalActivitiesPerCourse =
      totalLessonsPerCourse * tasksPerLesson;
  static const int totalCourses = 3;
  static const int totalActivities = totalActivitiesPerCourse * totalCourses;

  // ─── Progress ───

  double _calculateOverallProgress() {
    int totalCompleted = 0;
    totalCompleted += _progressManager.getTotalCompletedActivities(
      'course_one',
    );
    totalCompleted += _progressManager.getTotalCompletedActivities(
      'course_two',
    );
    totalCompleted += _progressManager.getTotalCompletedActivities(
      'course_three',
    );
    return totalActivities > 0 ? totalCompleted / totalActivities : 0.0;
  }

  // ─── Star Collector Helper ───

  int _getTotalStars() {
    int total = 0;
    const courses = ['course_one', 'course_two', 'course_three'];
    const exerciseKeys = [
      'Stage1_Exercise',
      'Stage2_Exercise',
      'Stage3_Exercise',
    ];
    for (int c = 0; c < courses.length; c++) {
      for (int i = 0; i < totalLessonsPerCourse; i++) {
        final score = _progressManager.getExerciseHighScore(
          courses[c],
          i,
          exerciseKeys[c],
        );
        if (score >= 4) {
          total += 3;
        } else if (score >= 3) {
          total += 2;
        } else if (score >= 2) {
          total += 1;
        }
      }
    }
    return total;
  }

  // ─── Achievements ───

  bool _checkAchievement(String achievementId) {
    switch (achievementId) {
      case 'first_step':
        return _progressManager.isLessonFullyCompleted('course_one', 0);

      case 'stage_1_complete':
        for (int i = 0; i < totalLessonsPerCourse; i++) {
          if (!_progressManager.isLessonFullyCompleted('course_one', i))
            return false;
        }
        return true;

      case 'stage_2_complete':
        for (int i = 0; i < totalLessonsPerCourse; i++) {
          if (!_progressManager.isLessonFullyCompleted('course_two', i))
            return false;
        }
        return true;

      case 'stage_3_complete':
        for (int i = 0; i < totalLessonsPerCourse; i++) {
          if (!_progressManager.isLessonFullyCompleted('course_three', i))
            return false;
        }
        return true;

      case 'guided_master':
        for (int i = 0; i < totalLessonsPerCourse; i++) {
          if (!_progressManager.isLessonFullyCompleted('course_one', i) ||
              !_progressManager.isLessonFullyCompleted('course_two', i) ||
              !_progressManager.isLessonFullyCompleted('course_three', i))
            return false;
        }
        return true;

      case 'learning_journey':
        return _checkAchievement('guided_master');

      case 'star_collector':
        return _getTotalStars() >= 54;

      default:
        return false;
    }
  }

  String _getAchievementProgress(String achievementId) {
    switch (achievementId) {
      case 'first_step':
        final done =
            _progressManager.isLessonFullyCompleted('course_one', 0) ? 1 : 0;
        return '$done/1';

      case 'stage_1_complete':
        int done = 0;
        for (int i = 0; i < totalLessonsPerCourse; i++) {
          if (_progressManager.isLessonFullyCompleted('course_one', i)) done++;
        }
        return '$done/$totalLessonsPerCourse';

      case 'stage_2_complete':
        int done = 0;
        for (int i = 0; i < totalLessonsPerCourse; i++) {
          if (_progressManager.isLessonFullyCompleted('course_two', i)) done++;
        }
        return '$done/$totalLessonsPerCourse';

      case 'stage_3_complete':
        int done = 0;
        for (int i = 0; i < totalLessonsPerCourse; i++) {
          if (_progressManager.isLessonFullyCompleted('course_three', i))
            done++;
        }
        return '$done/$totalLessonsPerCourse';

      case 'guided_master':
      case 'learning_journey':
        int done =
            _progressManager.getTotalCompletedActivities('course_one') +
            _progressManager.getTotalCompletedActivities('course_two') +
            _progressManager.getTotalCompletedActivities('course_three');
        return '$done/$totalActivities';

      case 'star_collector':
        return '${_getTotalStars()}/54';

      default:
        return '0/1';
    }
  }

  // ─── Badges ───

  bool _isMetaBadgeUnlocked(int badgeIndex) {
    switch (badgeIndex) {
      case 0:
        return _checkAchievement('stage_1_complete') &&
            _checkAchievement('stage_2_complete') &&
            _checkAchievement('stage_3_complete');

      case 1:
        return _checkAchievement('first_step') &&
            _checkAchievement('stage_1_complete') &&
            _checkAchievement('stage_2_complete') &&
            _checkAchievement('stage_3_complete') &&
            _checkAchievement('guided_master');

      case 2:
        return _checkAchievement('first_step') &&
            _checkAchievement('stage_1_complete') &&
            _checkAchievement('stage_2_complete') &&
            _checkAchievement('stage_3_complete') &&
            _checkAchievement('guided_master') &&
            _checkAchievement('learning_journey');

      default:
        return false;
    }
  }

  Map<String, String> _getBadgeInfo(int badgeIndex) {
    switch (badgeIndex) {
      case 0:
        return {
          'title': 'Stage Master Badge',
          'description':
              'You conquered every course and proved your growing power in pronunciation!',
          'requirements':
              '• Unlock Course 1 Explorer\n• Unlock Course 2 Achiever\n• Unlock Course 3 Master',
        };
      case 1:
        return {
          'title': 'Pronunciation Legend Badge',
          'description':
              'Your voice journey is complete — you\'ve mastered every lesson from start to finish like a true legend!',
          'requirements':
              '• Unlock First Step\n• Unlock Course 1 Explorer\n• Unlock Course 2 Achiever\n• Unlock Course 3 Master\n• Unlock Guided Master',
        };
      case 2:
        return {
          'title': 'Grand Master Badge',
          'description':
              'The ultimate title! You completed every challenge and unlocked the entire learning adventure. True mastery achieved!',
          'requirements':
              '• Unlock First Step\n• Unlock Course 1 Explorer\n• Unlock Course 2 Achiever\n• Unlock Course 3 Master\n• Unlock Guided Master\n• Unlock Learning Journey',
        };
      default:
        return {
          'title': 'Unknown Badge',
          'description': 'No description available',
          'requirements': 'No requirements',
        };
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final double overallProgress = _calculateOverallProgress();
    final int progressPercentage = (overallProgress * 100).round();

    return Column(
      children: [
        _buildHeader(overallProgress, progressPercentage),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child:
                isAchievementsActive
                    ? _buildAchievementsContent()
                    : _buildBadgesContent(),
          ),
        ),
      ],
    );
  }

  // ─── Header ───

  Widget _buildHeader(double overallProgress, int progressPercentage) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFFB8500),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Profile picture
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/studentProfile.png',
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      color: Colors.lightBlue,
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Juan Dela Cruz',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Fredoka',
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            'Bossing',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontFamily: 'Fredoka',
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: overallProgress,
                    minHeight: 10,
                    backgroundColor: Colors.white.withOpacity(0.35),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Overall Progress',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      '$progressPercentage%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── Tab buttons ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    label: 'Achievements',
                    isActive: isAchievementsActive,
                    onTap: () => setState(() => isAchievementsActive = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTabButton(
                    label: 'Badges',
                    isActive: !isAchievementsActive,
                    onTap: () => setState(() => isAchievementsActive = false),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return _TapAnimatedButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFFFB8500) : Colors.white,
            fontFamily: 'Fredoka',
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ─── Achievements ───

  Widget _buildAchievementsContent() {
    const achievements = [
      {
        'id': 'first_step',
        'title': 'First Step',
        'description': 'Complete your first lesson.',
      },
      {
        'id': 'stage_1_complete',
        'title': 'Course 1 Explorer',
        'description': 'Complete all Course 1 lessons.',
      },
      {
        'id': 'stage_2_complete',
        'title': 'Course 2 Achiever',
        'description': 'Complete all Course 2 lessons.',
      },
      {
        'id': 'stage_3_complete',
        'title': 'Course 3 Master',
        'description': 'Complete all Course 3 lessons.',
      },
      {
        'id': 'guided_master',
        'title': 'Guided Master',
        'description': 'Complete all lessons across all Courses.',
      },
      {
        'id': 'learning_journey',
        'title': 'Learning Journey',
        'description': 'Finish the entire learning path.',
      },
      {
        'id': 'star_collector',
        'title': 'Star Collector',
        'description':
            'Earn all 54 stars by achieving top scores across every lesson in all 3 courses.',
      },
    ];

    return Column(
      children:
          achievements
              .map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildAchievementItem(
                    achievementId: a['id']!,
                    title: a['title']!,
                    description: a['description']!,
                    imagePath: 'assets/images/achievementBadge.png',
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildAchievementItem({
    required String achievementId,
    required String title,
    required String description,
    required String imagePath,
  }) {
    final bool isCompleted = _checkAchievement(achievementId);
    final String progress = _getAchievementProgress(achievementId);
    final List<String> parts = progress.split('/');
    final double progressValue =
        parts.length == 2 ? int.parse(parts[0]) / int.parse(parts[1]) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color:
                  isCompleted
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFF0F0F0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                isCompleted ? imagePath : 'assets/images/badgeLock.png',
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Icon(
                      isCompleted ? Icons.emoji_events : Icons.lock,
                      color:
                          isCompleted
                              ? const Color(0xFFFB8500)
                              : Colors.grey[500],
                      size: 34,
                    ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontFamily: 'Fredoka',
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontFamily: 'Fredoka',
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFB8500),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    progress,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.4),
                      fontFamily: 'Fredoka',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Badges ───

  Widget _buildBadgesContent() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (i) => _buildMetaBadge(i)),
      ),
    );
  }

  Widget _buildMetaBadge(int badgeIndex) {
    final bool isUnlocked = _isMetaBadgeUnlocked(badgeIndex);

    return _TapAnimatedButton(
      onTap: () => _showBadgeDialog(badgeIndex),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color:
                  isUnlocked
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFF0F0F0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                isUnlocked
                    ? 'assets/images/achievementBadge.png'
                    : 'assets/images/badgeLock.png',
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Icon(
                      isUnlocked ? Icons.emoji_events : Icons.lock,
                      size: 36,
                      color:
                          isUnlocked
                              ? const Color(0xFFFB8500)
                              : Colors.grey[500],
                    ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            child: Text(
              _getBadgeInfo(badgeIndex)['title']!.split(' ').first,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withOpacity(0.55),
                fontFamily: 'Fredoka',
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBadgeDialog(int badgeIndex) {
    final badgeInfo = _getBadgeInfo(badgeIndex);
    final bool isUnlocked = _isMetaBadgeUnlocked(badgeIndex);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  badgeInfo['title']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      isUnlocked
                          ? 'assets/images/achievementBadge.png'
                          : 'assets/images/badgeLock.png',
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              color:
                                  isUnlocked
                                      ? const Color(0xFFFB8500)
                                      : Colors.grey[400],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              isUnlocked ? Icons.emoji_events : Icons.lock,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  badgeInfo['description']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Requirements:\n${badgeInfo['requirements']}',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      color: Colors.black54,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _TapAnimatedButton(
                    onTap: () => Navigator.of(context).pop(),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/close1Button.png',
                        fit: BoxFit.cover,
                        height: 56,
                        errorBuilder:
                            (_, __, ___) => Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFB8500),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
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
        );
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
