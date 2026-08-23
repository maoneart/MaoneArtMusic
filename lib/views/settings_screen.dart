import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../services/youtube_audio_extractor.dart';
import '../theme/maoneart_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/glass_modal.dart';
import 'about_screen.dart';

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

              const SizedBox(height: 12),

              // Tentang Aplikasi Tile (Opens Full-Page AboutScreen)
              GlassContainer(
                borderRadius: 16,
                padding: const EdgeInsets.all(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AboutScreen()),
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: MaoneArtTheme.primaryCyan),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Tentang Aplikasi",
                              style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Profil Developer & Info Sistem",
                              style: TextStyle(fontSize: 12, color: Colors.white54),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // App Version Footer
              Center(
                child: Text(
                  "MaoneArt Music v1.0.0 • by Hermawan",
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35)),
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
