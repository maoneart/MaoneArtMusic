import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/artist.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../services/music_service.dart';
import '../services/youtube_audio_extractor.dart';
import '../theme/maoneart_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/song_tile.dart';
import '../widgets/playlist_picker_modal.dart';
import 'player_screen.dart';

class ArtistProfileScreen extends ConsumerStatefulWidget {
  final Artist artist;

  const ArtistProfileScreen({Key? key, required this.artist}) : super(key: key);

  @override
  ConsumerState<ArtistProfileScreen> createState() => _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends ConsumerState<ArtistProfileScreen> {
  final MusicService _musicService = MusicService();
  bool _isLoading = true;
  List<Song> _songs = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchArtistSongs();
  }

  Future<void> _fetchArtistSongs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _musicService.getArtistTopSongs(
        widget.artist.id,
        widget.artist.name,
        limit: 50,
      );

      if (mounted) {
        setState(() {
          _songs = results;
          _isLoading = false;
        });

        // Pre-fetch top 3 lagu artis di background agar klik lagu langsung play 0ms
        if (_songs.isNotEmpty) {
          YoutubeAudioExtractor.preFetchBatch(_songs, limit: 3);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Musify-Style App Bar with Artist Artwork & Verified Badge
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: MaoneArtTheme.bgDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MaoneArtTheme.spotifyGreen.withOpacity(0.25),
                      MaoneArtTheme.bgDark,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      // Large Circular Artist Avatar
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: MaoneArtTheme.spotifyGreen.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                          border: Border.all(
                            color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: widget.artist.avatarUrl != null &&
                                  widget.artist.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  widget.artist.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _fallbackAvatar(),
                                )
                              : _fallbackAvatar(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Artist Name
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.artist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (widget.artist.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              color: MaoneArtTheme.spotifyGreenBright,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Subtitle / Monthly Listeners
                      Text(
                        widget.artist.subtitle ?? 'Artis Resmi',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Playback Action Buttons & Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Buttons: Putar Semua & Putar Acak (Simetris 2-Kolom Grid)
                  if (_songs.isNotEmpty)
                    Row(
                      children: [
                        // Tombol Putar Semua
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              ref.read(playerProvider).playSong(
                                    _songs.first,
                                    newQueue: _songs,
                                    index: 0,
                                  );
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const PlayerScreen()),
                              );
                            },
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    MaoneArtTheme.spotifyGreen,
                                    MaoneArtTheme.spotifyGreenBright,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                                  SizedBox(width: 6),
                                  Text(
                                    "PUTAR SEMUA",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Tombol Putar Acak
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              final shuffled = List<Song>.from(_songs)..shuffle();
                              ref.read(playerProvider).playSong(
                                    shuffled.first,
                                    newQueue: shuffled,
                                    index: 0,
                                  );
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const PlayerScreen()),
                              );
                            },
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.2,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shuffle_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 6),
                                  Text(
                                    "PUTAR ACAK",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Section Title: Lagu Resmi Terpopuler
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.music_note_rounded,
                              color: MaoneArtTheme.spotifyGreenBright, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            "Lagu Resmi Terpopuler",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (_songs.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              "(${_songs.length})",
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),

          // 3. Songs List
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: MaoneArtTheme.spotifyGreenBright),
              ),
            )
          else if (_songs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_off_rounded, size: 48, color: Colors.white.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage ?? "Tidak ada lagu ditemukan untuk ${widget.artist.name}",
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _fetchArtistSongs,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Coba Lagi"),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: isLandscape ? 85 : 160,
                left: 8,
                right: 8,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = _songs[index];
                    final isPlaying = playerState.currentSong?.id == song.id;
                    final isFav = ref.watch(libraryProvider).isFavorite(song);

                    return SongTile(
                      key: ValueKey(song.id),
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
                              newQueue: _songs,
                              index: index,
                            );
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const PlayerScreen()),
                        );
                      },
                    );
                  },
                  childCount: _songs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: MaoneArtTheme.bgDark,
      child: const Icon(
        Icons.person_rounded,
        color: MaoneArtTheme.spotifyGreenBright,
        size: 50,
      ),
    );
  }
}
