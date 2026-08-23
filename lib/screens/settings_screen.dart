import 'package:flutter/material.dart';

import '../services/sound_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _musicVolume = SoundService.instance.musicVolume;
  late double _sfxVolume = SoundService.instance.sfxVolume;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _VolumeSlider(
              icon: Icons.music_note_rounded,
              label: 'Musique',
              value: _musicVolume,
              onChanged: (value) {
                setState(() => _musicVolume = value);
                SoundService.instance.setMusicVolume(value);
              },
            ),
            const SizedBox(height: 28),
            _VolumeSlider(
              icon: Icons.graphic_eq_rounded,
              label: 'Effets sonores',
              value: _sfxVolume,
              onChanged: (value) {
                setState(() => _sfxVolume = value);
                SoundService.instance.setSfxVolume(value);
                if (value > 0) SoundService.instance.play(GameSound.tick);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _VolumeSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        Slider(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }
}
