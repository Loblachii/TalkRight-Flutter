import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'settings_manager.dart';

class NotificationManager extends ChangeNotifier {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final List<AppNotification> _notifications = [];
  final Set<String> _shownAchievements = {};
  final Set<String> _shownBadges = {};
  final Set<String> _shownCourses = {};
  bool _isFirstAchievement = true;
  bool _isFirstBadge = true;

  static final FlutterLocalNotificationsPlugin _pushPlugin =
      FlutterLocalNotificationsPlugin();
  static const int _dailyReminderId = 42;
  static const String _channelId = 'talkright_daily_reminder';
  static const String _channelName = 'Daily Reminders';

  static const String _notificationsKey = 'app_notifications';
  static const String _shownAchievementsKey = 'shown_achievements';
  static const String _shownBadgesKey = 'shown_badges';
  static const String _shownCoursesKey = 'shown_courses';
  static const String _firstAchievementKey = 'first_achievement_flag';
  static const String _firstBadgeKey = 'first_badge_flag';
  static const String _welcomeNotificationKey = 'welcome_notification_shown';
  static bool _isInitialized = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  // ─── Initialize ───────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Step 1: Init timezones (safe, no I/O)
    try {
      tz_data.initializeTimeZones();
    } catch (e) {
      debugPrint('Timezone init error: $e');
    }

    // Step 2: Init the local notifications plugin
    try {
      await _pushPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
    } catch (e) {
      debugPrint('Push plugin init error: $e');
    }

    // Step 3: Load persisted data from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();

