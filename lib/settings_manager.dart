import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  // Private constructor to prevent instantiation
  SettingsManager._();

  // Static variables for all settings
  static bool _soundEffectsEnabled = true;
  static bool _onboardingEnabled = true;
  static bool _pushNotificationEnabled = false;
  static double _speechInputVolume = 1;
  static double _speechOutputVolume = 1;
  static bool _isInitialized = false;

  // Keys for SharedPreferences
  static const String _soundEffectsKey = 'sound_effects_enabled';
  static const String _onboardingKey = 'onboarding_enabled';
  static const String _pushNotificationKey = 'push_notification_enabled';
  static const String _speechInputVolumeKey = 'speech_input_volume';
  static const String _speechOutputVolumeKey = 'speech_output_volume';

  // Initialize settings from SharedPreferences
  static Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();

    _soundEffectsEnabled = prefs.getBool(_soundEffectsKey) ?? true;
    _onboardingEnabled = prefs.getBool(_onboardingKey) ?? true;
    _pushNotificationEnabled = prefs.getBool(_pushNotificationKey) ?? false;
    _speechInputVolume = prefs.getDouble(_speechInputVolumeKey) ?? 1;
    _speechOutputVolume = prefs.getDouble(_speechOutputVolumeKey) ?? 1;

    _isInitialized = true;
  }

  // Getters
  static bool get soundEffectsEnabled => _soundEffectsEnabled;
  static bool get onboardingEnabled => _onboardingEnabled;
  static bool get pushNotificationEnabled => _pushNotificationEnabled;
  static double get speechInputVolume => _speechInputVolume;
  static double get speechOutputVolume => _speechOutputVolume;

  // Setters with persistence
  static Future<void> setSoundEffects(bool enabled) async {
    _soundEffectsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEffectsKey, enabled);
  }

  static Future<void> setOnboarding(bool enabled) async {
    _onboardingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, enabled);
  }

  static Future<void> setPushNotification(bool enabled) async {
    _pushNotificationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushNotificationKey, enabled);
  }

  static Future<void> setSpeechInputVolume(double volume) async {
    _speechInputVolume = volume;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_speechInputVolumeKey, volume);
  }

  static Future<void> setSpeechOutputVolume(double volume) async {
    _speechOutputVolume = volume;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_speechOutputVolumeKey, volume);
  }
}
