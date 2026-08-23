import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../services/youtube_audio_extractor.dart';
import '../theme/maoneart_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/glass_modal.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _audioQuality = 'Tinggi (320kbps)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Pengaturan",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Audio Quality Tile
              GlassContainer(
                borderRadius: 16,
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.high_quality, color: MaoneArtTheme.primaryCyan),
                        SizedBox(width: 12),
                        Text(
                          "Kualitas Audio",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                    DropdownButton<String>(
                      value: _audioQuality,
                      dropdownColor: const Color(0xFF141927),
                      underline: const SizedBox.shrink(),
                      items: ['Tinggi (320kbps)', 'Sedang (160kbps)', 'Hemat Data (96kbps)']
                          .map((q) => DropdownMenuItem(
                                value: q,
                                child: Text(q, style: const TextStyle(color: MaoneArtTheme.primaryCyan, fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _audioQuality = val;
                          });
                          ref.read(playerProvider).setAudioQuality(val);
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Clear Cache Tile
              GlassContainer(
                borderRadius: 16,
                padding: const EdgeInsets.all(16),
                onTap: () async {
                  final confirm = await MaoneArtGlassModal.showConfirmModal(
                    context: context,
                    title: "Bersihkan Cache Audio?",
                    message: "Ini akan menghapus seluruh file cache memory audio stream dan metadata.",
                    confirmText: "Bersihkan",
                    cancelText: "Batal",
                    icon: Icons.cleaning_services_outlined,
                    iconColor: Colors.amberAccent,
                  );

                  if (confirm == true && mounted) {
                    YoutubeAudioExtractor.clearCache();
                    await MaoneArtGlassModal.showAlertModal(
                      context: context,
                      title: "Cache Dibersihkan",
                      message: "Seluruh cache temporary audio berhasil dibersihkan.",
                      icon: Icons.check_circle_outline,
                      iconColor: MaoneArtTheme.accentGreen,
                    );
                  }
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cleaning_services, color: Colors.amberAccent),
                        SizedBox(width: 12),
                        Text(
                          "Bersihkan Cache App",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                    Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // About Section Card
              GlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: MaoneArtTheme.primaryCyan,
                      child: Icon(Icons.music_note, size: 36, color: Colors.black),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "MaoneArt Music v1.0.0",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Klien Musik Open Source berbasis Flutter & Musify YouTube Audio Engine.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "© 2026 MaoneArt. All rights reserved.",
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 140),
            ],
          ),
        ),
      ),
    );
  }
}
