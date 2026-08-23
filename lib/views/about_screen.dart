import 'package:flutter/material.dart';
import '../theme/maoneart_theme.dart';
import '../widgets/glass_container.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MaoneArtTheme.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Tentang Aplikasi",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              // PP Bulat Profile Card
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        MaoneArtTheme.spotifyGreenBright,
                        MaoneArtTheme.primaryCyan,
                        MaoneArtTheme.primaryPurple,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.35),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 54,
                    backgroundColor: Color(0xFF141927),
                    backgroundImage: AssetImage('assets/images/pp.jpg'),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Developer Name & Title
              const Text(
                "Hermawan",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: MaoneArtTheme.spotifyGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MaoneArtTheme.spotifyGreen.withOpacity(0.4)),
                ),
                child: const Text(
                  "Developer & Creator",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MaoneArtTheme.spotifyGreenBright,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Detail Spesifikasi Aplikasi Card
              GlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: MaoneArtTheme.primaryCyan, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Informasi Sistem",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 16),

                    _buildDetailRow(Icons.apps_rounded, "Nama Aplikasi", "MaoneArt Music"),
                    const SizedBox(height: 14),
                    _buildDetailRow(Icons.verified_rounded, "Versi Rilis", "v1.0.0 (Release 2026)"),
                    const SizedBox(height: 14),
                    _buildDetailRow(Icons.code_rounded, "Bahasa Program", "Flutter & Dart (Google)"),
                    const SizedBox(height: 14),
                    _buildDetailRow(Icons.headphones_rounded, "Audio Engine", "ExoPlayer & YouTube Music"),
                    const SizedBox(height: 14),
                    _buildDetailRow(Icons.palette_outlined, "UI Design", "MaoneArt Glassmorphism"),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Deskripsi & Fitur Card
              GlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Tentang MaoneArt Music",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Aplikasi pemutar musik modern open source berbasis Flutter dengan antarmuka elegan terinspirasi Spotify. Menyajikan streaming audio cepat tanpa batas, pencarian cerdas instan, lirik lagu, dan tangga lagu terpopuler secara gratis.",
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Copyright Footer
              Text(
                "© 2026 Hermawan • MaoneArt. All rights reserved.",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: MaoneArtTheme.primaryCyan),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6)),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
