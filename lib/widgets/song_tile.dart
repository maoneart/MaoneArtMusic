import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../theme/maoneart_theme.dart';
import 'glass_container.dart';
import 'app_artwork.dart';

class SongTile extends ConsumerWidget {
  final Song song;
  final bool isPlaying;
  final int? rank;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onPlaylistTap;
  final VoidCallback? onMoreTap;

  const SongTile({
    Key? key,
    required this.song,
    this.isPlaying = false,
    this.rank,
    this.isFavorite = false,
    required this.onTap,
    this.onFavoriteTap,
    this.onPlaylistTap,
    this.onMoreTap,
  }) : super(key: key);

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color _getRankColor(int r) {
    if (r == 1) return const Color(0xFFFFD700); // Gold
    if (r == 2) return const Color(0xFFC0C0C0); // Silver
    if (r == 3) return const Color(0xFFCD7F32); // Bronze
    return Colors.white.withOpacity(0.5);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(libraryProvider).isOffline(song);

    final activeBorder = isPlaying
        ? Border.all(color: MaoneArtTheme.primaryCyan.withOpacity(0.55), width: 1.2)
        : Border.all(color: Colors.white.withOpacity(0.12), width: 0.9);

    final activeGradient = isPlaying
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MaoneArtTheme.primaryCyan.withOpacity(0.18),
              MaoneArtTheme.primaryPurple.withOpacity(0.08),
            ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.11),
              Colors.white.withOpacity(0.04),
            ],
          );

    final activeShadow = isPlaying
        ? [
            BoxShadow(
              color: MaoneArtTheme.primaryCyan.withOpacity(0.22),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5, horizontal: 14.0),
      child: GlassContainer(
        borderRadius: 16,
        padding: const EdgeInsets.all(9.0),
        border: activeBorder,
        gradient: activeGradient,
        boxShadow: activeShadow,
        onTap: onTap,
        child: Row(
          children: [
            // Rank Number Badge (Spotify style)
            if (rank != null) ...[
              SizedBox(
                width: 30,
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: rank! <= 3 ? 15 : 13.5,
                      fontWeight: rank! <= 3 ? FontWeight.w800 : FontWeight.w600,
                      color: _getRankColor(rank!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Track Artwork with Animated Dancing Equalizer Overlay
            Stack(
              children: [
                AppArtwork(
                  artworkUrl: song.artworkUrl,
                  width: 52,
                  height: 52,
                  borderRadius: 12,
                ),
                if (isPlaying)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.48),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MaoneArtTheme.primaryCyan.withOpacity(0.4),
                          width: 0.8,
                        ),
                      ),
                      child: const Center(
                        child: _PlayingAnimatedBars(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 13),

            // Track Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (isOffline) ...[
                        const Icon(
                          Icons.offline_pin_rounded,
                          color: MaoneArtTheme.spotifyGreenBright,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                            color: isPlaying ? MaoneArtTheme.primaryCyan : Colors.white,
                          ),
                        ),
                      ),
                      if (rank != null && rank! <= 3)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: MaoneArtTheme.spotifyGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: MaoneArtTheme.spotifyGreen.withOpacity(0.4), width: 0.8),
                          ),
                          child: const Text(
                            "🔥 HOT",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: MaoneArtTheme.spotifyGreenBright,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${song.artist} • ${song.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w400,
                      color: isPlaying ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            if (onPlaylistTap != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(4),
                icon: const Icon(
                  Icons.star_border_rounded,
                  color: Colors.amberAccent,
                  size: 20,
                ),
                tooltip: "Tambah ke Playlist",
                onPressed: onPlaylistTap,
              ),

            if (onFavoriteTap != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(4),
                icon: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFavorite ? Colors.redAccent : Colors.white54,
                  size: 19,
                ),
                onPressed: onFavoriteTap,
              ),

            Container(
              margin: const EdgeInsets.only(left: 2, right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatDuration(song.durationSeconds),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ),

            if (onMoreTap != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
                padding: const EdgeInsets.all(2),
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 18),
                onPressed: onMoreTap,
              ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight Animated Neon Equalizer Bars for Playing Song Artwork Overlay
class _PlayingAnimatedBars extends StatefulWidget {
  const _PlayingAnimatedBars({Key? key}) : super(key: key);

  @override
  State<_PlayingAnimatedBars> createState() => _PlayingAnimatedBarsState();
}

class _PlayingAnimatedBarsState extends State<_PlayingAnimatedBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
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
      builder: (context, _) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(9 + val * 11),
            const SizedBox(width: 3),
            _bar(19 - val * 9),
            const SizedBox(width: 3),
            _bar(7 + val * 13),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 3.5,
      height: height.clamp(4.0, 20.0),
      decoration: BoxDecoration(
        color: MaoneArtTheme.primaryCyan,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: MaoneArtTheme.primaryCyan.withOpacity(0.8),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
