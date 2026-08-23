import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/maoneart_theme.dart';
import '../views/player_screen.dart';
import 'app_artwork.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;

    if (song == null) return const SizedBox.shrink();

    final libraryState = ref.watch(libraryProvider);
    final isFavorite = libraryState.isFavorite(song);

    final double progress = (playerState.duration.inMilliseconds > 0)
        ? (playerState.position.inMilliseconds / playerState.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const PlayerScreen()),
          );
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -200) {
              ref.read(playerProvider).next();
            } else if (details.primaryVelocity! > 200) {
              ref.read(playerProvider).previous();
            }
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [Color(0xFF242A2F), Color(0xFF14191D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      // Artwork
                      Hero(
                        tag: 'player_artwork',
                        child: AppArtwork(
                          artworkUrl: song.artworkUrl,
                          width: 40,
                          height: 40,
                          borderRadius: 6,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Title & Artist (Spotify Style)
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
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.65),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Favorite Heart Button
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? MaoneArtTheme.spotifyGreenBright : Colors.white60,
                          size: 22,
                        ),
                        onPressed: () {
                          ref.read(libraryProvider).toggleFavorite(song);
                        },
                      ),

                      // Play/Pause Control
                      if (playerState.status == PlayerLoadingStatus.loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: MaoneArtTheme.spotifyGreenBright,
                            ),
                          ),
                        )
                      else
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: () {
                            ref.read(playerProvider).togglePlayPause();
                          },
                        ),

                      // Next Track Control
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.skip_next_rounded, color: Colors.white70, size: 26),
                        onPressed: () {
                          ref.read(playerProvider).next();
                        },
                      ),
                    ],
                  ),
                ),

                // Spotify Bottom Mini Progress Bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 2.0,
                    color: Colors.white.withOpacity(0.12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [MaoneArtTheme.spotifyGreenBright, MaoneArtTheme.primaryCyan],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
