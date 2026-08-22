import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../theme/maoneart_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/song_tile.dart';
import 'search_screen.dart';
import 'player_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicState = ref.watch(musicProvider);
    final playerState = ref.watch(playerProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(musicProvider).fetchTrending(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Banner
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "MaoneArt Music",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              foreground: Paint()
                                ..shader = const LinearGradient(
                                  colors: [MaoneArtTheme.primaryCyan, MaoneArtTheme.accentGreen],
                                ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Streaming Musik Tanpa Batas",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, size: 28, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const SearchScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Featured Banner Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: GlassContainer(
                    borderRadius: 20,
                    opacity: 0.15,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: MaoneArtTheme.primaryCyan.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "FEATURED",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: MaoneArtTheme.primaryCyan,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Dengarkan Musik YouTube & Spotify Tanpa Iklan",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Cari jutaan lagu, buat playlist favorit, dan nikmati audio kualitas tinggi.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Section Title: Trending Songs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Trending Sekarang",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (musicState.isLoadingTrending)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MaoneArtTheme.primaryCyan,
                          ),
                        ),
                    ],
                  ),
                ),

                // Songs List
                if (musicState.trendingSongs.isEmpty && musicState.isLoadingTrending)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: MaoneArtTheme.primaryCyan),
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

                      return SongTile(
                        song: song,
                        isPlaying: isPlaying,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
