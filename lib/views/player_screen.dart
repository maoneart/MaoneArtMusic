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
import '../widgets/equalizer_modal.dart';
import '../widgets/neon_visualizer.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _showLyrics = false;
  bool _showQueue = false;
  bool _showVisualizer = false;

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

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: isLandscape ? 44.0 : kToolbarHeight,
        leading: IconButton(
          icon: Icon(Icons.keyboard_arrow_down, size: isLandscape ? 28 : 32, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: isLandscape
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "SEDANG DIPUTAR",
                    style: TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold),
                  ),
                  if (playerState.isPlayingOffline) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: MaoneArtTheme.spotifyGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.5), width: 0.8),
                      ),
                      child: const Text(
                        "⚡ OFFLINE",
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: MaoneArtTheme.spotifyGreenBright),
                      ),
                    ),
                  ],
                  if (playerState.isKaraokeMode) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: MaoneArtTheme.spotifyGreen.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.6), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic, size: 9, color: MaoneArtTheme.spotifyGreenBright),
                          SizedBox(width: 2),
                          Text(
                            "KARAOKE ON",
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: MaoneArtTheme.spotifyGreenBright),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              )
            : Column(
                children: [
                  const Text(
                    "SEDANG DIPUTAR",
                    style: TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold),
                  ),
                  if (playerState.isKaraokeMode)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: MaoneArtTheme.spotifyGreen.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.6), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic, size: 9, color: MaoneArtTheme.spotifyGreenBright),
                          SizedBox(width: 2),
                          Text(
                            "KARAOKE ON (MINUS-ONE)",
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: MaoneArtTheme.spotifyGreenBright),
                          ),
                        ],
                      ),
                    )
                  else if (playerState.isPlayingOffline)
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
              Icons.graphic_eq_rounded,
              color: _showVisualizer ? MaoneArtTheme.primaryCyan : Colors.white70,
              size: isLandscape ? 22 : 24,
            ),
            tooltip: "Neon Visualizer",
            onPressed: () {
              setState(() {
                _showVisualizer = !_showVisualizer;
                _showLyrics = false;
                _showQueue = false;
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: playerState.isEqualizerEnabled ? MaoneArtTheme.primaryCyan : Colors.white70,
              size: isLandscape ? 22 : 24,
            ),
            tooltip: "Equalizer & Efek Suara",
            onPressed: () => showEqualizerModal(context),
          ),
          IconButton(
            icon: Icon(
              Icons.lyrics_outlined,
              color: _showLyrics ? MaoneArtTheme.primaryCyan : Colors.white70,
              size: isLandscape ? 22 : 24,
            ),
            tooltip: "Lirik",
            onPressed: () {
              setState(() {
                _showLyrics = !_showLyrics;
                _showQueue = false;
                _showVisualizer = false;
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.queue_music,
              color: _showQueue ? MaoneArtTheme.primaryCyan : Colors.white70,
              size: isLandscape ? 22 : 24,
            ),
            tooltip: "Antrean",
            onPressed: () {
              setState(() {
                _showQueue = !_showQueue;
                _showLyrics = false;
                _showVisualizer = false;
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
            child: isLandscape
                ? _buildLandscapeContent(context, playerState, song)
                : _buildPortraitContent(context, playerState, song),
          ),
        ],
      ),
    );
  }

  // --- PORTRAIT CONTENT ---
  Widget _buildPortraitContent(BuildContext context, PlayerStateNotifier playerState, dynamic song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        children: [
          Expanded(
            child: _showVisualizer
                ? _buildVisualizerView(context, playerState, song)
                : _showLyrics
                    ? _buildLyricsView(playerState)
                    : _showQueue
                        ? _buildQueueView(playerState)
                        : _buildMainArtwork(context, song),
          ),

          const SizedBox(height: 12),

          // Song Title & Artist Info Box with Star/Playlist, Offline Download & Favorite
          GlassContainer(
            borderRadius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1.0,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.14),
                Colors.white.withOpacity(0.05),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
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
                          fontSize: 18.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
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
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.72),
                        ),
                      ),
                    ],
                  ),
                ),

                // Offline Download Button
                _buildOfflineDownloadButton(song),

                // Add to Playlist (Star Button)
                _buildStarPlaylistButton(song),

                // Favorite Heart Button
                _buildFavoriteButton(song),

                if (playerState.errorMessage != null) _buildRetryButton(song),
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

          // Audio Controls with tactile play button and glowing states
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: playerState.isShuffle
                      ? MaoneArtTheme.primaryCyan.withOpacity(0.15)
                      : Colors.transparent,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: playerState.isShuffle ? MaoneArtTheme.primaryCyan : Colors.white70,
                    size: 24,
                  ),
                  tooltip: "Acak",
                  onPressed: () => ref.read(playerProvider).toggleShuffle(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, size: 38, color: Colors.white),
                tooltip: "Sebelumnya",
                onPressed: () => ref.read(playerProvider).previous(),
              ),

              // Animated Play/Pause Button
              _AnimatedPlayButton(
                size: 68,
                isLoading: playerState.isLoading,
                isPlaying: playerState.isPlaying,
                onTap: () => ref.read(playerProvider).togglePlayPause(),
              ),

              IconButton(
                icon: const Icon(Icons.skip_next_rounded, size: 38, color: Colors.white),
                tooltip: "Berikutnya",
                onPressed: () => ref.read(playerProvider).next(),
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: playerState.repeatMode != MusicRepeatMode.off
                      ? MaoneArtTheme.primaryCyan.withOpacity(0.15)
                      : Colors.transparent,
                ),
                child: IconButton(
                  icon: Icon(
                    playerState.repeatMode == MusicRepeatMode.one
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded,
                    color: playerState.repeatMode != MusicRepeatMode.off
                        ? MaoneArtTheme.primaryCyan
                        : Colors.white70,
                    size: 24,
                  ),
                  tooltip: "Ulangi",
                  onPressed: () => ref.read(playerProvider).toggleRepeatMode(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // --- LANDSCAPE CONTENT (SIDE-BY-SIDE) ---
  Widget _buildLandscapeContent(BuildContext context, PlayerStateNotifier playerState, dynamic song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Column
          Expanded(
            flex: 5,
            child: _showLyrics || _showQueue || _showVisualizer
                ? _buildLandscapeMiniControls(context, playerState, song)
                : _buildLandscapeMainArtwork(context, song),
          ),
          const SizedBox(width: 16),
          // Right Column
          Expanded(
            flex: 6,
            child: _showVisualizer
                ? _buildVisualizerView(context, playerState, song)
                : _showLyrics
                    ? _buildLyricsView(playerState)
                    : _showQueue
                        ? _buildQueueView(playerState)
                        : _buildLandscapeControlsPanel(context, playerState, song),
          ),
        ],
      ),
    );
  }

  // Landscape Right Side Controls Panel
  Widget _buildLandscapeControlsPanel(BuildContext context, PlayerStateNotifier playerState, dynamic song) {
    return GlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Song Title, Artist & Action Icons
          Row(
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
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${song.artist} • ${song.album}',
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
              _buildOfflineDownloadButton(song),
              _buildStarPlaylistButton(song),
              _buildFavoriteButton(song),
              if (playerState.errorMessage != null) _buildRetryButton(song),
            ],
          ),

          // Seek Bar
          SeekBar(
            position: playerState.position,
            duration: playerState.duration,
            onChanged: (newPos) {
              ref.read(playerProvider).seek(newPos);
            },
          ),

          // Audio Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: playerState.isShuffle
                      ? MaoneArtTheme.primaryCyan.withOpacity(0.15)
                      : Colors.transparent,
                ),
                child: IconButton(
                  iconSize: 22,
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: playerState.isShuffle ? MaoneArtTheme.primaryCyan : Colors.white70,
                  ),
                  tooltip: "Acak",
                  onPressed: () => ref.read(playerProvider).toggleShuffle(),
                ),
              ),
              IconButton(
                iconSize: 34,
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                tooltip: "Sebelumnya",
                onPressed: () => ref.read(playerProvider).previous(),
              ),

              // Animated Play/Pause Button
              _AnimatedPlayButton(
                size: 56,
                isLoading: playerState.isLoading,
                isPlaying: playerState.isPlaying,
                onTap: () => ref.read(playerProvider).togglePlayPause(),
              ),

              IconButton(
                iconSize: 34,
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                tooltip: "Berikutnya",
                onPressed: () => ref.read(playerProvider).next(),
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: playerState.repeatMode != MusicRepeatMode.off
                      ? MaoneArtTheme.primaryCyan.withOpacity(0.15)
                      : Colors.transparent,
                ),
                child: IconButton(
                  iconSize: 22,
                  icon: Icon(
                    playerState.repeatMode == MusicRepeatMode.one
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded,
                    color: playerState.repeatMode != MusicRepeatMode.off
                        ? MaoneArtTheme.primaryCyan
                        : Colors.white70,
                  ),
                  tooltip: "Ulangi",
                  onPressed: () => ref.read(playerProvider).toggleRepeatMode(),
                ),
              ),
            ],
          ),

          // Hi-Fi Audio & Smart Cache Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.graphic_eq_rounded, size: 12, color: MaoneArtTheme.primaryCyan),
                    const SizedBox(width: 4),
                    Text(
                      "YouTube Music • 320kbps",
                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: MaoneArtTheme.spotifyGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.3), width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 12, color: MaoneArtTheme.spotifyGreenBright),
                    SizedBox(width: 4),
                    Text(
                      "Auto-Cache 0s Delay",
                      style: TextStyle(fontSize: 10, color: MaoneArtTheme.spotifyGreenBright, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Landscape Mini Controls (shown on left when Lyrics or Queue is active on the right)
  Widget _buildLandscapeMiniControls(BuildContext context, PlayerStateNotifier playerState, dynamic song) {
    return GlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              Hero(
                tag: 'player_artwork',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: MaoneArtTheme.primaryCyan.withOpacity(0.25),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: AppArtwork(
                    artworkUrl: song.artworkUrl,
                    width: 52,
                    height: 52,
                    borderRadius: 12,
                    iconSize: 26,
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
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
              _buildFavoriteButton(song),
            ],
          ),

          SeekBar(
            position: playerState.position,
            duration: playerState.duration,
            onChanged: (newPos) {
              ref.read(playerProvider).seek(newPos);
            },
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                iconSize: 20,
                icon: Icon(
                  Icons.shuffle,
                  color: playerState.isShuffle ? MaoneArtTheme.primaryCyan : Colors.white70,
                ),
                onPressed: () => ref.read(playerProvider).toggleShuffle(),
              ),
              IconButton(
                iconSize: 28,
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: () => ref.read(playerProvider).previous(),
              ),
              GestureDetector(
                onTap: () => ref.read(playerProvider).togglePlayPause(),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [MaoneArtTheme.primaryCyan, MaoneArtTheme.primaryPurple],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MaoneArtTheme.primaryCyan.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: playerState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : Icon(
                          playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 28,
                          color: Colors.black,
                        ),
                ),
              ),
              IconButton(
                iconSize: 28,
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: () => ref.read(playerProvider).next(),
              ),
              IconButton(
                iconSize: 20,
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

          SizedBox(
            width: double.infinity,
            height: 30,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.album_outlined, size: 15, color: Colors.white70),
              label: Text(
                _showLyrics ? "Tutup Lirik • Tampilkan Cover" : "Tutup Antrean • Tampilkan Cover",
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
              onPressed: () {
                setState(() {
                  _showLyrics = false;
                  _showQueue = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeMainArtwork(BuildContext context, dynamic song) {
    final availableHeight = MediaQuery.of(context).size.height - 85;
    final size = availableHeight.clamp(140.0, 260.0);

    return Center(
      child: Hero(
        tag: 'player_artwork',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: MaoneArtTheme.primaryCyan.withOpacity(0.35),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: AppArtwork(
            artworkUrl: song.artworkUrl,
            width: size,
            height: size,
            borderRadius: 24,
            iconSize: 68,
          ),
        ),
      ),
    );
  }

  // --- REUSABLE ACTION BUTTONS ---
  Widget _buildOfflineDownloadButton(dynamic song) {
    return Consumer(
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
    );
  }

  Widget _buildStarPlaylistButton(dynamic song) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: const EdgeInsets.all(4),
      icon: const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 25),
      tooltip: "Tambahkan ke Playlist",
      onPressed: () {
        PlaylistPickerModal.show(context, ref, song);
      },
    );
  }

  Widget _buildFavoriteButton(dynamic song) {
    return Consumer(
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
    );
  }

  Widget _buildRetryButton(dynamic song) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: const EdgeInsets.all(4),
      icon: const Icon(Icons.refresh, color: Colors.amberAccent, size: 24),
      tooltip: "Coba Putar Ulang",
      onPressed: () {
        ref.read(playerProvider).playSong(song);
      },
    );
  }

  Widget _buildMainArtwork(BuildContext context, dynamic song) {
    final playerState = ref.watch(playerProvider);
    final artworkWidth = MediaQuery.of(context).size.width * 0.74;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Hero(
            tag: 'player_artwork',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: MaoneArtTheme.primaryCyan.withOpacity(0.35),
                    blurRadius: 36,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: MaoneArtTheme.primaryPurple.withOpacity(0.25),
                    blurRadius: 48,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: AppArtwork(
                artworkUrl: song.artworkUrl,
                width: artworkWidth,
                height: artworkWidth,
                borderRadius: 26,
                iconSize: 80,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Ambient Neon Visualizer Strip beneath artwork
          SizedBox(
            width: artworkWidth,
            height: 22,
            child: NeonMiniVisualizerStrip(
              isPlaying: playerState.isPlaying,
              position: playerState.position,
              barCount: 22,
              height: 22,
              glowColor: MaoneArtTheme.primaryCyan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizerView(BuildContext context, PlayerStateNotifier playerState, dynamic song) {
    final sessionId = playerState.audioPlayer.androidAudioSessionId ?? 0;
    return NeonVisualizerDeck(
      isPlaying: playerState.isPlaying,
      song: song,
      position: playerState.position,
      sessionId: sessionId,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Karaoke Mode Toggle Pill
                  InkWell(
                    onTap: () async {
                      final success = await ref.read(playerProvider).toggleKaraokeMode();
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF141927),
                            behavior: SnackBarBehavior.floating,
                            content: Text(
                              "❌ Instrumen minus-one tidak ditemukan untuk lagu ini.",
                              style: TextStyle(color: Colors.white),
                            ),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: playerState.isKaraokeMode
                            ? MaoneArtTheme.spotifyGreen.withOpacity(0.25)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: playerState.isKaraokeMode
                              ? MaoneArtTheme.spotifyGreenBright.withOpacity(0.6)
                              : Colors.white24,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (playerState.isSearchingKaraoke)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: MaoneArtTheme.primaryCyan),
                            )
                          else
                            Icon(
                              playerState.isKaraokeMode ? Icons.mic : Icons.mic_none_outlined,
                              color: playerState.isKaraokeMode
                                  ? MaoneArtTheme.spotifyGreenBright
                                  : Colors.white70,
                              size: 14,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            playerState.isKaraokeMode ? "Karaoke ON" : "Karaoke",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: playerState.isKaraokeMode
                                  ? MaoneArtTheme.spotifyGreenBright
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => setState(() => _showLyrics = false),
                  ),
                ],
              ),
            ],
          ),

          // Karaoke Active Banner / Searching Status
          if (playerState.isSearchingKaraoke)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MaoneArtTheme.primaryCyan.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MaoneArtTheme.primaryCyan.withOpacity(0.35), width: 0.8),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: MaoneArtTheme.primaryCyan),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Mencari instrumen minus-one di YouTube...",
                      style: TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          else if (playerState.isKaraokeMode)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MaoneArtTheme.spotifyGreen.withOpacity(0.25),
                    MaoneArtTheme.primaryCyan.withOpacity(0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.5), width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: MaoneArtTheme.spotifyGreenBright, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Mode Karaoke (Minus-One)",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  InkWell(
                    onTap: () => ref.read(playerProvider).toggleKaraokeMode(),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "Vokal Asli",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
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

/// Tactile Animated Play/Pause Button with Smooth Press Feedback & Ambient Neon Glow
class _AnimatedPlayButton extends StatefulWidget {
  final double size;
  final bool isLoading;
  final bool isPlaying;
  final VoidCallback onTap;

  const _AnimatedPlayButton({
    Key? key,
    this.size = 68.0,
    required this.isLoading,
    required this.isPlaying,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_AnimatedPlayButton> createState() => _AnimatedPlayButtonState();
}

class _AnimatedPlayButtonState extends State<_AnimatedPlayButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.size * 0.58;

    return GestureDetector(
      onTapDown: (_) {
        if (mounted) setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        if (mounted) setState(() => _isPressed = false);
      },
      onTapCancel: () {
        if (mounted) setState(() => _isPressed = false);
      },
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MaoneArtTheme.primaryCyan, MaoneArtTheme.primaryPurple],
            ),
            boxShadow: [
              BoxShadow(
                color: MaoneArtTheme.primaryCyan.withOpacity(0.42),
                blurRadius: 22,
                spreadRadius: 3,
                offset: const Offset(0, 4),
              ),
              if (widget.isPlaying)
                BoxShadow(
                  color: MaoneArtTheme.primaryPurple.withOpacity(0.35),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: widget.size * 0.4,
                    height: widget.size * 0.4,
                    child: const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      key: ValueKey<bool>(widget.isPlaying),
                      size: iconSize,
                      color: Colors.black,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
