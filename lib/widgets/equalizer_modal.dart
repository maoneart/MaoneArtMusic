import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../theme/maoneart_theme.dart';

void showEqualizerModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => const EqualizerModal(),
  );
}

class EqualizerModal extends ConsumerStatefulWidget {
  const EqualizerModal({Key? key}) : super(key: key);

  @override
  ConsumerState<EqualizerModal> createState() => _EqualizerModalState();
}

class _EqualizerModalState extends ConsumerState<EqualizerModal> {
  final List<double> _speedOptions = [0.75, 1.0, 1.25, 1.5];

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 640),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF141927).withOpacity(0.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: MaoneArtTheme.primaryCyan.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MaoneArtTheme.primaryCyan.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: MaoneArtTheme.primaryCyan,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Equalizer & Efek Suara",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Hardware Equalizer Sistem & Efek Suara",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 14),

                // 2. Scrollable Body
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Equalizer Bawaan HP (Hardware EQ)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                MaoneArtTheme.primaryCyan.withOpacity(0.12),
                                MaoneArtTheme.primaryPurple.withOpacity(0.10),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: MaoneArtTheme.primaryCyan.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.headphones_rounded,
                                      color: MaoneArtTheme.spotifyGreenBright,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Equalizer Bawaan HP",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          "Dolby Atmos / Mi Sound / Wavelet",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: MaoneArtTheme.spotifyGreenBright,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Gunakan hardware equalizer sistem bawaan ponsel Anda untuk pemrosesan audio 10-band studio tanpa beban buffering atau lag streaming.",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withOpacity(0.7),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [MaoneArtTheme.primaryCyan, MaoneArtTheme.primaryPurple],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.tune_rounded, size: 18, color: Colors.white),
                                    label: const Text(
                                      "Buka Equalizer Sistem",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    onPressed: () async {
                                      final opened = await ref.read(playerProvider).openSystemEqualizer();
                                      if (!opened && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: const Color(0xFF1E2638),
                                            content: const Text(
                                              "Equalizer sistem tidak ditemukan (Bisa gunakan aplikasi Wavelet / Dolby Atmos).",
                                              style: TextStyle(color: Colors.white, fontSize: 13),
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Section 2: Kecepatan Putar (Playback Speed)
                        Row(
                          children: [
                            const Icon(
                              Icons.speed_rounded,
                              size: 16,
                              color: MaoneArtTheme.primaryCyan,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "KECEPATAN PUTAR",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: MaoneArtTheme.primaryCyan,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "${playerState.playbackSpeed.toStringAsFixed(2)}x",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: _speedOptions.map((speed) {
                            final isCurrent = (playerState.playbackSpeed - speed).abs() < 0.05;

                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: InkWell(
                                  onTap: () {
                                    ref.read(playerProvider).setPlaybackSpeed(speed);
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? MaoneArtTheme.primaryCyan.withOpacity(0.25)
                                          : Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isCurrent
                                            ? MaoneArtTheme.primaryCyan
                                            : Colors.white.withOpacity(0.12),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        speed == 1.0 ? "1.0x Normal" : "${speed}x",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                          color: isCurrent ? Colors.white : Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 20),

                        // Section 3: Volume Pemutar (Gain Tuning)
                        Row(
                          children: [
                            const Icon(
                              Icons.volume_up_rounded,
                              size: 16,
                              color: MaoneArtTheme.spotifyGreenBright,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "VOLUME OUTPUT PEMUTAR",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: MaoneArtTheme.spotifyGreenBright,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "${(playerState.volume * 100).toInt()}%",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.volume_mute_rounded, size: 18, color: Colors.white38),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                    activeTrackColor: MaoneArtTheme.primaryCyan,
                                    inactiveTrackColor: Colors.white12,
                                    thumbColor: MaoneArtTheme.spotifyGreenBright,
                                    overlayColor: MaoneArtTheme.primaryCyan.withOpacity(0.2),
                                  ),
                                  child: Slider(
                                    value: playerState.volume.clamp(0.0, 1.0),
                                    min: 0.0,
                                    max: 1.0,
                                    onChanged: (val) {
                                      ref.read(playerProvider).setVolume(val);
                                    },
                                  ),
                                ),
                              ),
                              const Icon(Icons.volume_up_rounded, size: 18, color: MaoneArtTheme.spotifyGreenBright),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 16),

                // 4. Modal Symmetric Action Buttons (MaoneArt Standard Grid 2-Kolom)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.25)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white70),
                          label: const Text(
                            "Reset Normal",
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            ref.read(playerProvider).resetAudioEffects();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [MaoneArtTheme.primaryCyan, MaoneArtTheme.primaryPurple],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              "Tutup",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
