import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProgressManager {
  static final ProgressManager _instance = ProgressManager._internal();
  factory ProgressManager() => _instance;
  ProgressManager._internal();

  // Nested map: courseId -> lessonIndex -> LessonProgress
  final Map<String, Map<int, LessonProgress>> _courseProgress = {};

  // Map to store high scores: courseId -> lessonIndex -> exerciseType -> score
  final Map<String, Map<int, Map<String, int>>> _exerciseHighScores = {};

  // Separate storage for assessment high scores: assessmentId -> score
  final Map<String, int> _assessmentHighScores = {};

  // Assessment stage completion: 'stage1'/'stage2'/'stage3' -> completed count (0-4)
  final Map<String, int> _assessmentStageProgress = {};

  // Keys for SharedPreferences
  static const String _progressKey = 'course_progress_data';
  static const String _highScoresKey = 'exercise_high_scores_data';
  static const String _assessmentScoresKey = 'assessment_high_scores_data';
  static const String _assessmentStageKey = 'assessment_stage_progress_data';
  static bool _isInitialized = false;

  // Initialize - Load progress from SharedPreferences
  static Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();

    // Load progress data
    final progressJson = prefs.getString(_progressKey);
    if (progressJson != null && progressJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = json.decode(progressJson);

        _instance._courseProgress.clear();
        decoded.forEach((courseId, lessonsMap) {
          final Map<int, LessonProgress> lessonProgressMap = {};
          (lessonsMap as Map<String, dynamic>).forEach((
            lessonIndex,
            progressData,
          ) {
            int savedTotal = progressData['total'] as int;
            int savedCompleted = progressData['completed'] as int;

            // ✅ MIGRATION: clamp total to 1 for any course that was saved with
            // the old tasksPerLesson = 2 value. Also clamp the completed
            // bit-flags so bit 1 (the old second task) is cleared — only
            // bit 0 (game_drill) is valid now.
            if ((courseId == 'course_one' ||
                    courseId == 'course_two' ||
                    courseId == 'course_three') &&
                savedTotal > 1) {
              savedTotal = 1;
              savedCompleted = savedCompleted & 1; // keep only bit 0
            }

            lessonProgressMap[int.parse(lessonIndex)] = LessonProgress(
              savedCompleted,
              savedTotal,
            );
          });
          _instance._courseProgress[courseId] = lessonProgressMap;
        });
      } catch (e) {
        print('Error loading progress: $e');
      }
    }

    // Load high scores data
    final highScoresJson = prefs.getString(_highScoresKey);
    if (highScoresJson != null && highScoresJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = json.decode(highScoresJson);
        _instance._exerciseHighScores.clear();
        decoded.forEach((courseId, lessonsMap) {
          final Map<int, Map<String, int>> lessonScoresMap = {};
          (lessonsMap as Map<String, dynamic>).forEach((
            lessonIndex,
            exercisesMap,
          ) {
            final Map<String, int> exerciseScores = {};
            (exercisesMap as Map<String, dynamic>).forEach((
              exerciseType,
              score,
            ) {
              exerciseScores[exerciseType] = score as int;
            });
            lessonScoresMap[int.parse(lessonIndex)] = exerciseScores;
          });
          _instance._exerciseHighScores[courseId] = lessonScoresMap;
        });
      } catch (e) {
        print('Error loading high scores: $e');
      }
    }

    // Load assessment high scores data
    final assessmentScoresJson = prefs.getString(_assessmentScoresKey);
    if (assessmentScoresJson != null && assessmentScoresJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = json.decode(assessmentScoresJson);
        _instance._assessmentHighScores.clear();
        decoded.forEach((assessmentId, score) {
          _instance._assessmentHighScores[assessmentId] = score as int;
        });
      } catch (e) {
        print('Error loading assessment scores: $e');
      }
    }

    // Load assessment stage progress
    final stageProgressJson = prefs.getString(_assessmentStageKey);
    if (stageProgressJson != null && stageProgressJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = json.decode(stageProgressJson);
        _instance._assessmentStageProgress.clear();
        decoded.forEach((stageId, count) {
          _instance._assessmentStageProgress[stageId] = count as int;
        });
      } catch (e) {
        print('Error loading assessment stage progress: $e');
      }
    }

    _isInitialized = true;
  }

  // Save progress to SharedPreferences
  Future<void> _saveProgress() async {
    try {
      final Map<String, Map<String, Map<String, int>>> jsonData = {};
      _courseProgress.forEach((courseId, lessonsMap) {
        jsonData[courseId] = {};
        lessonsMap.forEach((lessonIndex, progress) {
          jsonData[courseId]![lessonIndex.toString()] = {
            'completed': progress.completed,
            'total': progress.total,
          };
        });
      });

      final Map<String, Map<String, Map<String, int>>> highScoresData = {};
      _exerciseHighScores.forEach((courseId, lessonsMap) {
        highScoresData[courseId] = {};
        lessonsMap.forEach((lessonIndex, exercisesMap) {
          highScoresData[courseId]![lessonIndex.toString()] = exercisesMap;
        });
      });

      final Map<String, int> assessmentScoresData = Map.from(
        _assessmentHighScores,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_progressKey, json.encode(jsonData));
      await prefs.setString(_highScoresKey, json.encode(highScoresData));
      await prefs.setString(
        _assessmentScoresKey,
        json.encode(assessmentScoresData),
      );
      await prefs.setString(
        _assessmentStageKey,
        json.encode(Map<String, int>.from(_assessmentStageProgress)),
      );
    } catch (e) {
      print('Error saving progress: $e');
    }
  }

  // Helper to get or create course map
  Map<int, LessonProgress> _getCourseMap(String courseId) {
    return _courseProgress.putIfAbsent(courseId, () => {});
  }

  Future<void> updateLessonProgress(
    String courseId,
    int lessonIndex,
    int completed,
    int total,
  ) async {
    final courseMap = _getCourseMap(courseId);
    courseMap[lessonIndex] = LessonProgress(completed, total);
    await _saveProgress();
  }

  LessonProgress? getLessonProgress(String courseId, int lessonIndex) {
    final courseMap = _courseProgress[courseId];
    if (courseMap == null) return null;
    return courseMap[lessonIndex];
  }

  String getProgressString(String courseId, int lessonIndex, int defaultTotal) {
    final progress = getLessonProgress(courseId, lessonIndex);
    if (progress == null) return "0/$defaultTotal";

    int actualCompleted = _countCompletedFromBitFlags(progress.completed);
    return "$actualCompleted/${progress.total}";
  }

  int getCompletedActivities(String courseId, int lessonIndex) {
    final progress = getLessonProgress(courseId, lessonIndex);
    if (progress == null) return 0;

    return _countCompletedFromBitFlags(progress.completed);
  }

  // Helper method to count completed exercises from bit flags
  int _countCompletedFromBitFlags(int bitFlags) {
    int count = 0;
    for (int i = 0; i < 32; i++) {
      if ((bitFlags & (1 << i)) != 0) {
        count++;
      }
    }
    return count;
  }

  /// Update exercise completion.
  ///
  /// With only one exercise per lesson remaining (game_drill / equivalents),
  /// all exercise types now map to bit 0. The default total is 1.
  Future<void> updateExerciseCompletion(
    String courseId,
    int lessonIndex,
    String exerciseType,
    bool completed,
  ) async {
    final courseMap = _getCourseMap(courseId);
    // ✅ UPDATED: default total is now 1 (was 2)
    final current = courseMap[lessonIndex] ?? LessonProgress(0, 1);
    int currentFlags = current.completed;

    // ✅ UPDATED: all exercise types now use bit 0 (single task per lesson)
    if (completed) {
      currentFlags |= 1; // Set bit 0
    } else {
      currentFlags &= ~1; // Clear bit 0
    }

    courseMap[lessonIndex] = LessonProgress(currentFlags, current.total);
    await _saveProgress();
  }

  /// Check if a specific exercise is completed.
  ///
  /// With a single task per lesson, all exercise types check bit 0.
  bool isExerciseCompleted(
    String courseId,
    int lessonIndex,
    String exerciseType,
  ) {
    final progress = getLessonProgress(courseId, lessonIndex);
    if (progress == null) return false;

    // ✅ UPDATED: all exercise types check bit 0
    return (progress.completed & 1) != 0;
  }

  // ===== EXERCISE HIGH SCORE METHODS =====

  /// Get the high score for a specific exercise
  int getExerciseHighScore(
    String courseId,
    int lessonIndex,
    String exerciseType,
  ) {
    final courseMap = _exerciseHighScores[courseId];
    if (courseMap == null) return 0;

    final lessonMap = courseMap[lessonIndex];
    if (lessonMap == null) return 0;

    return lessonMap[exerciseType] ?? 0;
  }

  /// Update the high score for a specific exercise
  Future<void> updateExerciseHighScore(
    String courseId,
    int lessonIndex,
    String exerciseType,
    int score,
  ) async {
    final courseMap = _exerciseHighScores.putIfAbsent(courseId, () => {});
    final lessonMap = courseMap.putIfAbsent(lessonIndex, () => {});

    final currentHighScore = lessonMap[exerciseType] ?? 0;
    if (score > currentHighScore) {
      lessonMap[exerciseType] = score;
      await _saveProgress();
    }
  }

  /// Get all high scores for a specific lesson
  Map<String, int> getLessonHighScores(String courseId, int lessonIndex) {
    final courseMap = _exerciseHighScores[courseId];
    if (courseMap == null) return {};

    return courseMap[lessonIndex] ?? {};
  }

  /// Reset high score for a specific exercise
  Future<void> resetExerciseHighScore(
    String courseId,
    int lessonIndex,
    String exerciseType,
  ) async {
    final courseMap = _exerciseHighScores[courseId];
    if (courseMap == null) return;

    final lessonMap = courseMap[lessonIndex];
    if (lessonMap == null) return;

    lessonMap.remove(exerciseType);
    await _saveProgress();
  }

  /// Reset all high scores for a lesson
  Future<void> resetLessonHighScores(String courseId, int lessonIndex) async {
    final courseMap = _exerciseHighScores[courseId];
    if (courseMap == null) return;

    courseMap.remove(lessonIndex);
    await _saveProgress();
  }

  /// Reset all high scores for a course
  Future<void> resetCourseHighScores(String courseId) async {
    _exerciseHighScores.remove(courseId);
    await _saveProgress();
  }

  void forceSetHighScore(
    String courseId,
    int lessonIndex,
    String exerciseType,
    int score,
  ) {
    final courseMap = _exerciseHighScores.putIfAbsent(courseId, () => {});
    final lessonMap = courseMap.putIfAbsent(lessonIndex, () => {});
    lessonMap[exerciseType] = score;
  }

  // ===== ASSESSMENT HIGH SCORE METHODS =====

  /// Get the high score for a specific assessment
  int getAssessmentHighScore(String assessmentId) {
    return _assessmentHighScores[assessmentId] ?? 0;
  }

  /// Update the high score for a specific assessment
  Future<void> updateAssessmentHighScore(String assessmentId, int score) async {
    final currentHighScore = _assessmentHighScores[assessmentId] ?? 0;

    if (score > currentHighScore) {
      _assessmentHighScores[assessmentId] = score;
      await _saveProgress();
    }
  }

  /// Get all assessment high scores
  Map<String, int> getAllAssessmentHighScores() {
    return Map.from(_assessmentHighScores);
  }

  /// Reset high score for a specific assessment
  Future<void> resetAssessmentHighScore(String assessmentId) async {
    _assessmentHighScores.remove(assessmentId);
    await _saveProgress();
  }

  /// Reset all assessment high scores
  Future<void> resetAllAssessmentHighScores() async {
    _assessmentHighScores.clear();
    await _saveProgress();
  }

  // ===== ASSESSMENT STAGE PROGRESS METHODS =====

  /// Get completed game count for a stage (0-4)
  int getAssessmentStageCompleted(String stageId) {
    return _assessmentStageProgress[stageId] ?? 0;
  }

  /// Get stage completion percentage (0.0 - 1.0)
  double getAssessmentStagePercentage(String stageId) {
    return (getAssessmentStageCompleted(stageId) / 4).clamp(0.0, 1.0);
  }

  /// Update completed game count for a stage
  Future<void> updateAssessmentStageProgress(
    String stageId,
    int completedCount,
  ) async {
    _assessmentStageProgress[stageId] = completedCount.clamp(0, 4);
    await _saveProgress();
  }

  /// Check if an assessment has been completed (has a high score > 0)
  bool hasCompletedAssessment(String assessmentId) {
    return (_assessmentHighScores[assessmentId] ?? 0) > 0;
  }

  /// Get the number of assessments completed
  int getCompletedAssessmentsCount() {
    return _assessmentHighScores.values.where((score) => score > 0).length;
  }

  /// Get average assessment score (returns 0 if no assessments completed)
  double getAverageAssessmentScore() {
    if (_assessmentHighScores.isEmpty) return 0.0;

    int totalScore = 0;
    int count = 0;

    _assessmentHighScores.forEach((_, score) {
      if (score > 0) {
        totalScore += score;
        count++;
      }
    });

    if (count == 0) return 0.0;
    return totalScore / count;
  }

  // ===== GENERAL PROGRESS METHODS =====

  // Get total activities count for a specific course
  int getTotalCompletedActivities(String courseId) {
    final courseMap = _courseProgress[courseId];
    if (courseMap == null) return 0;

    int total = 0;
    for (var progress in courseMap.values) {
      total += _countCompletedFromBitFlags(progress.completed);
    }
    return total;
  }

  // Check if lesson is fully completed
  bool isLessonFullyCompleted(String courseId, int lessonIndex) {
    final progress = getLessonProgress(courseId, lessonIndex);
    if (progress == null) return false;

    int completedCount = _countCompletedFromBitFlags(progress.completed);
    return completedCount >= progress.total;
  }

  // Get completion percentage for a lesson
  double getLessonCompletionPercentage(String courseId, int lessonIndex) {
    final progress = getLessonProgress(courseId, lessonIndex);
    if (progress == null || progress.total == 0) return 0.0;

    int completedCount = _countCompletedFromBitFlags(progress.completed);
    return completedCount / progress.total;
  }

  // Get overall course completion percentage
  double getCourseCompletionPercentage(String courseId) {
    final courseMap = _courseProgress[courseId];
    if (courseMap == null || courseMap.isEmpty) return 0.0;

    int totalCompleted = 0;
    int totalActivities = 0;

    for (var progress in courseMap.values) {
      totalCompleted += _countCompletedFromBitFlags(progress.completed);
      totalActivities += progress.total;
    }

    if (totalActivities == 0) return 0.0;
    return totalCompleted / totalActivities;
  }

  // Get number of completed lessons in a course
  int getCompletedLessonsCount(String courseId) {
    final courseMap = _courseProgress[courseId];
    if (courseMap == null) return 0;

    int count = 0;
    for (var entry in courseMap.entries) {
      if (isLessonFullyCompleted(courseId, entry.key)) {
        count++;
      }
    }
    return count;
  }

  // Reset all progress (including assessments and stage progress)
  Future<void> resetAllProgress() async {
    _courseProgress.clear();
    _exerciseHighScores.clear();
    _assessmentHighScores.clear();
    _assessmentStageProgress.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey);
    await prefs.remove(_highScoresKey);
    await prefs.remove(_assessmentScoresKey);
    await prefs.remove(_assessmentStageKey);
  }

  // Reset specific course progress
  Future<void> resetCourseProgress(String courseId) async {
    _courseProgress.remove(courseId);
    _exerciseHighScores.remove(courseId);
    await _saveProgress();
  }

  // Reset specific lesson progress
  Future<void> resetLessonProgress(String courseId, int lessonIndex) async {
    final courseMap = _courseProgress[courseId];
    if (courseMap != null) {
      courseMap.remove(lessonIndex);
    }

    final scoresMap = _exerciseHighScores[courseId];
    if (scoresMap != null) {
      scoresMap.remove(lessonIndex);
    }

    await _saveProgress();
  }

  // Get all course IDs that have progress
  List<String> getAllCourseIds() {
    return _courseProgress.keys.toList();
  }

  // Get all assessment IDs that have scores
  List<String> getAllAssessmentIds() {
    return _assessmentHighScores.keys.toList();
  }

  // Check if any progress exists (courses or assessments)
  bool hasAnyProgress() {
    return _courseProgress.isNotEmpty || _assessmentHighScores.isNotEmpty;
  }

  // Export progress as JSON string (for backup/debugging)
  String exportProgressAsJson() {
    final Map<String, dynamic> exportData = {
      'progress': {},
      'highScores': {},
      'assessmentScores': {},
      'assessmentStageProgress': Map<String, int>.from(
        _assessmentStageProgress,
      ),
    };

    _courseProgress.forEach((courseId, lessonsMap) {
      exportData['progress'][courseId] = {};
      lessonsMap.forEach((lessonIndex, progress) {
        exportData['progress'][courseId][lessonIndex.toString()] = {
          'completed': progress.completed,
          'total': progress.total,
        };
      });
    });

    _exerciseHighScores.forEach((courseId, lessonsMap) {
      exportData['highScores'][courseId] = {};
      lessonsMap.forEach((lessonIndex, exercisesMap) {
        exportData['highScores'][courseId][lessonIndex.toString()] =
            exercisesMap;
      });
    });

    exportData['assessmentScores'] = Map.from(_assessmentHighScores);

    return json.encode(exportData);
  }

  // Import progress from JSON string (for restore/debugging)
  Future<void> importProgressFromJson(String jsonString) async {
    try {
      final Map<String, dynamic> importData = json.decode(jsonString);

      if (importData.containsKey('progress')) {
        _courseProgress.clear();
        final progressData = importData['progress'] as Map<String, dynamic>;
        progressData.forEach((courseId, lessonsMap) {
          final Map<int, LessonProgress> lessonProgressMap = {};
          (lessonsMap as Map<String, dynamic>).forEach((
            lessonIndex,
            progressData,
          ) {
            lessonProgressMap[int.parse(lessonIndex)] = LessonProgress(
              progressData['completed'] as int,
              progressData['total'] as int,
            );
          });
          _courseProgress[courseId] = lessonProgressMap;
        });
      }

      if (importData.containsKey('highScores')) {
        _exerciseHighScores.clear();
        final highScoresData = importData['highScores'] as Map<String, dynamic>;
        highScoresData.forEach((courseId, lessonsMap) {
          final Map<int, Map<String, int>> lessonScoresMap = {};
          (lessonsMap as Map<String, dynamic>).forEach((
            lessonIndex,
            exercisesMap,
          ) {
            final Map<String, int> exerciseScores = {};
            (exercisesMap as Map<String, dynamic>).forEach((
              exerciseType,
              score,
            ) {
              exerciseScores[exerciseType] = score as int;
            });
            lessonScoresMap[int.parse(lessonIndex)] = exerciseScores;
          });
          _exerciseHighScores[courseId] = lessonScoresMap;
        });
      }

      if (importData.containsKey('assessmentScores')) {
        _assessmentHighScores.clear();
        final assessmentData =
            importData['assessmentScores'] as Map<String, dynamic>;
        assessmentData.forEach((assessmentId, score) {
          _assessmentHighScores[assessmentId] = score as int;
        });
      }

      if (importData.containsKey('assessmentStageProgress')) {
        _assessmentStageProgress.clear();
        final stageData =
            importData['assessmentStageProgress'] as Map<String, dynamic>;
        stageData.forEach((stageId, count) {
          _assessmentStageProgress[stageId] = count as int;
        });
      }

      await _saveProgress();
    } catch (e) {
      print('Error importing progress: $e');
      rethrow;
    }
  }
}

class LessonProgress {
  final int completed; // Stores bit flags
  final int total;

  LessonProgress(this.completed, this.total);

  @override
  String toString() {
    return 'LessonProgress(completed: $completed, total: $total)';
  }
}
