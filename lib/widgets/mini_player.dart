import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../theme/maoneart_theme.dart';
import '../views/player_screen.dart';
import 'glass_container.dart';
import 'app_artwork.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;

    if (song == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GlassContainer(
        borderRadius: 20,
        blur: 25,
        opacity: 0.2,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const PlayerScreen()),
          );
        },
        child: Row(
          children: [
            // Artwork
            Hero(
              tag: 'player_artwork',
              child: AppArtwork(
                artworkUrl: song.artworkUrl,
                width: 46,
                height: 46,
                borderRadius: 12,
              ),
            ),
            const SizedBox(width: 12),

            // Title & Artist
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Controls
            if (playerState.status == PlayerLoadingStatus.loading)
              const Padding(
                padding: EdgeInsets.all(10.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MaoneArtTheme.primaryCyan,
                  ),
                ),
              )
            else
              IconButton(
                icon: Icon(
                  playerState.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: MaoneArtTheme.primaryCyan,
                  size: 36,
                ),
                onPressed: () {
                  ref.read(playerProvider).togglePlayPause();
                },
              ),

            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
              onPressed: () {
                ref.read(playerProvider).next();
              },
            ),
          ],
        ),
      ),
    );
  }
}
