import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/maoneart_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/song_tile.dart';
import '../widgets/playlist_picker_modal.dart';
import '../models/song.dart';
import '../models/artist.dart';
import '../widgets/artist_bar.dart';
import 'artist_profile_screen.dart';
import 'player_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

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
    ref.read(musicProvider).search(clean);
  }

  @override
  Widget build(BuildContext context) {
    final musicState = ref.watch(musicProvider);
    final playerState = ref.watch(playerProvider);

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
                          hintText: "Cari lagu, artis, atau band...",
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

            // Quick Trending Pills (Single compact horizontal row, doesn't eat vertical screen space)
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
                  final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
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
                            "Cari Lagu, Artis, atau Playlist",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Ketik di kolom pencarian untuk hasil musik instan",
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35)),
                          ),
                        ],
                      ),
                    );
                  }
                  if (musicState.searchResults.isEmpty) {
                    return Center(
                      child: Text(
                        "Tidak ada hasil untuk '${_searchController.text}'",
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Musify Artist Spotlight Section (Di Atas)
                      if (musicState.searchedArtists.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline_rounded, color: MaoneArtTheme.spotifyGreenBright, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Artis",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...musicState.searchedArtists.take(2).map((artist) => ArtistBar(
                          artist: artist,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ArtistProfileScreen(artist: artist),
                              ),
                            );
                          },
                          onPlayTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ArtistProfileScreen(artist: artist),
                              ),
                            );
                          },
                        )),
                        const SizedBox(height: 6),
                      ],

                      // 2. Musify Popular Songs Section (Di Bawah)
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
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
