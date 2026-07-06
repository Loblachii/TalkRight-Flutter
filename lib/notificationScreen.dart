import 'package:flutter/material.dart';
import 'notification_manager.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationManager _notificationManager = NotificationManager();

  @override
  void initState() {
    super.initState();
    // Mark all as read when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationManager.markAllAsRead();
    });
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.lessonComplete:
        return const Color(0xFF4CAF50);
      case NotificationType.achievementUnlocked:
        return const Color(0xFFFB8500);
      case NotificationType.badgeUnlocked:
        return const Color(0xFF2196F3);
      case NotificationType.courseUnlocked:
        return const Color(0xFF9C27B0);
      case NotificationType.assessmentUnlocked:
        return const Color(0xFFE91E63);
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.lessonComplete:
        return Icons.check_circle;
      case NotificationType.achievementUnlocked:
        return Icons.emoji_events;
      case NotificationType.badgeUnlocked:
        return Icons.military_tech;
      case NotificationType.courseUnlocked:
        return Icons.school;
      case NotificationType.assessmentUnlocked: // ← ADD THIS
        return Icons.assignment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFB8500), width: 3),
        ),
        // ─── ListenableBuilder rebuilds this subtree whenever
        //     notifyListeners() is called in NotificationManager ───
        child: ListenableBuilder(
          listenable: _notificationManager,
          builder: (context, _) {
            final notifications = _notificationManager.notifications;

            return Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(21),
                      topRight: Radius.circular(21),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Notifications',
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: 'Fredoka',
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Notification list
                Expanded(
                  child:
                      notifications.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_off,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No notifications yet',
                                  style: TextStyle(
                                    fontFamily: 'Fredoka',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 30,
                                  ),
                                  child: Text(
                                    'Complete lessons to start earning achievements!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Fredoka',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notification = notifications[index];
                              final color = _getNotificationColor(
                                notification.type,
                              );
                              final icon = _getNotificationIcon(
                                notification.type,
                              );

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFCF4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        notification.isRead
                                            ? Colors.transparent
                                            : color.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(icon, color: color, size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  notification.title,
                                                  style: TextStyle(
                                                    fontFamily: 'Fredoka',
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w400,
                                                    color:
                                                        notification.isRead
                                                            ? Colors.black87
                                                            : Colors.black,
                                                  ),
                                                ),
                                              ),
                                              if (!notification.isRead)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: color,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            notification.description,
                                            style: TextStyle(
                                              fontFamily: 'Fredoka',
                                              fontSize: 18,
                                              fontWeight: FontWeight.w300,
                                              color:
                                                  notification.isRead
                                                      ? Colors.black54
                                                      : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            notification.getTimeAgo(),
                                            style: TextStyle(
                                              fontFamily: 'Fredoka',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w300,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                ),

                // Close button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/close1Button.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
