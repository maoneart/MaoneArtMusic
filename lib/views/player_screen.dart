import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/maoneart_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/seek_bar.dart';
import '../widgets/app_artwork.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("Tidak ada lagu yang sedang diputar")),
      );
    }

    final isFav = ref.read(libraryProvider).isFavorite(song);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "SEDANG DIPUTAR",
          style: TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.redAccent : Colors.white,
            ),
            onPressed: () {
              ref.read(libraryProvider).toggleFavorite(song);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Ambient Artwork Blur Background
          Positioned.fill(
            child: song.artworkUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: song.artworkUrl,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(color: Colors.black),
                  )
                : Container(color: Colors.black),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                color: Colors.black.withOpacity(0.65),
              ),
            ),
          ),

          // Main Player Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  const Spacer(),

                  // Big Artwork with Glass Glow & Gradient Fallback
                  Hero(
                    tag: 'player_artwork',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: MaoneArtTheme.primaryCyan.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: AppArtwork(
                        artworkUrl: song.artworkUrl,
                        width: MediaQuery.of(context).size.width * 0.78,
                        height: MediaQuery.of(context).size.width * 0.78,
                        borderRadius: 24,
                        iconSize: 80,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Song Title & Artist Info Box
                  GlassContainer(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${song.artist} • ${song.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Seek Bar
                  SeekBar(
                    position: playerState.position,
                    duration: playerState.duration,
                    onChanged: (newPos) {
                      ref.read(playerProvider).seek(newPos);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Audio Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: playerState.isShuffle ? MaoneArtTheme.primaryCyan : Colors.white70,
                        ),
                        onPressed: () => ref.read(playerProvider).toggleShuffle(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous, size: 36, color: Colors.white),
                        onPressed: () => ref.read(playerProvider).previous(),
                      ),

                      // Play/Pause/Loading Button
                      GestureDetector(
                        onTap: () => ref.read(playerProvider).togglePlayPause(),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [MaoneArtTheme.primaryCyan, MaoneArtTheme.primaryPurple],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: MaoneArtTheme.primaryCyan.withOpacity(0.4),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: playerState.status == PlayerLoadingStatus.loading
                              ? const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.black,
                                  ),
                                )
                              : Icon(
                                  playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                                  size: 36,
                                  color: Colors.black,
                                ),
                        ),
                      ),

                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 36, color: Colors.white),
                        onPressed: () => ref.read(playerProvider).next(),
                      ),
                      IconButton(
                        icon: Icon(
                          playerState.repeatMode == RepeatMode.one
                              ? Icons.repeat_one
                              : Icons.repeat,
                          color: playerState.repeatMode != RepeatMode.off
                              ? MaoneArtTheme.primaryCyan
                              : Colors.white70,
                        ),
                        onPressed: () => ref.read(playerProvider).toggleRepeatMode(),
                      ),
                    ],
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
