import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../theme/maoneart_theme.dart';
import 'glass_container.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;

  const SongTile({
    Key? key,
    required this.song,
    this.isPlaying = false,
    required this.onTap,
    this.onMoreTap,
  }) : super(key: key);

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
      child: GlassContainer(
        borderRadius: 14,
        padding: const EdgeInsets.all(8.0),
        onTap: onTap,
        child: Row(
          children: [
            // Track Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: song.artworkUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.white.withOpacity(0.1),
                  child: const Icon(Icons.music_note, color: Colors.white54),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.white.withOpacity(0.1),
                  child: const Icon(Icons.music_note, color: Colors.white54),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Track Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isPlaying ? MaoneArtTheme.primaryCyan : Colors.white,
                    ),
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

            if (isPlaying)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.equalizer, color: MaoneArtTheme.primaryCyan, size: 22),
              ),

            Text(
              _formatDuration(song.durationSeconds),
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
            ),

            if (onMoreTap != null)
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
                onPressed: onMoreTap,
              ),
          ],
        ),
      ),
    );
  }
}
