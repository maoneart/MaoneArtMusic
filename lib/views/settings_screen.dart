import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../services/storage_service.dart';
import '../services/youtube_audio_extractor.dart';
import '../services/audio_cache_service.dart';
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
  String _cacheSizeText = 'Memuat...';

  @override
  void initState() {
    super.initState();
    _refreshCacheSize();
  }

  Future<void> _refreshCacheSize() async {
    try {
      final bytes = await AudioCacheService.instance.getTotalCacheSizeBytes();
      final mb = bytes / (1024 * 1024);
      if (mounted) {
        setState(() {
          if (mb < 1.0) {
            _cacheSizeText = '${(bytes / 1024).toStringAsFixed(1)} KB';
          } else {
            _cacheSizeText = '${mb.toStringAsFixed(1)} MB / 500 MB Max';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cacheSizeText = '0 MB / 500 MB Max';
        });
      }
    }
  }

  void _showAudioQualityModal() {
    final qualities = [
      {
        'title': 'Tinggi (320kbps)',
        'desc': 'Audio resolusi tinggi, sangat jernih & detail',
        'val': 'Tinggi (320kbps)',
      },
      {
        'title': 'Sedang (160kbps)',
        'desc': 'Kualitas seimbang, hemat bandwidth & stabil',
        'val': 'Sedang (160kbps)',
      },
      {
        'title': 'Hemat Data (96kbps)',
        'desc': 'Sangat hemat kuota, buffering lebih cepat',
        'val': 'Hemat Data (96kbps)',
      },
    ];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF141927).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MaoneArtTheme.primaryCyan.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.high_quality_rounded, color: MaoneArtTheme.primaryCyan, size: 32),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Pilih Kualitas Audio",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Sesuaikan bitrate streaming YouTube Music",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ...qualities.map((item) {
                        final isSelected = _audioQuality == item['val'];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _audioQuality = item['val']!;
                              });
                              ref.read(playerProvider).setAudioQuality(item['val']!);
                              Navigator.of(context).pop();
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? MaoneArtTheme.primaryCyan.withOpacity(0.15)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? MaoneArtTheme.primaryCyan.withOpacity(0.5)
                                      : Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title']!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected ? MaoneArtTheme.primaryCyan : Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item['desc']!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded, color: MaoneArtTheme.primaryCyan, size: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.25)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            "Tutup",
                            style: TextStyle(color: Colors.white.withOpacity(0.8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 14, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: MaoneArtTheme.spotifyGreenBright,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0).copyWith(
            bottom: isLandscape ? 85 : 140,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Text(
                "Pengaturan",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Preferensi sistem, lirik & auto-cache offline",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 12),

              // Section 1: Audio & Streaming
              _buildSectionHeader("AUDIO & STREAMING"),
              _SettingTile(
                icon: Icons.graphic_eq_rounded,
                iconColor: MaoneArtTheme.primaryCyan,
                title: "Kualitas Audio",
                subtitle: "Bitrate streaming YouTube Music",
                onTap: _showAudioQualityModal,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: MaoneArtTheme.primaryCyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: MaoneArtTheme.primaryCyan.withOpacity(0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _audioQuality.split(' ')[0],
                        style: const TextStyle(
                          color: MaoneArtTheme.primaryCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: MaoneArtTheme.primaryCyan,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              _SettingTile(
                icon: Icons.lyrics_rounded,
                iconColor: MaoneArtTheme.primaryPurple,
                title: "Lirik Sinkron Real-time",
                subtitle: "Auto-scroll otomatis & pencarian multi-source",
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MaoneArtTheme.primaryPurple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: MaoneArtTheme.primaryPurple.withOpacity(0.3),
                      width: 1.0,
                    ),
                  ),
                  child: const Text(
                    "Aktif",
                    style: TextStyle(
                      color: MaoneArtTheme.primaryPurple,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _SettingTile(
                icon: Icons.flash_on_rounded,
                iconColor: MaoneArtTheme.accentGreen,
                title: "Smart Auto-Cache (0s Delay)",
                subtitle: "Otomatis menyimpan lagu yang diputar ke HP",
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MaoneArtTheme.accentGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: MaoneArtTheme.accentGreen.withOpacity(0.25),
                      width: 1.0,
                    ),
                  ),
                  child: const Text(
                    "Maks 500 MB",
                    style: TextStyle(
                      color: MaoneArtTheme.accentGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Section 2: Penyimpanan & Data
              _buildSectionHeader("PENYIMPANAN & DATA"),
              _SettingTile(
                icon: Icons.pie_chart_rounded,
                iconColor: MaoneArtTheme.primaryCyan,
                title: "Penyimpanan Offline & Cache",
                subtitle: "Ukuran file lagu di memori internal HP",
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _cacheSizeText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _SettingTile(
                icon: Icons.cleaning_services_rounded,
                iconColor: Colors.amberAccent,
                title: "Bersihkan Auto-Cache Audio",
                subtitle: "Hapus temporary cache (Lagu download manual aman)",
                onTap: () async {
                  final confirm = await MaoneArtGlassModal.showConfirmModal(
                    context: context,
                    title: "Bersihkan Auto-Cache?",
                    message: "Ini akan membersihkan temporary file auto-cache. Lagu yang Anda simpan/download manual TIDAK akan dihapus.",
                    confirmText: "Bersihkan",
                    cancelText: "Batal",
                    icon: Icons.cleaning_services_outlined,
                    iconColor: Colors.amberAccent,
                  );

                  if (confirm == true && mounted) {
                    YoutubeAudioExtractor.clearCache();
                    await AudioCacheService.instance.clearAutoCacheOnly();
                    await _refreshCacheSize();
                    ref.read(libraryProvider).loadLibrary();

                    if (mounted) {
                      await MaoneArtGlassModal.showAlertModal(
                        context: context,
                        title: "Auto-Cache Dibersihkan",
                        message: "Temporary cache audio berhasil dikosongkan.",
                        icon: Icons.check_circle_outline,
                        iconColor: MaoneArtTheme.accentGreen,
                      );
                    }
                  }
                },
                trailing: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Colors.white54,
                  ),
                ),
              ),
              _SettingTile(
                icon: Icons.history_toggle_off_rounded,
                iconColor: const Color(0xFFFF7043),
                title: "Reset Riwayat Putar",
                subtitle: "Bersihkan daftar lagu yang baru diputar",
                onTap: () async {
                  final confirm = await MaoneArtGlassModal.showConfirmModal(
                    context: context,
                    title: "Reset Riwayat Putar?",
                    message: "Daftar lagu yang baru diputar akan dikosongkan.",
                    confirmText: "Reset",
                    cancelText: "Batal",
                    icon: Icons.history_toggle_off_rounded,
                    iconColor: const Color(0xFFFF7043),
                  );

                  if (confirm == true && mounted) {
                    await StorageService().saveRecent([]);
                    if (mounted) {
                      await MaoneArtGlassModal.showAlertModal(
                        context: context,
                        title: "Riwayat Direset",
                        message: "Riwayat putar musik berhasil dikosongkan.",
                        icon: Icons.check_circle_outline,
                        iconColor: MaoneArtTheme.accentGreen,
                      );
                    }
                  }
                },
                trailing: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Colors.white54,
                  ),
                ),
              ),

              // Section 3: Informasi Aplikasi
              _buildSectionHeader("INFORMASI APLIKASI"),
              _SettingTile(
                icon: Icons.info_outline_rounded,
                iconColor: MaoneArtTheme.spotifyGreenBright,
                title: "Tentang Aplikasi",
                subtitle: "Profil developer, versi & info sistem",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AboutScreen()),
                  );
                },
                trailing: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Colors.white54,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // App Version Footer
              Center(
                child: Column(
                  children: [
                    Text(
                      "MaoneArt Music v1.0.0",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Developed with ❤️ by Hermawan",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.35),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isLandscape ? 40 : 140),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconColor.withOpacity(0.3), width: 1.0),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.55),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (trailing != null) trailing!,
        ],
      ),
      ),
    );
  }
}
