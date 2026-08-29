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
import '../widgets/playlist_picker_modal.dart';
import '../widgets/synced_lyrics_view.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _showLyrics = false;
  bool _showQueue = false;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("Tidak ada lagu yang sedang diputar")),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            const Text(
              "SEDANG DIPUTAR",
              style: TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold),
            ),
            if (playerState.isPlayingOffline)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: MaoneArtTheme.spotifyGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.5), width: 0.8),
                ),
                child: const Text(
                  "⚡ OFFLINE (0s DELAY)",
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: MaoneArtTheme.spotifyGreenBright),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.lyrics_outlined,
              color: _showLyrics ? MaoneArtTheme.primaryCyan : Colors.white70,
            ),
            tooltip: "Lirik",
            onPressed: () {
              setState(() {
                _showLyrics = !_showLyrics;
                _showQueue = false;
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.queue_music,
              color: _showQueue ? MaoneArtTheme.primaryCyan : Colors.white70,
            ),
            tooltip: "Antrean",
            onPressed: () {
              setState(() {
                _showQueue = !_showQueue;
                _showLyrics = false;
              });
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
                color: Colors.black.withOpacity(0.68),
              ),
            ),
          ),

          // Main Player Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                children: [
                  Expanded(
                    child: _showLyrics
                        ? _buildLyricsView(playerState)
                        : _showQueue
                            ? _buildQueueView(playerState)
                            : _buildMainArtwork(context, song),
                  ),

                  const SizedBox(height: 12),

                  // Song Title & Artist Info Box with Star/Playlist, Offline Download & Favorite
                  GlassContainer(
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
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
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Offline Download Button
                        Consumer(
                          builder: (context, ref, _) {
                            final isOff = ref.watch(libraryProvider).isOffline(song);
                            return IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: const EdgeInsets.all(4),
                              icon: Icon(
                                isOff ? Icons.offline_pin_rounded : Icons.download_for_offline_outlined,
                                color: isOff ? MaoneArtTheme.spotifyGreenBright : Colors.white70,
                                size: 24,
                              ),
                              tooltip: isOff ? "Tersimpan Offline (0s Delay)" : "Simpan Lagu Offline",
                              onPressed: () async {
                                final res = await ref.read(libraryProvider).toggleDownloadSong(song);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(0xFF141927),
                                      behavior: SnackBarBehavior.floating,
                                      content: Text(
                                        res
                                            ? "💾 '${song.title}' berhasil disimpan offline (0s Delay)"
                                            : "🗑️ '${song.title}' dihapus dari offline",
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),

                        // Add to Playlist (Star Button)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: const EdgeInsets.all(4),
                          icon: const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 25),
                          tooltip: "Tambahkan ke Playlist",
                          onPressed: () {
                            PlaylistPickerModal.show(context, ref, song);
                          },
                        ),

                        // Favorite Heart Button
                        Consumer(
                          builder: (context, ref, _) {
                            final isFav = ref.watch(libraryProvider).isFavorite(song);
                            return IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: const EdgeInsets.all(4),
                              icon: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                color: isFav ? Colors.redAccent : Colors.white70,
                                size: 24,
                              ),
                              tooltip: isFav ? "Hapus dari Favorit" : "Tambah ke Favorit",
                              onPressed: () {
                                ref.read(libraryProvider).toggleFavorite(song);
                              },
                            );
                          },
                        ),

                        if (playerState.errorMessage != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: const EdgeInsets.all(4),
                            icon: const Icon(Icons.refresh, color: Colors.amberAccent, size: 24),
                            tooltip: "Coba Putar Ulang",
                            onPressed: () {
                              ref.read(playerProvider).playSong(song);
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Seek Bar
                  SeekBar(
                    position: playerState.position,
                    duration: playerState.duration,
                    onChanged: (newPos) {
                      ref.read(playerProvider).seek(newPos);
                    },
                  ),

                  const SizedBox(height: 12),

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
                          playerState.repeatMode == MusicRepeatMode.one
                              ? Icons.repeat_one
                              : Icons.repeat,
                          color: playerState.repeatMode != MusicRepeatMode.off
                              ? MaoneArtTheme.primaryCyan
                              : Colors.white70,
                        ),
                        onPressed: () => ref.read(playerProvider).toggleRepeatMode(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainArtwork(BuildContext context, dynamic song) {
    return Center(
      child: Hero(
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
            width: MediaQuery.of(context).size.width * 0.76,
            height: MediaQuery.of(context).size.width * 0.76,
            borderRadius: 24,
            iconSize: 80,
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsView(PlayerStateNotifier playerState) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    "Lirik Lagu",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MaoneArtTheme.primaryCyan),
                  ),
                  if (playerState.isSyncedLyrics) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: MaoneArtTheme.primaryCyan.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "SINKRON OTOMATIS",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: MaoneArtTheme.primaryCyan),
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: () => setState(() => _showLyrics = false),
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: SyncedLyricsView(
              lyrics: playerState.parsedLyrics,
              plainLyrics: playerState.plainLyrics ?? playerState.currentLyrics,
              currentPosition: playerState.position,
              onSeek: (pos) => ref.read(playerProvider).seek(pos),
              isLoading: playerState.isLoadingLyrics,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueView(PlayerStateNotifier playerState) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Daftar Antrean (${playerState.queue.length})",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MaoneArtTheme.primaryCyan),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: () => setState(() => _showQueue = false),
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: ListView.builder(
              itemCount: playerState.queue.length,
              itemBuilder: (context, index) {
                final song = playerState.queue[index];
                final isCurrent = playerState.currentIndex == index;
                return ListTile(
                  dense: true,
                  leading: isCurrent
                      ? const Icon(Icons.volume_up, color: MaoneArtTheme.spotifyGreenBright)
                      : Text("${index + 1}", style: const TextStyle(color: Colors.white54)),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? MaoneArtTheme.spotifyGreenBright : Colors.white,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () {
                    ref.read(playerProvider).playSong(song, index: index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
