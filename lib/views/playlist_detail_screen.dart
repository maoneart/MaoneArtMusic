import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/playlist.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/maoneart_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/glass_modal.dart';
import '../widgets/song_tile.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({Key? key, required this.playlist}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final playerState = ref.watch(playerProvider);

    // Refresh updated playlist state
    final currentPlaylist = libraryState.playlists.firstWhere(
      (p) => p.id == playlist.id,
      orElse: () => playlist,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(currentPlaylist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await MaoneArtGlassModal.showConfirmModal(
                context: context,
                title: "Hapus Playlist?",
                message: "Apakah Anda yakin ingin menghapus playlist '${currentPlaylist.name}'?",
                confirmText: "Hapus",
                cancelText: "Batal",
                icon: Icons.delete_forever,
                iconColor: Colors.redAccent,
              );
              if (confirm == true) {
                ref.read(libraryProvider).deletePlaylist(currentPlaylist.id);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Playlist Header Info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [MaoneArtTheme.primaryCyan, MaoneArtTheme.primaryPurple],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.queue_music, size: 36, color: Colors.black),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentPlaylist.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${currentPlaylist.songs.length} Lagu tersimpan",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Play All Button
            if (currentPlaylist.songs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MaoneArtTheme.primaryCyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("PUTAR SEMUA", style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      ref.read(playerProvider).playSong(
                            currentPlaylist.songs.first,
                            newQueue: currentPlaylist.songs,
                            index: 0,
                          );
                    },
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Songs List
            Expanded(
              child: currentPlaylist.songs.isEmpty
                  ? Center(
                      child: Text(
                        "Playlist ini masih kosong.",
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 160),
                      itemCount: currentPlaylist.songs.length,
                      itemBuilder: (context, index) {
                        final song = currentPlaylist.songs[index];
                        final isPlaying = playerState.currentSong?.id == song.id;

                        return SongTile(
                          song: song,
                          isPlaying: isPlaying,
                          onTap: () {
                            ref.read(playerProvider).playSong(
                                  song,
                                  newQueue: currentPlaylist.songs,
                                  index: index,
                                );
                          },
                          onMoreTap: () async {
                            final confirm = await MaoneArtGlassModal.showConfirmModal(
                              context: context,
                              title: "Hapus Lagu?",
                              message: "Hapus '${song.title}' dari playlist ini?",
                              confirmText: "Hapus",
                              cancelText: "Batal",
                              icon: Icons.remove_circle_outline,
                              iconColor: Colors.redAccent,
                            );
                            if (confirm == true) {
                              ref.read(libraryProvider).removeSongFromPlaylist(
                                    currentPlaylist.id,
                                    song.id,
                                  );
                            }
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
