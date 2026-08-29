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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
      child: GlassContainer(
        borderRadius: 14,
        padding: const EdgeInsets.all(8.0),
        onTap: onTap,
        child: Row(
          children: [
            // Rank Number Badge (Spotify style)
            if (rank != null) ...[
              SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: rank! <= 3 ? 16 : 14,
                      fontWeight: rank! <= 3 ? FontWeight.w900 : FontWeight.w600,
                      color: _getRankColor(rank!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Track Artwork with Playing Indicator Overlay
            Stack(
              children: [
                AppArtwork(
                  artworkUrl: song.artworkUrl,
                  width: 52,
                  height: 52,
                  borderRadius: 10,
                ),
                if (isPlaying)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.bar_chart_rounded, color: MaoneArtTheme.spotifyGreenBright, size: 26),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Track Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isPlaying ? MaoneArtTheme.spotifyGreenBright : Colors.white,
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
                  const SizedBox(height: 4),
                  Text(
                    '${song.artist} • ${song.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
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
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.redAccent : Colors.white54,
                  size: 19,
                ),
                onPressed: onFavoriteTap,
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                _formatDuration(song.durationSeconds),
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
              ),
            ),

            if (onMoreTap != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
                padding: const EdgeInsets.all(2),
                icon: const Icon(Icons.more_vert, color: Colors.white70, size: 18),
                onPressed: onMoreTap,
              ),
          ],
        ),
      ),
    );
  }
}
