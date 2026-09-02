import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/playlist.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/maoneart_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/glass_modal.dart';
import '../widgets/song_tile.dart';
import '../widgets/playlist_picker_modal.dart';

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

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

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
            // Playlist Header Info & Play All Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: isLandscape
                  ? Row(
                      children: [
                        Expanded(
                          child: GlassContainer(
                            borderRadius: 16,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [MaoneArtTheme.primaryCyan, MaoneArtTheme.primaryPurple],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.queue_music, size: 26, color: Colors.black),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currentPlaylist.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${currentPlaylist.songs.length} Lagu tersimpan",
                                        style: TextStyle(
                                          fontSize: 12,
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
                        if (currentPlaylist.songs.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MaoneArtTheme.primaryCyan,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        ],
                      ],
                    )
                  : Column(
                      children: [
                        GlassContainer(
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
                        if (currentPlaylist.songs.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
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
                        ],
                      ],
                    ),
            ),

            const SizedBox(height: 8),

            // Songs List
            Expanded(
              child: currentPlaylist.songs.isEmpty
                  ? Center(
                      child: Text(
                        "Playlist ini masih kosong.",
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.only(bottom: isLandscape ? 85 : 160),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 520,
                        mainAxisExtent: 78,
                        crossAxisSpacing: 0,
                        mainAxisSpacing: 0,
                      ),
                      itemCount: currentPlaylist.songs.length,
                      itemBuilder: (context, index) {
                        final song = currentPlaylist.songs[index];
                        final isPlaying = playerState.currentSong?.id == song.id;

                        final isFav = libraryState.isFavorite(song);

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
