import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final Duration position;
  final int sessionId;
  final NeonVisualizerType initialType;

  const NeonVisualizerDeck({
    Key? key,
    required this.isPlaying,
    required this.song,
    this.position = Duration.zero,
    this.sessionId = 0,
    this.initialType = NeonVisualizerType.bars,
  }) : super(key: key);

  @override
  State<NeonVisualizerDeck> createState() => _NeonVisualizerDeckState();
}

class _NeonVisualizerDeckState extends State<NeonVisualizerDeck> with SingleTickerProviderStateMixin {
  static const MethodChannel _visualizerChannel = MethodChannel('com.maoneart.music/visualizer');
  static const EventChannel _streamChannel = EventChannel('com.maoneart.music/visualizer_stream');

  late AnimationController _controller;
  late NeonVisualizerType _currentType;

  StreamSubscription? _streamSubscription;
  List<double> _currentBands = List.filled(24, 0.1);
  bool _isNativeActive = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _initNativeVisualizer();
  }

  @override
  void didUpdateWidget(covariant NeonVisualizerDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionId != oldWidget.sessionId || widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying && _hasPermission) {
        _startNativeStream();
      }
    }
  }

  Future<void> _initNativeVisualizer() async {
    try {
      final hasPerm = await _visualizerChannel.invokeMethod<bool>('hasPermission') ?? false;
      if (mounted) {
        setState(() {
          _hasPermission = hasPerm;
        });
      }
      if (hasPerm && widget.isPlaying) {
        _startNativeStream();
      }
    } catch (_) {}
  }

  Future<void> _requestPermissionAndStart() async {
    try {
      final granted = await _visualizerChannel.invokeMethod<bool>('requestPermission') ?? false;
      if (mounted) {
        setState(() {
          _hasPermission = granted;
        });
      }
      if (granted) {
        _startNativeStream();
      }
    } catch (e) {
      debugPrint("requestPermission error: $e");
    }
  }

  void _startNativeStream() async {
    try {
      await _visualizerChannel.invokeMethod('startVisualizer', {'sessionId': widget.sessionId});
      _streamSubscription?.cancel();
      _streamSubscription = _streamChannel.receiveBroadcastStream().listen(
        (data) {
          if (data is List && mounted) {
            final raw = data.map((e) => (e as num).toDouble()).toList();
            if (raw.isNotEmpty) {
              final newBands = List<double>.filled(24, 0.0);
              for (int i = 0; i < 24; i++) {
                final target = i < raw.length ? raw[i] : 0.0;
                // Fast attack, smooth decay (Exponential Smoothing)
                newBands[i] = (_currentBands[i] * 0.45) + (target * 0.55);
              }
              setState(() {
                _currentBands = newBands;
                _isNativeActive = true;
              });
            }
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isNativeActive = false;
            });
          }
        },
      );
    } catch (e) {
      debugPrint("startVisualizer error: $e");
    }
  }

  void _stopNativeStream() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _visualizerChannel.invokeMethod('stopVisualizer').catchError((_) {});
    _isNativeActive = false;
  }

  @override
  void dispose() {
    _stopNativeStream();
    _controller.dispose();
    super.dispose();
  }

  /// Calculates real musical tempo and beat-reactive rhythm when native FFT is idle
  List<double> _getRhythmicBands() {
    if (_isNativeActive && widget.isPlaying) {
      return _currentBands;
    }

    if (!widget.isPlaying) {
      // Gentle idle breathing
      return List.generate(24, (i) {
        final idle = math.sin((_controller.value * 2 * math.pi) + (i * 0.25));
        return (0.08 + (idle * 0.04)).clamp(0.04, 0.15);
      });
    }

    final int ms = widget.position.inMilliseconds;
    // 128 BPM rhythm: ~468ms per quarter-note beat
    const double beatPeriod = 468.0;
    final double beatCount = ms / beatPeriod;
    final int currentBeat = (beatCount % 4).floor(); // 0, 1, 2, 3 in 4/4 meter
    final double beatPhase = (ms % beatPeriod.toInt()) / beatPeriod; // 0.0 to 1.0
    final double decay = math.exp(-beatPhase * 4.8); // Percussive transient snap

    // Kick drum: Hits hard on beat 1 and 3 (0 and 2)
    final bool isKick = (currentBeat == 0 || currentBeat == 2);
    final double kickPulse = isKick ? decay : (decay * 0.25);

    // Snare / Clap: Snaps on beat 2 and 4 (1 and 3)
    final bool isSnare = (currentBeat == 1 || currentBeat == 3);
    final double snarePulse = isSnare ? decay : (decay * 0.18);

    // Hi-hats: 8th notes (half beat = 234ms)
    final double hatPhase = (ms % (beatPeriod ~/ 2)) / (beatPeriod / 2);
    final double hatPulse = math.exp(-hatPhase * 5.5);

    // Dynamic 16-bar phrase energy cycle (build-up & drops)
    final double phraseEnergy = 0.72 + (math.sin(beatCount * (math.pi / 8)) * 0.28);

    final List<double> bands = List.filled(24, 0.1);
    for (int i = 0; i < 24; i++) {
      double val = 0.15;
      if (i < 7) {
        // Bass / Sub-bass: Heavily driven by kick
        final double dist = 1.0 - (i / 7.0);
        val = 0.18 + (kickPulse * 0.82 * dist);
      } else if (i < 16) {
        // Mids / Vocals / Snare: Driven by snare and chord harmonics
        final double midSpread = math.sin((i - 7) * (math.pi / 9));
        val = 0.18 + (snarePulse * 0.75 * midSpread);
      } else {
        // Highs / Treble / Cymbals: Driven by fast hi-hats
        final double highSpread = (i - 16) / 8.0;
        val = 0.15 + (hatPulse * 0.85 * highSpread);
      }
      val *= phraseEnergy;
      bands[i] = val.clamp(0.08, 1.0);
    }

    return bands;
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

          // 2. Main Animated Canvas (Driven by live or beat-sync bands)
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final bands = _getRhythmicBands();
                return Center(
                  child: _buildVisualizerBody(bands),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // 3. Audio Rhythm Status & Hardware FFT Trigger
          _buildRhythmStatusBadge(),
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

  Widget _buildRhythmStatusBadge() {
    if (_isNativeActive && widget.isPlaying) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: MaoneArtTheme.primaryCyan.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MaoneArtTheme.primaryCyan.withOpacity(0.4), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MaoneArtTheme.primaryCyan,
                boxShadow: [
                  BoxShadow(
                    color: MaoneArtTheme.primaryCyan.withOpacity(0.9),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              "IRAMA AUDIO ASLI AKTIF (HARDWARE FFT)",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: MaoneArtTheme.primaryCyan,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isPlaying ? MaoneArtTheme.accentGreen : Colors.white38,
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
          widget.isPlaying ? "BEAT SYNC AKTIF (128 BPM)" : "PAUSED (IDLE PULSE)",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: widget.isPlaying ? MaoneArtTheme.accentGreen : Colors.white38,
          ),
        ),
        if (!_hasPermission && widget.isPlaying) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _requestPermissionAndStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: MaoneArtTheme.primaryPurple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MaoneArtTheme.primaryPurple, width: 0.8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic, size: 10, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    "Sinkronkan FFT Asli",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVisualizerBody(List<double> bands) {
    switch (_currentType) {
      case NeonVisualizerType.bars:
        return NeonBarsVisualizer(
          bands: bands,
          animationValue: _controller.value,
          isPlaying: widget.isPlaying,
        );
      case NeonVisualizerType.waves:
        return NeonWavesVisualizer(
          bands: bands,
          animationValue: _controller.value,
          isPlaying: widget.isPlaying,
        );
      case NeonVisualizerType.pulse:
        return NeonPulseVisualizer(
          bands: bands,
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
  final Duration position;
  final int barCount;
  final double height;
  final Color? glowColor;

  const NeonMiniVisualizerStrip({
    Key? key,
    required this.isPlaying,
    this.position = Duration.zero,
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
      duration: const Duration(milliseconds: 1400),
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
            positionMs: widget.position.inMilliseconds,
            barCount: widget.barCount,
            primaryColor: widget.glowColor ?? MaoneArtTheme.primaryCyan,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 1. NEON BARS SPECTRUM VISUALIZER (CYBER NEON BARS - REAL BEAT DRIVEN)
// ---------------------------------------------------------------------------
class NeonBarsVisualizer extends StatelessWidget {
  final List<double> bands;
  final double animationValue;
  final bool isPlaying;

  const NeonBarsVisualizer({
    Key? key,
    required this.bands,
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
            bands: bands,
            animationValue: animationValue,
            isPlaying: isPlaying,
          ),
        );
      },
    );
  }
}

class _NeonBarsPainter extends CustomPainter {
  final List<double> bands;
  final double animationValue;
  final bool isPlaying;

  _NeonBarsPainter({
    required this.bands,
    required this.animationValue,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int barCount = bands.length.clamp(16, 24);
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
      final double rawHeightRatio = bands[i].clamp(0.05, 1.0);
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
        ..color = baseColor.withOpacity(isPlaying ? 0.38 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(barRect, glowPaint);

      // Inner Solid Neon Bar with Gradient
      barPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.92),
          baseColor,
          baseColor.withOpacity(0.35),
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
    return oldDelegate.bands != bands ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying;
  }
}

// ---------------------------------------------------------------------------
// 2. NEON WAVES VISUALIZER (FLUID SINE WAVES - MODULATED BY REAL AUDIO)
// ---------------------------------------------------------------------------
class NeonWavesVisualizer extends StatelessWidget {
  final List<double> bands;
  final double animationValue;
  final bool isPlaying;

  const NeonWavesVisualizer({
    Key? key,
    required this.bands,
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
            bands: bands,
            animationValue: animationValue,
            isPlaying: isPlaying,
          ),
        );
      },
    );
  }
}

class _NeonWavesPainter extends CustomPainter {
  final List<double> bands;
  final double animationValue;
  final bool isPlaying;

  _NeonWavesPainter({
    required this.bands,
    required this.animationValue,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height * 0.52;

    // Extract average energy for Low (Bass), Mid, High from bands
    double bassEnergy = 0.2;
    double midEnergy = 0.2;
    double highEnergy = 0.2;

    if (bands.length >= 24) {
      bassEnergy = (bands.sublist(0, 7).reduce((a, b) => a + b) / 7.0).clamp(0.05, 1.0);
      midEnergy = (bands.sublist(7, 16).reduce((a, b) => a + b) / 9.0).clamp(0.05, 1.0);
      highEnergy = (bands.sublist(16, 24).reduce((a, b) => a + b) / 8.0).clamp(0.05, 1.0);
    }

    final double maxAmplitude = isPlaying ? size.height * 0.38 : size.height * 0.08;

    // 1. Cyan Bass Wave
    _drawSineWave(
      canvas: canvas,
      size: size,
      centerY: centerY,
      amplitude: maxAmplitude * (isPlaying ? bassEnergy * 1.1 : 0.6),
      frequency: 2.0,
      phase: animationValue * 2 * math.pi * 2.2,
      color: MaoneArtTheme.primaryCyan,
      strokeWidth: 3.2,
    );

    // 2. Purple Mid Wave
    _drawSineWave(
      canvas: canvas,
      size: size,
      centerY: centerY,
      amplitude: maxAmplitude * (isPlaying ? midEnergy * 0.9 : 0.5),
      frequency: 3.2,
      phase: -animationValue * 2 * math.pi * 1.8 + 1.2,
      color: MaoneArtTheme.primaryPurple,
      strokeWidth: 2.6,
    );

    // 3. Green Treble Wave
    _drawSineWave(
      canvas: canvas,
      size: size,
      centerY: centerY,
      amplitude: maxAmplitude * (isPlaying ? highEnergy * 0.75 : 0.4),
      frequency: 4.4,
      phase: animationValue * 2 * math.pi * 2.8 + 2.4,
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
      final double normalizedX = (x / size.width) * 2 - 1;
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
      ..color = color.withOpacity(isPlaying ? 0.48 : 0.18)
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
    return oldDelegate.bands != bands ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying;
  }
}

// ---------------------------------------------------------------------------
// 3. NEON PULSE VISUALIZER (CIRCULAR ORBIT - KICK BASS DRIVEN)
// ---------------------------------------------------------------------------
class NeonPulseVisualizer extends StatelessWidget {
  final List<double> bands;
  final double animationValue;
  final bool isPlaying;
  final String artworkUrl;

  const NeonPulseVisualizer({
    Key? key,
    required this.bands,
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
                bands: bands,
                animationValue: animationValue,
                isPlaying: isPlaying,
                innerRadius: centerArtworkSize / 2,
              ),
            ),

            // Center Circular Rotating Album Thumbnail with kick pulse bounce
            _buildCenterArtwork(centerArtworkSize),
          ],
        );
      },
    );
  }

  Widget _buildCenterArtwork(double baseSize) {
    double bassKick = 0.0;
    if (bands.isNotEmpty && isPlaying) {
      bassKick = (bands.take(4).reduce((a, b) => a + b) / 4.0).clamp(0.0, 1.0);
    }
    final double scale = 1.0 + (bassKick * 0.08);

    return Transform.scale(
      scale: scale,
      child: Container(
        width: baseSize,
        height: baseSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: MaoneArtTheme.primaryCyan.withOpacity(0.85),
            width: 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: MaoneArtTheme.primaryCyan.withOpacity(0.4 + (bassKick * 0.4)),
              blurRadius: 24 + (bassKick * 16),
              spreadRadius: 4 + (bassKick * 4),
            ),
          ],
        ),
        child: ClipOval(
          child: AppArtwork(
            artworkUrl: artworkUrl,
            width: baseSize,
            height: baseSize,
            borderRadius: 0,
            iconSize: 42,
          ),
        ),
      ),
    );
  }
}

