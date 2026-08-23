import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/maoneart_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/song_tile.dart';
import '../widgets/playlist_picker_modal.dart';
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

            // Quick Category Pills
            if (_searchController.text.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Jelajahi Genre Populer",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickCategories.map((cat) {
                    return ActionChip(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      label: Text(
                        cat,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        _triggerSearch(cat);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],

            // Results List
            Expanded(
              child: musicState.isSearching
                  ? const Center(
                      child: CircularProgressIndicator(color: MaoneArtTheme.primaryCyan),
                    )
                  : musicState.searchResults.isEmpty && _searchController.text.isNotEmpty
                      ? Center(
                          child: Text(
                            "Tidak ada hasil untuk '${_searchController.text}'",
                            style: TextStyle(color: Colors.white.withOpacity(0.6)),
                          ),
                        )
                      : ListView.builder(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.only(bottom: 160, top: 8),
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
        ),
      ),
    );
  }
}
