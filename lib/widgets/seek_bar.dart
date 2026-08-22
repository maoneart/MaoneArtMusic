import 'package:flutter/material.dart';
import '../theme/maoneart_theme.dart';

class SeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration>? onChanged;

  const SeekBar({
    Key? key,
    required this.position,
    required this.duration,
    this.onChanged,
  }) : super(key: key);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final double maxSec = duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1.0;
    final double currentSec = position.inSeconds.toDouble().clamp(0.0, maxSec);

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: MaoneArtTheme.primaryCyan,
            inactiveTrackColor: Colors.white.withOpacity(0.2),
            thumbColor: MaoneArtTheme.primaryCyan,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayColor: MaoneArtTheme.primaryCyan.withOpacity(0.2),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            min: 0.0,
            max: maxSec,
            value: currentSec,
            onChanged: (val) {
              if (onChanged != null) {
                onChanged!(Duration(seconds: val.round()));
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
              ),
              Text(
                _formatDuration(duration),
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
