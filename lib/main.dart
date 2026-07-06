import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'splashScreen.dart';
import 'settings_manager.dart';
import 'progress_manager.dart';
import 'notification_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await SettingsManager.initialize();
  await ProgressManager.initialize();

  // Wrap in try-catch so a notification init failure never blocks the app
  try {
    await NotificationManager.initialize();
  } catch (e) {
    debugPrint('NotificationManager init failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TalkRight App',
      home: const SplashScreen(),
    );
  }
}
