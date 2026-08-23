import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../theme/maoneart_theme.dart';
import '../widgets/song_tile.dart';
import '../widgets/playlist_picker_modal.dart';
import 'search_screen.dart';
import 'player_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicState = ref.watch(musicProvider);
    final playerState = ref.watch(playerProvider);
    final libraryState = ref.watch(libraryProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: MaoneArtTheme.spotifyGreenBright,
          backgroundColor: MaoneArtTheme.bgDark,
          onRefresh: () => ref.read(musicProvider).fetchTrending(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar: App Name & Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.45),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/ic_launcher.png',
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "MaoneArt Music",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  foreground: Paint()
                                    ..shader = const LinearGradient(
                                      colors: [MaoneArtTheme.spotifyGreenBright, MaoneArtTheme.primaryCyan],
                                    ).createShader(const Rect.fromLTWH(0, 0, 220, 30)),
                                ),
                              ),
                              Text(
                                "Streaming & Tangga Lagu Bebas Iklan",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, size: 26, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const SearchScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Featured Hero Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F3820), Color(0xFF0B1B15), Color(0xFF141927)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: MaoneArtTheme.spotifyGreen.withOpacity(0.3), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: MaoneArtTheme.spotifyGreen.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: MaoneArtTheme.spotifyGreen.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.whatshot, size: 14, color: MaoneArtTheme.spotifyGreenBright),
                                  SizedBox(width: 4),
                                  Text(
                                    "MAONEART TRENDING",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: MaoneArtTheme.spotifyGreenBright,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              "UPDATED TODAY",
                              style: TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Top 10 Charts & Viral Hits",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Lagu Paling Sering Diputar Minggu Ini • Dengarkan Tanpa Iklan",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MaoneArtTheme.spotifyGreenBright,
                                foregroundColor: Colors.black,
                                elevation: 4,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              onPressed: () {
                                if (musicState.trendingSongs.isNotEmpty) {
                                  ref.read(playerProvider).playSong(
                                        musicState.trendingSongs.first,
                                        newQueue: musicState.trendingSongs,
                                        index: 0,
                                      );
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => const PlayerScreen()),
                                  );
                                }
                              },
                              icon: const Icon(Icons.play_arrow, size: 22, color: Colors.black),
                              label: const Text(
                                "Putar Semua",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              onPressed: () => ref.read(musicProvider).fetchTrending(),
                              icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
                              label: const Text(
                                "Refresh",
                                style: TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Spotify Top Charts Horizontal Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: const Text(
                    "Tangga Lagu Populer",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      _buildChartCard(
                        ref,
                        musicState,
                        title: "Top 10 Trending",
                        subtitle: "Hits Terpopuler 2026",
                        categoryKey: "Trending",
                        gradientColors: [const Color(0xFF134E5E), const Color(0xFF71B280)],
                        icon: Icons.whatshot,
                      ),
                      const SizedBox(width: 12),
                      _buildChartCard(
                        ref,
                        musicState,
                        title: "Top 10 Indonesia",
                        subtitle: "Lagu Teratas Indonesia",
                        categoryKey: "Indonesia",
                        gradientColors: [const Color(0xFF8D0B41), const Color(0xFF1E0A24)],
                        icon: Icons.flag,
                      ),
                      const SizedBox(width: 12),
                      _buildChartCard(
                        ref,
                        musicState,
                        title: "Top 10 Barat",
                        subtitle: "Hits Dunia Paling Viral",
                        categoryKey: "Global",
                        gradientColors: [const Color(0xFF1E3264), const Color(0xFF0F172A)],
                        icon: Icons.public,
                      ),
                      const SizedBox(width: 12),
                      _buildChartCard(
                        ref,
                        musicState,
                        title: "TikTok Viral 10",
                        subtitle: "Musik FYP Paling Candu",
                        categoryKey: "Viral TikTok",
                        gradientColors: [const Color(0xFF005F73), const Color(0xFF0A9396)],
                        icon: Icons.music_note,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Category Chips Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bar_chart, color: MaoneArtTheme.spotifyGreenBright, size: 22),
                          const SizedBox(width: 6),
                          Text(
                            "Daftar Trending ${musicState.selectedCategory}",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      if (musicState.isLoadingTrending)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MaoneArtTheme.spotifyGreenBright,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Category Filter Chips (Spotify Pill Style)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    children: [
                      _buildCategoryChip(ref, musicState, 'Trending', '🔥 Top Trending'),
                      _buildCategoryChip(ref, musicState, 'Indonesia', '🇮🇩 Top Indo'),
                      _buildCategoryChip(ref, musicState, 'Global', '🌐 Top Global'),
                      _buildCategoryChip(ref, musicState, 'Viral TikTok', '🎵 TikTok Hits'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Songs List (Ranked Spotify Style)
                if (musicState.trendingSongs.isEmpty && musicState.isLoadingTrending)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: MaoneArtTheme.spotifyGreenBright),
                    ),
                  )
                else if (musicState.trendingSongs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.music_off, size: 48, color: Colors.white.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          const Text(
                            "Tidak ada lagu ditemukan",
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: MaoneArtTheme.spotifyGreen),
                            onPressed: () => ref.read(musicProvider).fetchTrending(),
                            child: const Text("Coba Lagi", style: TextStyle(color: Colors.black)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: musicState.trendingSongs.length,
                    itemBuilder: (context, index) {
                      final song = musicState.trendingSongs[index];
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
                                newQueue: musicState.trendingSongs,
                                index: index,
                              );
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const PlayerScreen()),
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 140),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard(
    WidgetRef ref,
    dynamic musicState, {
    required String title,
    required String subtitle,
    required String categoryKey,
    required List<Color> gradientColors,
    required IconData icon,
  }) {
    final isSelected = musicState.selectedCategory == categoryKey;

    return GestureDetector(
      onTap: () => ref.read(musicProvider).fetchTrending(category: categoryKey),
      child: Container(
        width: 150,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isSelected ? MaoneArtTheme.spotifyGreenBright : Colors.white.withOpacity(0.12),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: MaoneArtTheme.spotifyGreenBright,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 12, color: Colors.black),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(WidgetRef ref, dynamic musicState, String categoryKey, String label) {
    final isSelected = musicState.selectedCategory == categoryKey;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          ref.read(musicProvider).fetchTrending(category: categoryKey);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? MaoneArtTheme.spotifyGreen : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? MaoneArtTheme.spotifyGreenBright : Colors.white.withOpacity(0.15),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: MaoneArtTheme.spotifyGreen.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.white.withOpacity(0.9),
          ),
        ),
      ),
    );
  }
}
