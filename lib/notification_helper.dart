// notification_helper.dart
import 'notification_manager.dart';
import 'progress_manager.dart';

class NotificationHelper {
  static final NotificationManager _notificationManager = NotificationManager();
  static final ProgressManager _progressManager = ProgressManager();

  static const int _totalLessonsPerCourse = 6;

  /// Call this when a lesson is completed.
  static void onLessonComplete(
    String courseId,
    int lessonIndex,
    String lessonName,
  ) {
    _notificationManager.addLessonCompleteNotification(courseId, lessonName);
    checkAchievements(courseId, lessonIndex);
    checkCourseUnlocks(courseId);
  }

  static void runRetroactiveCheck() {
    final Map<String, List<String>> lessons = {
      'course_one': [
        'Introduction to Phonemes',
        'Short vs. Long Vowel Sounds',
        'Consonant Sounds',
        'Blending Simple CVC Words',
        'Beginning Consonant Blends',
        'Ending Consonant Blends',
      ],
      'course_two': [
        'Compound Sounds',
        'Common Vowel Teams',
        'Syllables and Stress',
        'Word Families / Rhyming Words',
        'Irregular Words',
        'Morphology Basics',
      ],
      'course_three': [
        'Basic Sentence Patterns',
        'Phrases and Clauses',
        'Common Expressions & Phrases',
        'Question & Answer Formation',
        'Connected Speech',
        'Listening & Comprehension Practice',
      ],
    };

    lessons.forEach((courseId, lessonNames) {
      for (int i = 0; i < lessonNames.length; i++) {
        if (_progressManager.isLessonFullyCompleted(courseId, i)) {
          checkAchievements(courseId, i);
          checkCourseUnlocks(courseId);
        }
      }
    });

    // ── Star Collector retroactive check ────────────────────────────────────
    // Runs independently so already-earned stars are caught the next
    // time runRetroactiveCheck is called (e.g. on app launch).
    if (_getTotalStars() >= 54) {
      _notificationManager.addAchievementUnlockedNotification('Star Collector');
      checkBadges();
    }
  }

  /// Check and trigger achievement + badge notifications.
  static void checkAchievements(String courseId, int lessonIndex) {
    // ── First Step ──────────────────────────────────────────────────────────
    if (courseId == 'course_one' &&
        lessonIndex == 0 &&
        _progressManager.isLessonFullyCompleted('course_one', 0)) {
      _notificationManager.addAchievementUnlockedNotification('First Step');
      checkBadges();
    }

    // ── Course 1 Explorer ───────────────────────────────────────────────────
    if (courseId == 'course_one' && _allLessonsComplete('course_one')) {
      _notificationManager.addAchievementUnlockedNotification(
        'Course 1 Explorer',
      );
      checkBadges();
    }

    // ── Course 2 Achiever ───────────────────────────────────────────────────
    if (courseId == 'course_two' && _allLessonsComplete('course_two')) {
      _notificationManager.addAchievementUnlockedNotification(
        'Course 2 Achiever',
      );
      checkBadges();
    }

    // ── Course 3 Master ─────────────────────────────────────────────────────
    if (courseId == 'course_three' && _allLessonsComplete('course_three')) {
      _notificationManager.addAchievementUnlockedNotification(
        'Course 3 Master',
      );
      checkBadges();
    }

    // ── Guided Master ───────────────────────────────────────────────────────
    if (_allLessonsComplete('course_one') &&
        _allLessonsComplete('course_two') &&
        _allLessonsComplete('course_three')) {
      _notificationManager.addAchievementUnlockedNotification('Guided Master');
      checkBadges();
    }

    // ── Learning Journey ────────────────────────────────────────────────────
    if (_allLessonsComplete('course_one') &&
        _allLessonsComplete('course_two') &&
        _allLessonsComplete('course_three')) {
      _notificationManager.addAchievementUnlockedNotification(
        'Learning Journey',
      );
      checkBadges();
    }

    // ── Star Collector ──────────────────────────────────────────────────────
    if (_getTotalStars() >= 54) {
      _notificationManager.addAchievementUnlockedNotification('Star Collector');
      checkBadges();
    }
  }

  /// Check and trigger badge notifications.
  static void checkBadges() {
    // Stage Master Badge
    if (_allLessonsComplete('course_one') &&
        _allLessonsComplete('course_two') &&
        _allLessonsComplete('course_three')) {
      _notificationManager.addBadgeUnlockedNotification('Stage Master Badge');
    }

    // Pronunciation Legend Badge
    if (_progressManager.isLessonFullyCompleted('course_one', 0) &&
        _allLessonsComplete('course_one') &&
        _allLessonsComplete('course_two') &&
        _allLessonsComplete('course_three')) {
      _notificationManager.addBadgeUnlockedNotification(
        'Pronunciation Legend Badge',
      );
    }

    // Grand Master Badge
    if (_progressManager.isLessonFullyCompleted('course_one', 0) &&
        _allLessonsComplete('course_one') &&
        _allLessonsComplete('course_two') &&
        _allLessonsComplete('course_three')) {
      _notificationManager.addBadgeUnlockedNotification('Grand Master Badge');
    }
  }

  /// Check if Grade 2 / Grade 3 should be unlocked.
  static void checkCourseUnlocks(String courseId) {
    // ── Course 1 complete → Grade 2 + Stage 1 Assessment unlocked ──
    if (courseId == 'course_one' && _allLessonsComplete('course_one')) {
      _notificationManager.addCourseUnlockedNotification(
        'course_two',
        'Grade 2',
      );
      _notificationManager.addAssessmentUnlockedNotification(
        'Stage 1 Assessment',
      );
    }

    // ── Course 2 complete → Grade 3 + Stage 2 Assessment unlocked ──
    if (courseId == 'course_two' && _allLessonsComplete('course_two')) {
      _notificationManager.addCourseUnlockedNotification(
        'course_three',
        'Grade 3',
      );
      _notificationManager.addAssessmentUnlockedNotification(
        'Stage 2 Assessment',
      );
    }

    // ── Course 3 complete → Stage 3 Assessment unlocked ──
    if (courseId == 'course_three' && _allLessonsComplete('course_three')) {
      _notificationManager.addAssessmentUnlockedNotification(
        'Stage 3 Assessment',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static bool _allLessonsComplete(String courseId) {
    for (int i = 0; i < _totalLessonsPerCourse; i++) {
      if (!_progressManager.isLessonFullyCompleted(courseId, i)) return false;
    }
    return true;
  }

  static int _getTotalStars() {
    int total = 0;
    const courses = ['course_one', 'course_two', 'course_three'];
    const exerciseKeys = [
      'Stage1_Exercise',
      'Stage2_Exercise',
      'Stage3_Exercise',
    ];
    for (int c = 0; c < courses.length; c++) {
      for (int i = 0; i < _totalLessonsPerCourse; i++) {
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
}
