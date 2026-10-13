import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/maoneart_theme.dart';
import 'glass_container.dart';
import 'app_artwork.dart';
import '../models/song.dart';

enum NeonVisualizerType {
  bars,   // Cyber Spectrum Bars with peak meters
  waves,  // Fluid Neon Sine Waveforms
  pulse,  // Neon Circular Orbit & Glow Rings
}

/// Standalone Full-Deck Neon Visualizer View for PlayerScreen
class NeonVisualizerDeck extends StatefulWidget {
  final bool isPlaying;
  final Song song;
  final NeonVisualizerType initialType;

  const NeonVisualizerDeck({
    Key? key,
    required this.isPlaying,
    required this.song,
    this.initialType = NeonVisualizerType.bars,
  }) : super(key: key);

  @override
  State<NeonVisualizerDeck> createState() => _NeonVisualizerDeckState();
}

class _NeonVisualizerDeckState extends State<NeonVisualizerDeck> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late NeonVisualizerType _currentType;

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          // 1. Top Mode Selector Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: MaoneArtTheme.primaryCyan.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MaoneArtTheme.primaryCyan.withOpacity(0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MaoneArtTheme.primaryCyan.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: MaoneArtTheme.primaryCyan,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "NEON VISUALIZER",
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              // Mode Pills
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTypePill("Bars", NeonVisualizerType.bars),
                  const SizedBox(width: 6),
                  _buildTypePill("Waves", NeonVisualizerType.waves),
                  const SizedBox(width: 6),
                  _buildTypePill("Pulse", NeonVisualizerType.pulse),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Main Animated Canvas
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Center(
                  child: _buildVisualizerBody(),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // 3. Status indicator & hint
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isPlaying
                      ? MaoneArtTheme.accentGreen
                      : Colors.white38,
                  boxShadow: widget.isPlaying
                      ? [
                          BoxShadow(
                            color: MaoneArtTheme.accentGreen.withOpacity(0.8),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.isPlaying ? "AUDIO REACTIVE LIVE" : "PAUSED (IDLE PULSE)",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: widget.isPlaying
                      ? MaoneArtTheme.accentGreen
                      : Colors.white38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypePill(String title, NeonVisualizerType type) {
    final isSelected = _currentType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentType = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? MaoneArtTheme.primaryCyan.withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? MaoneArtTheme.primaryCyan
                : Colors.white.withOpacity(0.12),
            width: isSelected ? 1.2 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: MaoneArtTheme.primaryCyan.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? MaoneArtTheme.primaryCyan : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildVisualizerBody() {
    switch (_currentType) {
      case NeonVisualizerType.bars:
        return NeonBarsVisualizer(
          animationValue: _controller.value,
          isPlaying: widget.isPlaying,
        );
      case NeonVisualizerType.waves:
        return NeonWavesVisualizer(
          animationValue: _controller.value,
          isPlaying: widget.isPlaying,
        );
      case NeonVisualizerType.pulse:
        return NeonPulseVisualizer(
          animationValue: _controller.value,
          isPlaying: widget.isPlaying,
          artworkUrl: widget.song.artworkUrl,
        );
    }
  }
}

/// Compact Neon Audio Wave Strip (Can be embedded beneath Artwork or in mini bars)
class NeonMiniVisualizerStrip extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double height;
  final Color? glowColor;

  const NeonMiniVisualizerStrip({
    Key? key,
    required this.isPlaying,
    this.barCount = 20,
    this.height = 36,
    this.glowColor,
  }) : super(key: key);

  @override
  State<NeonMiniVisualizerStrip> createState() => _NeonMiniVisualizerStripState();
}

class _NeonMiniVisualizerStripState extends State<NeonMiniVisualizerStrip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _NeonMiniStripPainter(
            animationValue: _controller.value,
            isPlaying: widget.isPlaying,
            barCount: widget.barCount,
            primaryColor: widget.glowColor ?? MaoneArtTheme.primaryCyan,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 1. NEON BARS SPECTRUM VISUALIZER (CYBER NEON BARS)
// ---------------------------------------------------------------------------
class NeonBarsVisualizer extends StatelessWidget {
  final double animationValue;
  final bool isPlaying;

  const NeonBarsVisualizer({
    Key? key,
    required this.animationValue,
    required this.isPlaying,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _NeonBarsPainter(
            animationValue: animationValue,
            isPlaying: isPlaying,
          ),
        );
      },
    );
  }
}

class _NeonBarsPainter extends CustomPainter {
  final double animationValue;
  final bool isPlaying;

  _NeonBarsPainter({
    required this.animationValue,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int barCount = 24;
    final double barWidth = (size.width / (barCount * 1.55)).clamp(4.0, 10.0);
    final double totalWidth = barCount * barWidth + (barCount - 1) * (barWidth * 0.55);
    final double startX = (size.width - totalWidth) / 2;
    final double centerY = size.height * 0.65;
    final double maxBarHeight = size.height * 0.55;

    final Paint glowPaint = Paint()..style = PaintingStyle.fill;
    final Paint barPaint = Paint()..style = PaintingStyle.fill;
    final Paint peakPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final double normalizedIdx = i / barCount;
      // Frequency weighting: Bass on left (boosted), mids in center, highs on right
      final double freqMultiplier = (math.sin(normalizedIdx * math.pi) * 0.5 + 0.5);

      // Multiple harmonic sine waves for rhythmic bouncing
      final double wave1 = math.sin((animationValue * 2 * math.pi * 1.8) + (i * 0.45));
      final double wave2 = math.cos((animationValue * 2 * math.pi * 3.2) - (i * 0.3));
      final double wave3 = math.sin((animationValue * 2 * math.pi * 0.9) + (i * 0.8));

      double rawHeightRatio;
      if (isPlaying) {
        rawHeightRatio = ((wave1 * 0.45 + wave2 * 0.35 + wave3 * 0.2).abs() * 0.85 + 0.15);
        rawHeightRatio = (rawHeightRatio * (0.65 + freqMultiplier * 0.5)).clamp(0.12, 1.0);
      } else {
        // Subtle resting idle breathing
        final double idle = math.sin((animationValue * 2 * math.pi) + (i * 0.25));
        rawHeightRatio = (0.08 + (idle * 0.04)).clamp(0.04, 0.15);
      }

      final double barH = rawHeightRatio * maxBarHeight;
      final double x = startX + i * (barWidth * 1.55);
      final double topY = centerY - barH;
      final double bottomY = centerY;

      // Color Palette: Gradient from Cyan -> Purple -> Accent Green
      final Color baseColor;
      if (normalizedIdx < 0.4) {
        baseColor = Color.lerp(MaoneArtTheme.primaryCyan, MaoneArtTheme.primaryPurple, normalizedIdx / 0.4)!;
      } else if (normalizedIdx < 0.75) {
        baseColor = Color.lerp(MaoneArtTheme.primaryPurple, const Color(0xFFFF0077), (normalizedIdx - 0.4) / 0.35)!;
      } else {
        baseColor = Color.lerp(const Color(0xFFFF0077), MaoneArtTheme.accentGreen, (normalizedIdx - 0.75) / 0.25)!;
      }

      final RRect barRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x, topY, x + barWidth, bottomY),
        Radius.circular(barWidth / 2),
      );

      // Outer Neon Glow Layer
      glowPaint
        ..color = baseColor.withOpacity(isPlaying ? 0.35 : 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(barRect, glowPaint);

      // Inner Solid Neon Bar with Gradient
      barPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.9),
          baseColor,
          baseColor.withOpacity(0.4),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromLTRB(x, topY, x + barWidth, bottomY));
      canvas.drawRRect(barRect, barPaint);

      // Floating Peak Meter Dot
      if (isPlaying) {
        final double peakY = (topY - 6.0).clamp(size.height * 0.05, centerY);
        final RRect peakDot = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, peakY, barWidth, 2.5),
          const Radius.circular(2),
        );
        peakPaint.color = Colors.white.withOpacity(0.95);
        canvas.drawRRect(peakDot, peakPaint);
      }

      // Reflection Mirror (Subtle Water/Glass Effect Underneath)
      final double reflectH = barH * 0.32;
      final RRect reflectRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x, bottomY + 2, x + barWidth, bottomY + 2 + reflectH),
        Radius.circular(barWidth / 2),
      );
      final Paint reflectPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            baseColor.withOpacity(0.25),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTRB(x, bottomY, x + barWidth, bottomY + reflectH));
      canvas.drawRRect(reflectRect, reflectPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeonBarsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying;
  }
}