class _NeonPulsePainter extends CustomPainter {
  final List<double> bands;
  final double animationValue;
  final bool isPlaying;
  final double innerRadius;

  _NeonPulsePainter({
    required this.bands,
    required this.animationValue,
    required this.isPlaying,
    required this.innerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = (size.width / 2) * 0.95;

    // Bass energy for ring expansion
    double bassEnergy = 0.2;
    if (bands.isNotEmpty && isPlaying) {
      bassEnergy = (bands.take(5).reduce((a, b) => a + b) / 5.0).clamp(0.05, 1.0);
    }

    // 1. Expanding Neon Pulse Rings modulated by bass kick
    for (int ring = 0; ring < 3; ring++) {
      final double ringPhase = (animationValue + (ring * 0.33)) % 1.0;
      final double ringRadius = innerRadius + (maxRadius - innerRadius) * ringPhase;
      final double ringOpacity = (1.0 - ringPhase) * (isPlaying ? (0.4 + bassEnergy * 0.5) : 0.2);

      final Color ringColor = ring == 0
          ? MaoneArtTheme.primaryCyan
          : ring == 1
              ? MaoneArtTheme.primaryPurple
              : MaoneArtTheme.accentGreen;

      final Paint ringPaint = Paint()
        ..color = ringColor.withOpacity(ringOpacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + (bassEnergy * 1.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawCircle(center, ringRadius, ringPaint);
    }

    // 2. Radial Audio Frequency Spikes mapped to frequency bands
    const int spokeCount = 36;
    final double spokeBaseRadius = innerRadius + 8.0;

    final Paint spikePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;

    for (int i = 0; i < spokeCount; i++) {
      final double angle = (i / spokeCount) * 2 * math.pi;
      final int bandIdx = (i * bands.length ~/ spokeCount).clamp(0, bands.length - 1);
      final double bandMag = bands.isNotEmpty ? bands[bandIdx] : 0.2;

      final double spikeLen = isPlaying
          ? (bandMag * (maxRadius - spokeBaseRadius) * 0.85 + 4.0)
          : (4.0 + (math.sin(animationValue * 2 * math.pi + i) * 2.0));

      final double startX = center.dx + math.cos(angle) * spokeBaseRadius;
      final double startY = center.dy + math.sin(angle) * spokeBaseRadius;
      final double endX = center.dx + math.cos(angle) * (spokeBaseRadius + spikeLen);
      final double endY = center.dy + math.sin(angle) * (spokeBaseRadius + spikeLen);

      final Color spikeColor = (i % 3 == 0)
          ? MaoneArtTheme.primaryCyan
          : (i % 3 == 1)
              ? MaoneArtTheme.primaryPurple
              : MaoneArtTheme.accentGreen;

      spikePaint.color = spikeColor.withOpacity(isPlaying ? (0.6 + bandMag * 0.4).clamp(0.0, 1.0) : 0.35);
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), spikePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeonPulsePainter oldDelegate) {
    return oldDelegate.bands != bands ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying;
  }
}

// ---------------------------------------------------------------------------
// 4. MINI PAINTER FOR HORIZONTAL COMPACT STRIP (RHYTHMIC BEAT-AWARE)
// ---------------------------------------------------------------------------
class _NeonMiniStripPainter extends CustomPainter {
  final double animationValue;
  final bool isPlaying;
  final int positionMs;
  final int barCount;
  final Color primaryColor;

  _NeonMiniStripPainter({
    required this.animationValue,
    required this.isPlaying,
    required this.positionMs,
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

    // 128 BPM beat pulse
    const double beatPeriod = 468.0;
    final double beatPhase = (positionMs % beatPeriod.toInt()) / beatPeriod;
    final double decay = math.exp(-beatPhase * 4.2);

    for (int i = 0; i < barCount; i++) {
      final double norm = i / barCount;
      double heightFactor;

      if (isPlaying) {
        final double harmonic = math.sin((animationValue * 2 * math.pi * 2.0) + (i * 0.6));
        heightFactor = (0.2 + (decay * 0.65 * (1.0 - norm * 0.5)) + (harmonic.abs() * 0.2)).clamp(0.12, 1.0);
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
        ..color = color.withOpacity(isPlaying ? 0.38 : 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRRect(rect, glowPaint);

      barPaint.color = color.withOpacity(isPlaying ? 0.92 : 0.4);
      canvas.drawRRect(rect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeonMiniStripPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.positionMs != positionMs ||
        oldDelegate.isPlaying != isPlaying;
  }
}
