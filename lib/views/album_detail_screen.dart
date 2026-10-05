import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/maoneart_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/song_tile.dart';
import '../widgets/playlist_picker_modal.dart';
import '../services/youtube_audio_extractor.dart';
import 'player_screen.dart';

class AlbumDetailScreen extends ConsumerStatefulWidget {
  final Album album;

  const AlbumDetailScreen({Key? key, required this.album}) : super(key: key);

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  List<Song> _tracks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tracks = await ref.read(musicProvider).getAlbumTracks(widget.album);
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
        });

        // Pre-fetch 3 lagu pertama album di background untuk pemutaran instan 0ms
        if (_tracks.isNotEmpty) {
          YoutubeAudioExtractor.preFetchBatch(_tracks, limit: 3);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Gagal memuat lagu dalam album. Coba lagi.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final libraryState = ref.watch(libraryProvider);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Glassmorphic Sliver App Bar with Big Album Artwork
          SliverAppBar(
            expandedHeight: isLandscape ? 200 : 320,
            pinned: true,
            backgroundColor: MaoneArtTheme.bgDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.album.artworkUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: Colors.black54),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.3),
                          MaoneArtTheme.bgDark.withOpacity(0.85),
                          MaoneArtTheme.bgDark,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 48,
                    left: 20,
                    right: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: widget.album.artworkUrl,
                            width: isLandscape ? 70 : 100,
                            height: isLandscape ? 70 : 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: MaoneArtTheme.spotifyGreen.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.album.type.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: MaoneArtTheme.spotifyGreenBright,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.album.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.album.artist + (widget.album.year != null ? " • ${widget.album.year}" : ""),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons: Play All & Shuffle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MaoneArtTheme.spotifyGreenBright,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                      label: Text(
                        _isLoading ? "Memuat..." : "Putar Semua (${_tracks.length})",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: _tracks.isEmpty
                          ? null
                          : () {
                              ref.read(playerProvider).playSong(
                                    _tracks.first,
                                    newQueue: _tracks,
                                    index: 0,
                                  );
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const PlayerScreen()),
                              );
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.12),
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: const Icon(Icons.shuffle_rounded, color: Colors.white),
                    onPressed: _tracks.isEmpty
                        ? null
                        : () {
                            final shuffled = List<Song>.from(_tracks)..shuffle();
                            ref.read(playerProvider).playSong(
                                  shuffled.first,
                                  newQueue: shuffled,
                                  index: 0,
                                );
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const PlayerScreen()),
                            );
                          },
                  ),
                ],
              ),
            ),
          ),

          // Content State (Loading, Error, or Tracks List)
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: MaoneArtTheme.primaryCyan),
                    SizedBox(height: 14),
                    Text("Memuat daftar lagu album...", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: MaoneArtTheme.spotifyGreen),
                      onPressed: _loadTracks,
                      child: const Text("Coba Lagi", style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
              ),
            )
          else if (_tracks.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text("Tidak ada lagu di album ini", style: TextStyle(color: Colors.white54)),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.only(bottom: isLandscape ? 85 : 140),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = _tracks[index];
                    final isPlaying = playerState.currentSong?.id == song.id;
                    final isFav = libraryState.isFavorite(song);

                    return SongTile(
                      song: song,
                      rank: index + 1,
                      isPlaying: isPlaying,
                      isFavorite: isFav,
                      onFavoriteTap: () {
                        ref.read(libraryProvider).toggleFavorite(song);
                      },
                      onPlaylistTap: () {
                        PlaylistPickerModal.show(context, ref, song);
                      },
                      onTap: () {
                        ref.read(playerProvider).playSong(
                              song,
                              newQueue: _tracks,
                              index: index,
                            );
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const PlayerScreen()),
                        );
                      },
                    );
                  },
                  childCount: _tracks.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
