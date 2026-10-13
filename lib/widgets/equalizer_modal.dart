import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
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
  final List<String> _presetNames = [
    'Normal',
    'Bass Boost',
    'Vokal & Akustik',
    'Rock',
    'Pop',
    'Treble Boost',
    'Electronic',
  ];

  final List<double> _speedOptions = [0.75, 1.0, 1.25, 1.5];

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final eq = playerState.equalizer;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 680),
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
                            "Sesuaikan karakter output audio",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Toggle Switch
                    Switch(
                      value: playerState.isEqualizerEnabled,
                      activeColor: MaoneArtTheme.primaryCyan,
                      activeTrackColor: MaoneArtTheme.primaryCyan.withOpacity(0.35),
                      inactiveThumbColor: Colors.white60,
                      inactiveTrackColor: Colors.white12,
                      onChanged: (val) {
                        ref.read(playerProvider).setEqualizerEnabled(val);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),

                // 2. Scrollable Body
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Preset Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "PRESET AUDIO",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: MaoneArtTheme.primaryCyan,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: MaoneArtTheme.primaryPurple.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: MaoneArtTheme.primaryPurple.withOpacity(0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                playerState.equalizerPreset.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Preset Chips (Horizontal List)
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _presetNames.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final name = _presetNames[index];
                              final isSelected = playerState.equalizerPreset == name;

                              return InkWell(
                                onTap: playerState.isEqualizerEnabled
                                    ? () {
                                        ref.read(playerProvider).setEqualizerPreset(name);
                                      }
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? MaoneArtTheme.primaryCyan.withOpacity(0.22)
                                        : Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? MaoneArtTheme.primaryCyan
                                          : Colors.white.withOpacity(0.12),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.white : Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Equalizer Bands Section
                        const Text(
                          "FREKUENSI SUARA (5-BAND)",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: MaoneArtTheme.spotifyGreenBright,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // FutureBuilder for parameters
                        if (eq != null)
                          FutureBuilder<AndroidEqualizerParameters>(
                            future: eq.parameters,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: MaoneArtTheme.primaryCyan,
                                    ),
                                  ),
                                );
                              }

                              final params = snapshot.data;
                              if (params != null && params.bands.isNotEmpty) {
                                return Column(
                                  children: params.bands.map((band) {
                                    final freq = band.centerFrequency.round();
                                    final freqLabel = freq >= 1000
                                        ? '${(freq / 1000).toStringAsFixed(1)} kHz'
                                        : '$freq Hz';

                                    return _buildBandSlider(
                                      index: band.index,
                                      label: freqLabel,
                                      currentGain: band.gain,
                                      minGain: params.minDecibels,
                                      maxGain: params.maxDecibels,
                                      isEnabled: playerState.isEqualizerEnabled,
                                      onChanged: (newGain) {
                                        ref.read(playerProvider).setBandGain(band.index, newGain);
                                      },
                                    );
                                  }).toList(),
                                );
                              }

                              return _buildFallbackSliders(playerState);
                            },
                          )
                        else
                          _buildFallbackSliders(playerState),

                        const SizedBox(height: 18),

                        // 3. Playback Speed Section
                        Row(
                          children: [
                            const Icon(
                              Icons.speed_rounded,
                              size: 15,
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
                                          ? MaoneArtTheme.primaryPurple.withOpacity(0.3)
                                          : Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isCurrent
                                            ? MaoneArtTheme.primaryPurple
                                            : Colors.white.withOpacity(0.12),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        speed == 1.0 ? "1.0x (Normal)" : "${speed}x",
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
                            ref.read(playerProvider).resetEqualizer();
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

  Widget _buildBandSlider({
    required int index,
    required String label,
    required double currentGain,
    required double minGain,
    required double maxGain,
    required bool isEnabled,
    required ValueChanged<double> onChanged,
  }) {
    final displayGain = currentGain > 0
        ? '+${currentGain.toStringAsFixed(1)} dB'
        : '${currentGain.toStringAsFixed(1)} dB';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isEnabled ? Colors.white : Colors.white38,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: isEnabled ? MaoneArtTheme.primaryCyan : Colors.white24,
                inactiveTrackColor: Colors.white12,
                thumbColor: isEnabled ? MaoneArtTheme.spotifyGreenBright : Colors.white38,
                overlayColor: MaoneArtTheme.primaryCyan.withOpacity(0.2),
              ),
              child: Slider(
                value: currentGain.clamp(minGain, maxGain),
                min: minGain,
                max: maxGain,
                onChanged: isEnabled ? onChanged : null,
              ),
            ),
          ),
          SizedBox(
            width: 62,
            child: Text(
              displayGain,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isEnabled
                    ? (currentGain > 0 ? MaoneArtTheme.spotifyGreenBright : Colors.white70)
                    : Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackSliders(PlayerStateNotifier playerState) {
    final fallbackFreqs = ['60 Hz', '230 Hz', '910 Hz', '3.6 kHz', '14 kHz'];
    final presetValues = PlayerStateNotifier.equalizerPresets[playerState.equalizerPreset] ??
        [0.0, 0.0, 0.0, 0.0, 0.0];

    return Column(
      children: List.generate(fallbackFreqs.length, (i) {
        final gain = playerState.bandGains[i] ?? (i < presetValues.length ? presetValues[i] : 0.0);

        return _buildBandSlider(
          index: i,
          label: fallbackFreqs[i],
          currentGain: gain,
          minGain: -10.0,
          maxGain: 10.0,
          isEnabled: playerState.isEqualizerEnabled,
          onChanged: (newGain) {
            ref.read(playerProvider).setBandGain(i, newGain);
          },
        );
      }),
    );
  }
}