      final notificationsJson = prefs.getString(_notificationsKey);
      if (notificationsJson != null && notificationsJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(notificationsJson);
          _instance._notifications.clear();
          _instance._notifications.addAll(
            decoded.map((item) => AppNotification.fromJson(item)).toList(),
          );
        } catch (e) {
          debugPrint('Error loading notifications: $e');
        }
      }

      final achievementsJson = prefs.getString(_shownAchievementsKey);
      if (achievementsJson != null && achievementsJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(achievementsJson);
          _instance._shownAchievements.clear();
          _instance._shownAchievements.addAll(decoded.cast<String>());
        } catch (e) {
          debugPrint('Error loading shown achievements: $e');
        }
      }

      final badgesJson = prefs.getString(_shownBadgesKey);
      if (badgesJson != null && badgesJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(badgesJson);
          _instance._shownBadges.clear();
          _instance._shownBadges.addAll(decoded.cast<String>());
        } catch (e) {
          debugPrint('Error loading shown badges: $e');
        }
      }

      final coursesJson = prefs.getString(_shownCoursesKey);
      if (coursesJson != null && coursesJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(coursesJson);
          _instance._shownCourses.clear();
          _instance._shownCourses.addAll(decoded.cast<String>());
        } catch (e) {
          debugPrint('Error loading shown courses: $e');
        }
      }

      _instance._isFirstAchievement =
          prefs.getBool(_firstAchievementKey) ?? true;
      _instance._isFirstBadge = prefs.getBool(_firstBadgeKey) ?? true;

      // Step 4: Show welcome notification if never shown
      try {
        final bool welcomeShown =
            prefs.getBool(_welcomeNotificationKey) ?? false;
        if (!welcomeShown) {
          _instance._notifications.insert(
            0,
            AppNotification(
              id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
              title: 'Welcome to TalkRight! 👋',
              description:
                  'Hi there! We\'re so glad you\'re here. Start your first lesson and begin your journey!',
              type: NotificationType.achievementUnlocked,
              timestamp: DateTime.now(),
              isRead: false,
            ),
          );
          await prefs.setBool(_welcomeNotificationKey, true);
          await prefs.setString(
            _notificationsKey,
            json.encode(
              _instance._notifications.map((n) => n.toJson()).toList(),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error showing welcome notification: $e');
      }
    } catch (e) {
      debugPrint('SharedPreferences load error: $e');
    }

    // Step 5: Schedule daily reminder if push is enabled
    if (SettingsManager.pushNotificationEnabled) {
      try {
        // Cancel any existing scheduled notification first to avoid conflicts
        await _cancelDailyReminder();
        await _scheduleDailyReminder();
      } catch (e) {
        debugPrint('Failed to schedule daily reminder on init: $e');
      }
    }

    _isInitialized = true;
  }

  // ─── Push Notification Methods ────────────────────────────────────────────

  static Future<void> _requestPermission() async {
    try {
      final android =
          _pushPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (android != null) {
        await android.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
  }

  static Future<void> _scheduleDailyReminder({
    int hour = 9,
    int minute = 0,
  }) async {
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      );

      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _pushPlugin.zonedSchedule(
        _dailyReminderId,
        '🗣️ Time to practice!',
        'Keep your streak going — a quick session is all it takes!',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule daily reminder: $e');
    }
  }

  static Future<void> _cancelDailyReminder() async {
    try {
      await _pushPlugin.cancel(_dailyReminderId);
    } catch (e) {
      debugPrint('Failed to cancel daily reminder: $e');
    }
  }

  static Future<void> setPushEnabled(bool enabled) async {
    try {
      await SettingsManager.setPushNotification(enabled);
    } catch (e) {
      debugPrint('Failed to save push setting: $e');
    }

    if (enabled) {
      try {
        await _requestPermission();
      } catch (e) {
        debugPrint('Permission request failed: $e');
      }
      try {
        // Cancel first to avoid duplicate scheduling on the same ID
        await _cancelDailyReminder();
        await _scheduleDailyReminder();
      } catch (e) {
        debugPrint('Failed to enable daily reminder: $e');
      }
    } else {
      try {
        await _cancelDailyReminder();
      } catch (e) {
        debugPrint('Failed to disable daily reminder: $e');
      }
    }
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> _saveAndNotify() async {
    notifyListeners();
    await _saveData();
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _notificationsKey,
        json.encode(_notifications.map((n) => n.toJson()).toList()),
      );
      await prefs.setString(
        _shownAchievementsKey,
        json.encode(_shownAchievements.toList()),
      );
      await prefs.setString(
        _shownBadgesKey,
        json.encode(_shownBadges.toList()),
      );
      await prefs.setString(
        _shownCoursesKey,
        json.encode(_shownCourses.toList()),
      );
      await prefs.setBool(_firstAchievementKey, _isFirstAchievement);
      await prefs.setBool(_firstBadgeKey, _isFirstBadge);
    } catch (e) {
      debugPrint('Error saving notification data: $e');
    }
  }

  // ─── Add Notifications ────────────────────────────────────────────────────

  void addLessonCompleteNotification(String courseId, String lessonName) {
    _notifications.insert(
      0,
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Lesson Complete! ✅',
        description:
            'Great job! You\'ve finished "$lessonName". Ready for the next challenge?',
        type: NotificationType.lessonComplete,
        timestamp: DateTime.now(),
        isRead: false,
      ),
    );
    _saveAndNotify();
  }

  void addAssessmentUnlockedNotification(String assessmentName) {
    if (_shownCourses.contains('assessment_$assessmentName')) return;
    _shownCourses.add('assessment_$assessmentName');

    _notifications.insert(
      0,
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Assessment Unlocked! 📝',
        description: '$assessmentName is now available. Ready to be tested?',
        type: NotificationType.assessmentUnlocked,
        timestamp: DateTime.now(),
        isRead: false,
      ),
    );
    _saveAndNotify();
  }

  void addAchievementUnlockedNotification(String achievementName) {
    if (_shownAchievements.contains(achievementName)) return;
    _shownAchievements.add(achievementName);

    String title;
    String description;

    if (_isFirstAchievement) {
      title = 'First Achievement! 🎊';
      description =
          'You\'ve unlocked "$achievementName"! This is just the beginning!';
      _isFirstAchievement = false;
    } else {
      final titleOptions = [
        'Master Unlocked! 🏆',
        'Completionist! ✅',
        'Rare Achievement! 💎',
      ];
      final descriptionOptions = [
        'Incredible! You\'ve earned "$achievementName" by mastering key skills!',
        'You\'ve completed all requirements for "$achievementName"! Well done!',
        'Amazing! You\'ve unlocked the rare "$achievementName" achievement!',
      ];
      final random = Random();
      title = titleOptions[random.nextInt(titleOptions.length)];
      description =
          descriptionOptions[random.nextInt(descriptionOptions.length)];
    }

    _notifications.insert(
      0,
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        type: NotificationType.achievementUnlocked,
        timestamp: DateTime.now(),
        isRead: false,
      ),
    );
    _saveAndNotify();
  }

  void addBadgeUnlockedNotification(String badgeName) {
    if (_shownBadges.contains(badgeName)) return;
    _shownBadges.add(badgeName);

    String title;
    String description;

    if (_isFirstBadge) {
      title = 'First Badge Earned! 🥇';
      description =
          'Congratulations! You\'ve unlocked your first badge: "$badgeName"!';
      _isFirstBadge = false;
    } else {
      final titleOptions = [
        'New Badge! 🛡️',
        'Master Badge Unlocked! 👑',
        'Badge Collector! 📍',
      ];
      final descriptionOptions = [
        'You\'ve earned the "$badgeName" badge! Your skills are growing!',
        'Incredible! You\'ve achieved the prestigious "$badgeName" badge!',
        'Well done! "$badgeName" has been added to your collection!',
      ];
      final random = Random();
      title = titleOptions[random.nextInt(titleOptions.length)];
      description =
          descriptionOptions[random.nextInt(descriptionOptions.length)];
    }

    _notifications.insert(
      0,
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        type: NotificationType.badgeUnlocked,
        timestamp: DateTime.now(),
        isRead: false,
      ),
    );
    _saveAndNotify();
  }

  void addCourseUnlockedNotification(String courseId, String courseName) {
    if (_shownCourses.contains(courseId)) return;
    _shownCourses.add(courseId);

    String title;
    String description;

    if (courseId == 'course_two') {
      title = 'Grade 2 Unlocked! 🔤';
      description =
          'Fantastic progress! Grade 2 is now available. Let\'s build words!';
    } else if (courseId == 'course_three') {
      title = 'Grade 3 Unlocked! 💬';
      description =
          'Outstanding! You\'ve reached Grade 3. Time to master sentences!';
    } else {
      title = '$courseName Unlocked! 🎓';
      description = 'Great job! $courseName is now available!';
    }

    _notifications.insert(
      0,
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        type: NotificationType.courseUnlocked,
        timestamp: DateTime.now(),
        isRead: false,
      ),
    );
    _saveAndNotify();
  }

  // ─── Read / Delete ────────────────────────────────────────────────────────

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _saveAndNotify();
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    _saveAndNotify();
  }

  void deleteNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _saveAndNotify();
  }

  void clearAllNotifications() {
    _notifications.clear();
    _saveAndNotify();
  }

  Future<void> resetAllData() async {
    _notifications.clear();
    _shownAchievements.clear();
    _shownBadges.clear();
    _shownCourses.clear();
    _isFirstAchievement = true;
    _isFirstBadge = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notificationsKey);
      await prefs.remove(_shownAchievementsKey);
      await prefs.remove(_shownBadgesKey);
      await prefs.remove(_shownCoursesKey);
      await prefs.remove(_firstAchievementKey);
      await prefs.remove(_firstBadgeKey);
      await prefs.remove(_welcomeNotificationKey);
    } catch (e) {
      debugPrint('Error resetting prefs: $e');
    }

    try {
      await _cancelDailyReminder();
    } catch (e) {
      debugPrint('Error cancelling reminder on reset: $e');
    }

    notifyListeners();
  }

  // ─── Getters ──────────────────────────────────────────────────────────────

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasUnreadNotifications => unreadCount > 0;
}

// ─── Enums & Models ───────────────────────────────────────────────────────────

enum NotificationType {
  lessonComplete,
  achievementUnlocked,
  badgeUnlocked,
  courseUnlocked,
  assessmentUnlocked,
}

class AppNotification {
  final String id;
  final String title;
  final String description;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.timestamp,
    required this.isRead,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? description,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.index,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'isRead': isRead,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        type: NotificationType.values[json['type'] as int],
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          json['timestamp'] as int,
        ),
        isRead: json['isRead'] as bool,
      );

  String getTimeAgo() {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }
}
