import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/maoneart_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/song_tile.dart';
import '../widgets/playlist_picker_modal.dart';
import '../models/song.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../widgets/artist_bar.dart';
import 'artist_profile_screen.dart';
import 'album_detail_screen.dart';
import 'player_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTab = 'Semua'; // 'Semua', 'Lagu', 'Album', 'Artis'

  final List<String> _quickCategories = [
    'Indonesian Hits',
    'Pop Terpopuler',
    'Lo-Fi Chill',
    'Anime OST',
    'Rock Classics',
    'K-Pop Top 50',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerSearch(String query) {
    final clean = query.replaceAll('*', '').trim();
    _searchController.text = clean;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: clean.length),
    );
    setState(() {
      _selectedTab = 'Semua';
    });
    ref.read(musicProvider).search(clean);
  }

  Widget _buildAlbumCard(BuildContext context, Album album, {double size = 135}) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AlbumDetailScreen(album: album),
          ),
        );
      },
      child: Container(
        width: size,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: album.artworkUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: size,
                      height: size,
                      color: Colors.white12,
                      child: const Icon(Icons.album_rounded, color: Colors.white38, size: 36),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        album.type.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: MaoneArtTheme.spotifyGreenBright,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              album.artist + (album.year != null ? " • ${album.year}" : ""),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final musicState = ref.watch(musicProvider);
    final playerState = ref.watch(playerProvider);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Glass Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        _searchController.clear();
                        ref.read(musicProvider).clearSearch();
                      }
                    },
                  ),
                  Expanded(
                    child: GlassContainer(
                      borderRadius: 16,
                      opacity: 0.15,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _searchController,
                        autofocus: false,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Cari lagu, artis, atau album...",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          border: InputBorder.none,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white70),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(musicProvider).clearSearch();
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          final clean = val.replaceAll('*', '');
                          ref.read(musicProvider).onSearchQueryChanged(clean);
                        },
                        onSubmitted: (val) {
                          FocusScope.of(context).unfocus();
                          _triggerSearch(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Live Autocomplete Suggestions (As user types)
            if (musicState.suggestions.isNotEmpty && _searchController.text.isNotEmpty)
              Container(
                height: 42,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: musicState.suggestions.length,
                  itemBuilder: (context, index) {
                    final sug = musicState.suggestions[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        avatar: const Icon(Icons.search, size: 16, color: MaoneArtTheme.spotifyGreenBright),
                        backgroundColor: MaoneArtTheme.bgDark.withOpacity(0.8),
                        side: BorderSide(color: MaoneArtTheme.spotifyGreen.withOpacity(0.4)),
                        label: Text(
                          sug,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _triggerSearch(sug);
                        },
                      ),
                    );
                  },
                ),
              ),

            // Tab Filter Chips (Semua | Lagu | Album | Artis)
            if (_searchController.text.isNotEmpty && !musicState.isSearching)
              Container(
                height: 38,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildFilterChip('Semua'),
                    _buildFilterChip('Lagu', count: musicState.searchResults.length),
                    _buildFilterChip('Album', count: musicState.searchedAlbums.length),
                    _buildFilterChip('Artis', count: musicState.searchedArtists.length),
                  ],
                ),
              ),

            // Quick Trending Pills (when search is empty)
            if (_searchController.text.isEmpty)
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _quickCategories.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        backgroundColor: Colors.white.withOpacity(0.08),
                        side: BorderSide(color: Colors.white.withOpacity(0.16)),
                        label: Text(
                          cat,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _triggerSearch(cat);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Results List
            Expanded(
              child: Builder(
                builder: (context) {
                  if (musicState.isSearching) {
                    return const Center(
                      child: CircularProgressIndicator(color: MaoneArtTheme.primaryCyan),
                    );
                  }
                  if (_searchController.text.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_rounded, size: 56, color: Colors.white.withOpacity(0.18)),
                          const SizedBox(height: 12),
                          const Text(
                            "Cari Lagu, Artis, atau Album",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Ketik nama lagu atau judul album untuk hasil musik instan",
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35)),
                          ),
                        ],
                      ),
                    );
                  }

                  final hasAny = musicState.searchResults.isNotEmpty ||
                      musicState.searchedAlbums.isNotEmpty ||
                      musicState.searchedArtists.isNotEmpty;

                  if (!hasAny) {
                    return Center(
                      child: Text(
                        "Tidak ada hasil untuk '${_searchController.text}'",
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    );
                  }

                  // Render based on selected tab
                  if (_selectedTab == 'Album') {
                    return _buildAlbumsOnlyView(musicState, isLandscape);
                  } else if (_selectedTab == 'Lagu') {
                    return _buildSongsOnlyView(musicState, playerState, isLandscape);
                  } else if (_selectedTab == 'Artis') {
                    return _buildArtistsOnlyView(musicState, isLandscape);
                  }

                  // Default: 'Semua' tab
                  return _buildUnifiedView(musicState, playerState, isLandscape);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String title, {int? count}) {
    final isSelected = _selectedTab == title;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        backgroundColor: Colors.white.withOpacity(0.08),
        selectedColor: MaoneArtTheme.spotifyGreenBright,
        side: BorderSide(
          color: isSelected ? MaoneArtTheme.spotifyGreenBright : Colors.white.withOpacity(0.16),
        ),
        label: Text(
          count != null && count > 0 ? "$title ($count)" : title,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        onSelected: (_) {
          setState(() {
            _selectedTab = title;
          });
        },
      ),
    );
  }

  Widget _buildUnifiedView(
    dynamic musicState,
    dynamic playerState,
    bool isLandscape,
  ) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: isLandscape ? 85 : 160, top: 4),
      children: [
        // 1. Artis Spotlight
        if (musicState.searchedArtists.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, color: MaoneArtTheme.spotifyGreenBright, size: 18),
                SizedBox(width: 8),
                Text(
                  "Artis",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          ...musicState.searchedArtists.take(2).map((artist) => ArtistBar(
                artist: artist,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => ArtistProfileScreen(artist: artist)),
                  );
                },
                onPlayTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => ArtistProfileScreen(artist: artist)),
                  );
                },
              )),
          const SizedBox(height: 10),
        ],

        // 2. Album & Playlist Carousel
        if (musicState.searchedAlbums.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                const Icon(Icons.album_outlined, color: MaoneArtTheme.spotifyGreenBright, size: 18),
                const SizedBox(width: 8),
                const Text(
                  "Album & Kumpulan Lagu",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(width: 6),
                Text(
                  "(${musicState.searchedAlbums.length})",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 195,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: musicState.searchedAlbums.length,
              itemBuilder: (context, idx) => _buildAlbumCard(context, musicState.searchedAlbums[idx]),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 3. Lagu Terpopuler
        if (musicState.searchResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded, color: MaoneArtTheme.primaryCyan, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      musicState.selectedArtist != null
                          ? "Lagu Populer ${musicState.selectedArtist!.name}"
                          : "Lagu Terpopuler",
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "(${musicState.searchResults.length})",
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    final shuffledList = List<Song>.from(musicState.searchResults)..shuffle();
                    ref.read(playerProvider).playSong(
                          shuffledList.first,
                          newQueue: shuffledList,
                          index: 0,
                        );
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const PlayerScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: MaoneArtTheme.spotifyGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shuffle, size: 14, color: MaoneArtTheme.spotifyGreenBright),
                        SizedBox(width: 6),
                        Text(
                          "Putar Acak",
                          style: TextStyle(
                            color: MaoneArtTheme.spotifyGreenBright,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(musicState.searchResults.length, (index) {
            final song = musicState.searchResults[index];
            final isPlaying = playerState.currentSong?.id == song.id;
            final isFav = ref.watch(libraryProvider).isFavorite(song);

            return SongTile(
              song: song,
              isPlaying: isPlaying,
              isFavorite: isFav,
              onFavoriteTap: () {
                ref.read(libraryProvider).toggleFavorite(song);
              },
              onPlaylistTap: () {
                PlaylistPickerModal.show(context, ref, song);
              },
              onTap: () {
                FocusScope.of(context).unfocus();
                ref.read(playerProvider).playSong(
                      song,
                      newQueue: musicState.searchResults,
                      index: index,
                    );
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const PlayerScreen()),
                );
              },
            );
          }),
        ],
      ],
    );
  }

  Widget _buildAlbumsOnlyView(dynamic musicState, bool isLandscape) {
    if (musicState.searchedAlbums.isEmpty) {
      return const Center(
        child: Text("Tidak ada album ditemukan", style: TextStyle(color: Colors.white54)),
      );
    }

    return GridView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: isLandscape ? 85 : 160, left: 16, right: 16, top: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isLandscape ? 4 : 2,
        childAspectRatio: 0.74,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: musicState.searchedAlbums.length,
      itemBuilder: (context, index) {
        final album = musicState.searchedAlbums[index];
        return _buildAlbumCard(context, album, size: double.infinity);
      },
    );
  }

  Widget _buildSongsOnlyView(dynamic musicState, dynamic playerState, bool isLandscape) {
    if (musicState.searchResults.isEmpty) {
      return const Center(
        child: Text("Tidak ada lagu ditemukan", style: TextStyle(color: Colors.white54)),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Daftar Lagu (${musicState.searchResults.length})",
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  final shuffledList = List<Song>.from(musicState.searchResults)..shuffle();
                  ref.read(playerProvider).playSong(
                        shuffledList.first,
                        newQueue: shuffledList,
                        index: 0,
                      );
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const PlayerScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: MaoneArtTheme.spotifyGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shuffle, size: 14, color: MaoneArtTheme.spotifyGreenBright),
                      SizedBox(width: 6),
                      Text(
                        "Putar Acak",
                        style: TextStyle(
                          color: MaoneArtTheme.spotifyGreenBright,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(bottom: isLandscape ? 85 : 160, top: 4),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 520,
              mainAxisExtent: 78,
              crossAxisSpacing: 0,
              mainAxisSpacing: 0,
            ),
            itemCount: musicState.searchResults.length,
            itemBuilder: (context, index) {
              final song = musicState.searchResults[index];
              final isPlaying = playerState.currentSong?.id == song.id;
              final isFav = ref.watch(libraryProvider).isFavorite(song);

              return SongTile(
                song: song,
                isPlaying: isPlaying,
                isFavorite: isFav,
                onFavoriteTap: () {
                  ref.read(libraryProvider).toggleFavorite(song);
                },
                onPlaylistTap: () {
                  PlaylistPickerModal.show(context, ref, song);
                },
                onTap: () {
                  FocusScope.of(context).unfocus();
                  ref.read(playerProvider).playSong(
                        song,
                        newQueue: musicState.searchResults,
                        index: index,
                      );
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const PlayerScreen()),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArtistsOnlyView(dynamic musicState, bool isLandscape) {
    if (musicState.searchedArtists.isEmpty) {
      return const Center(
        child: Text("Tidak ada artis ditemukan", style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: isLandscape ? 85 : 160, top: 4),
      itemCount: musicState.searchedArtists.length,
      itemBuilder: (context, index) {
        final artist = musicState.searchedArtists[index];
        return ArtistBar(
          artist: artist,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => ArtistProfileScreen(artist: artist)),
            );
          },
          onPlayTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => ArtistProfileScreen(artist: artist)),
            );
          },
        );
      },
    );
  }
}
