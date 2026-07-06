import 'package:flutter/material.dart';
import 'settings_manager.dart';
import 'notification_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool onboardingEnabled = true;
  bool pushNotificationEnabled = true;
  bool soundEffectsEnabled = true;
  double speechInputVolume = 1;
  double speechOutputVolume = 1;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      soundEffectsEnabled = SettingsManager.soundEffectsEnabled;
      onboardingEnabled = SettingsManager.onboardingEnabled;
      pushNotificationEnabled = SettingsManager.pushNotificationEnabled;
      speechInputVolume = SettingsManager.speechInputVolume;
      speechOutputVolume = SettingsManager.speechOutputVolume;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    switch (key) {
      case 'soundEffects':
        await SettingsManager.setSoundEffects(value as bool);
        break;
      case 'onboarding':
        await SettingsManager.setOnboarding(value as bool);
        break;
      case 'speechOutput':
        await SettingsManager.setSpeechOutputVolume(value as double);
        break;
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      color: const Color.fromRGBO(255, 252, 244, 1),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'Fredoka',
              fontSize: 26,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16),
          Divider(thickness: 1, height: 1),
        ],
      ),
    );
  }

  // ─── Body ─────────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),

        // ── General Settings ────────────────────────────────────────────────
        const Text(
          'General Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 36),

        SettingsToggle(
          icon: Icons.phone_iphone_outlined,
          title: 'Onboarding Screen',
          subtitle: 'Show the introduction screens when the app starts.',
          value: onboardingEnabled,
          onChanged: (value) async {
            setState(() => onboardingEnabled = value);
            await _saveSetting('onboarding', value);
          },
        ),
        const SizedBox(height: 34),

        SettingsToggle(
          icon: Icons.notifications_outlined,
          title: 'Push Notification',
          subtitle:
              'Receive reminders and updates about your learning journey.',
          value: pushNotificationEnabled,
          onChanged: (value) async {
            setState(() => pushNotificationEnabled = value);
            await NotificationManager.setPushEnabled(value);
          },
        ),
        const SizedBox(height: 34),

        SettingsToggle(
          icon: Icons.volume_up_outlined,
          title: 'SFX - Sound Effects',
          subtitle: 'Play sounds for game actions and feedback.',
          value: soundEffectsEnabled,
          onChanged: (value) async {
            setState(() => soundEffectsEnabled = value);
            await _saveSetting('soundEffects', value);
          },
        ),

        const SizedBox(height: 30),
        const Divider(),
        const SizedBox(height: 20),

        // ── Audio Preference ─────────────────────────────────────────────────
        const Text(
          'Audio Preference',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 36),

        SettingsSlider(
          icon: Icons.volume_up_outlined,
          title: 'Speech Output Volume',
          subtitle: 'Control the volume of the app\'s voice and instructions.',
          value: speechOutputVolume,
          onChanged: (value) async {
            setState(() => speechOutputVolume = value);
            await _saveSetting('speechOutput', value);
          },
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

// ─── SettingsToggle ───────────────────────────────────────────────────────────

class SettingsToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsToggle({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Fredoka',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w300,
                  fontFamily: 'Fredoka',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          thumbColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFFB8500);
            }
            return Colors.grey[300]!;
          }),
          trackColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFFB8500).withOpacity(0.5);
            }
            return Colors.grey[200]!;
          }),
        ),
      ],
    );
  }
}

// ─── SettingsSlider ───────────────────────────────────────────────────────────

class SettingsSlider extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final ValueChanged<double> onChanged;

  const SettingsSlider({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Fredoka',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w300,
                  fontFamily: 'Fredoka',
                ),
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: const Color(0xFFFB8500),
                  inactiveTrackColor: Colors.grey[300],
                  thumbColor: const Color(0xFFFB8500),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: Slider(
                  value: value,
                  onChanged: onChanged,
                  min: 0,
                  max: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