// ---------------------------------------------------------------------------
// 2. NEON WAVES VISUALIZER (FLUID MULTI-LAYER SINE WAVES)
// ---------------------------------------------------------------------------
class NeonWavesVisualizer extends StatelessWidget {
  final double animationValue;
  final bool isPlaying;

  const NeonWavesVisualizer({
    Key? key,
    required this.animationValue,
    required this.isPlaying,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _NeonWavesPainter(
            animationValue: animationValue,
            isPlaying: isPlaying,
          ),
        );
      },
    );
  }
}

class _NeonWavesPainter extends CustomPainter {
  final double animationValue;
  final bool isPlaying;

  _NeonWavesPainter({
    required this.animationValue,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height * 0.52;
    final double maxAmplitude = isPlaying ? size.height * 0.32 : size.height * 0.08;

    // Draw 3 harmonic neon wave layers
    _drawSineWave(
      canvas: canvas,
      size: size,
      centerY: centerY,
      amplitude: maxAmplitude * 0.95,
      frequency: 2.2,
      phase: animationValue * 2 * math.pi * 2.0,
      color: MaoneArtTheme.primaryCyan,
      strokeWidth: 3.0,
    );

    _drawSineWave(
      canvas: canvas,
      size: size,
      centerY: centerY,
      amplitude: maxAmplitude * 0.75,
      frequency: 3.1,
      phase: -animationValue * 2 * math.pi * 1.5 + 1.2,
      color: MaoneArtTheme.primaryPurple,
      strokeWidth: 2.5,
    );

    _drawSineWave(
      canvas: canvas,
      size: size,
      centerY: centerY,
      amplitude: maxAmplitude * 0.55,
      frequency: 4.0,
      phase: animationValue * 2 * math.pi * 2.5 + 2.5,
      color: MaoneArtTheme.accentGreen,
      strokeWidth: 2.0,
    );
  }

  void _drawSineWave({
    required Canvas canvas,
    required Size size,
    required double centerY,
    required double amplitude,
    required double frequency,
    required double phase,
    required Color color,
    required double strokeWidth,
  }) {
    final Path path = Path();
    final double step = size.width / 60;

    for (double x = 0; x <= size.width; x += step) {
      // Gaussian window damping at the left/right edges
      final double normalizedX = (x / size.width) * 2 - 1; // -1 to 1
      final double damping = math.exp(-3.0 * normalizedX * normalizedX);

      final double y = centerY +
          math.sin((x / size.width) * frequency * 2 * math.pi + phase) *
              amplitude *
              damping;

      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Outer Glow
    final Paint glowPaint = Paint()
      ..color = color.withOpacity(isPlaying ? 0.45 : 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(path, glowPaint);

    // Inner Crisp Neon Stroke
    final Paint strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _NeonWavesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying;
  }
}

// ---------------------------------------------------------------------------
// 3. NEON PULSE VISUALIZER (CIRCULAR ORBIT & GLOW RINGS)
// ---------------------------------------------------------------------------
class NeonPulseVisualizer extends StatelessWidget {
  final double animationValue;
  final bool isPlaying;
  final String artworkUrl;

  const NeonPulseVisualizer({
    Key? key,
    required this.animationValue,
    required this.isPlaying,
    required this.artworkUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double size = math.min(constraints.maxWidth, constraints.maxHeight);
        final double centerArtworkSize = size * 0.46;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Custom Paint for Circular Neon Waves & Radial Spikes
            CustomPaint(
              size: Size(size, size),
              painter: _NeonPulsePainter(
                animationValue: animationValue,
                isPlaying: isPlaying,
                innerRadius: centerArtworkSize / 2,
              ),
            ),

            // Center Circular Rotating Album Thumbnail
            Container(
              width: centerArtworkSize,
              height: centerArtworkSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: MaoneArtTheme.primaryCyan.withOpacity(0.8),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: MaoneArtTheme.primaryCyan.withOpacity(0.5),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: AppArtwork(
                  artworkUrl: artworkUrl,
                  width: centerArtworkSize,
                  height: centerArtworkSize,
                  borderRadius: 0,
                  iconSize: 42,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NeonPulsePainter extends CustomPainter {
  final double animationValue;
  final bool isPlaying;
  final double innerRadius;

  _NeonPulsePainter({
    required this.animationValue,
    required this.isPlaying,
    required this.innerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = (size.width / 2) * 0.95;

    // 1. Expanding Neon Pulse Rings
    for (int ring = 0; ring < 3; ring++) {
      final double ringPhase = (animationValue + (ring * 0.33)) % 1.0;
      final double ringRadius = innerRadius + (maxRadius - innerRadius) * ringPhase;
      final double ringOpacity = (1.0 - ringPhase) * (isPlaying ? 0.65 : 0.25);

      final Color ringColor = ring == 0
          ? MaoneArtTheme.primaryCyan
          : ring == 1
              ? MaoneArtTheme.primaryPurple
              : MaoneArtTheme.accentGreen;

      final Paint ringPaint = Paint()
        ..color = ringColor.withOpacity(ringOpacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawCircle(center, ringRadius, ringPaint);
    }

    // 2. Radial Audio Frequency Spikes around the circle
    const int spokeCount = 36;
    final double spokeBaseRadius = innerRadius + 8.0;

    final Paint spikePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;

    for (int i = 0; i < spokeCount; i++) {
      final double angle = (i / spokeCount) * 2 * math.pi;
      final double wave = math.sin((animationValue * 2 * math.pi * 2.0) + (i * 0.7));
      final double spikeLen = isPlaying
          ? (wave.abs() * (maxRadius - spokeBaseRadius) * 0.75 + 4.0)
          : (4.0 + (wave * 2.0));

      final double startX = center.dx + math.cos(angle) * spokeBaseRadius;
      final double startY = center.dy + math.sin(angle) * spokeBaseRadius;
      final double endX = center.dx + math.cos(angle) * (spokeBaseRadius + spikeLen);
      final double endY = center.dy + math.sin(angle) * (spokeBaseRadius + spikeLen);

      final Color spikeColor = (i % 3 == 0)
          ? MaoneArtTheme.primaryCyan
          : (i % 3 == 1)
              ? MaoneArtTheme.primaryPurple
              : MaoneArtTheme.accentGreen;

      spikePaint.color = spikeColor.withOpacity(isPlaying ? 0.85 : 0.35);
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), spikePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeonPulsePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying;
  }
}

// ---------------------------------------------------------------------------
// 4. MINI PAINTER FOR HORIZONTAL COMPACT STRIP
// ---------------------------------------------------------------------------
class _NeonMiniStripPainter extends CustomPainter {
  final double animationValue;
  final bool isPlaying;
  final int barCount;
  final Color primaryColor;

  _NeonMiniStripPainter({
    required this.animationValue,
    required this.isPlaying,
    required this.barCount,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double barWidth = (size.width / (barCount * 1.6)).clamp(2.5, 6.0);
    final double spacing = (size.width - (barCount * barWidth)) / (barCount - 1);
    final double centerY = size.height * 0.5;
    final double maxHalfHeight = size.height * 0.44;

    final Paint barPaint = Paint()..style = PaintingStyle.fill;
    final Paint glowPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final double norm = i / barCount;
      final double wave1 = math.sin((animationValue * 2 * math.pi * 2.0) + (i * 0.5));
      final double wave2 = math.cos((animationValue * 2 * math.pi * 3.5) - (i * 0.3));

      double heightFactor;
      if (isPlaying) {
        heightFactor = ((wave1 * 0.6 + wave2 * 0.4).abs() * 0.85 + 0.15).clamp(0.12, 1.0);
      } else {
        heightFactor = 0.12;
      }

      final double h = heightFactor * maxHalfHeight;
      final double x = i * (barWidth + spacing);

      final Color color = Color.lerp(
        primaryColor,
        MaoneArtTheme.accentGreen,
        norm,
      )!;

      final RRect rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x, centerY - h, x + barWidth, centerY + h),
        Radius.circular(barWidth / 2),
      );

      glowPaint
        ..color = color.withOpacity(isPlaying ? 0.35 : 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRRect(rect, glowPaint);

      barPaint.color = color.withOpacity(isPlaying ? 0.9 : 0.4);
      canvas.drawRRect(rect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeonMiniStripPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying;
  }
}
