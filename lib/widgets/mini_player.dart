import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/maoneart_theme.dart';
import '../views/player_screen.dart';
import 'app_artwork.dart';
import 'neon_visualizer.dart';

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
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E242B).withOpacity(0.85),
                    const Color(0xFF101418).withOpacity(0.92),
                  ],
                ),
                border: Border.all(
                  color: playerState.isPlaying
                      ? MaoneArtTheme.primaryCyan.withOpacity(0.35)
                      : Colors.white.withOpacity(0.12),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                  if (playerState.isPlaying)
                    BoxShadow(
                      color: MaoneArtTheme.primaryCyan.withOpacity(0.12),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // Artwork
                        Hero(
                          tag: 'player_artwork',
                          child: AppArtwork(
                            artworkUrl: song.artworkUrl,
                            width: 44,
                            height: 44,
                            borderRadius: 10,
                          ),
                        ),
                        const SizedBox(width: 12),

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
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                  letterSpacing: -0.2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (playerState.isPlaying) ...[
                                    SizedBox(
                                      width: 14,
                                      height: 10,
                                      child: NeonMiniVisualizerStrip(
                                        isPlaying: true,
                                        position: playerState.position,
                                        barCount: 4,
                                        height: 10,
                                        glowColor: MaoneArtTheme.primaryCyan,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: Text(
                                      song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white.withOpacity(0.68),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Favorite Heart Button
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFavorite ? Colors.redAccent : Colors.white60,
                            size: 21,
                          ),
                          onPressed: () {
                            ref.read(libraryProvider).toggleFavorite(song);
                          },
                        ),

                        // Play/Pause Control with sleek round container
                        Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                              width: 0.8,
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: playerState.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(
                                    playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                            onPressed: () {
                              ref.read(playerProvider).togglePlayPause();
                            },
                          ),
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

                  // Bottom Mini Gradient Progress Bar
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 2.5,
                      color: Colors.white.withOpacity(0.08),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [MaoneArtTheme.primaryCyan, MaoneArtTheme.primaryPurple],
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
      ),
    );
  }
}
