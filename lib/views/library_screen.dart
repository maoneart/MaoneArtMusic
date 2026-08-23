import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/maoneart_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/glass_modal.dart';
import '../widgets/song_tile.dart';
import '../widgets/playlist_picker_modal.dart';
import 'playlist_detail_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF141927).withOpacity(0.88),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MaoneArtTheme.primaryCyan.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.playlist_add, color: MaoneArtTheme.primaryCyan, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Buat Playlist Baru",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Nama Playlist...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: MaoneArtTheme.primaryCyan),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                "Batal",
                                style: TextStyle(color: Colors.white.withOpacity(0.8)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MaoneArtTheme.primaryCyan,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              onPressed: () {
                                if (nameController.text.trim().isNotEmpty) {
                                  ref.read(libraryProvider).createPlaylist(nameController.text.trim());
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text(
                                "Buat",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final playerState = ref.watch(playerProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header & Create Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Koleksi Saya",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.playlist_add, color: MaoneArtTheme.primaryCyan, size: 28),
                    onPressed: _showCreatePlaylistDialog,
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: MaoneArtTheme.primaryCyan,
              labelColor: MaoneArtTheme.primaryCyan,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(text: "Favorit Saya"),
                Tab(text: "Playlist"),
              ],
            ),

            // Tab View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Favorites View
                  libraryState.favorites.isEmpty
                      ? Center(
                          child: Text(
                            "Belum ada lagu favorit.",
                            style: TextStyle(color: Colors.white.withOpacity(0.5)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 160, top: 12),
                          itemCount: libraryState.favorites.length,
                          itemBuilder: (context, index) {
                            final song = libraryState.favorites[index];
                            final isPlaying = playerState.currentSong?.id == song.id;

                            return SongTile(
                              song: song,
                              isPlaying: isPlaying,
                              isFavorite: true,
                              onFavoriteTap: () {
                                ref.read(libraryProvider).toggleFavorite(song);
                              },
                              onPlaylistTap: () {
                                PlaylistPickerModal.show(context, ref, song);
                              },
                              onTap: () {
                                ref.read(playerProvider).playSong(
                                      song,
                                      newQueue: libraryState.favorites,
                                      index: index,
                                    );
                              },
                              onMoreTap: () async {
                                final confirm = await MaoneArtGlassModal.showConfirmModal(
                                  context: context,
                                  title: "Hapus dari Favorit?",
                                  message: "Apakah Anda yakin ingin menghapus '${song.title}' dari daftar favorit?",
                                  confirmText: "Hapus",
                                  cancelText: "Batal",
                                  icon: Icons.delete_outline,
                                  iconColor: Colors.redAccent,
                                );
                                if (confirm == true) {
                                  ref.read(libraryProvider).toggleFavorite(song);
                                }
                              },
                            );
                          },
                        ),

                  // Playlists View
                  libraryState.playlists.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.queue_music, size: 64, color: Colors.white.withOpacity(0.2)),
                              const SizedBox(height: 12),
                              Text(
                                "Belum ada playlist tersimpan.",
                                style: TextStyle(color: Colors.white.withOpacity(0.5)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
                          itemCount: libraryState.playlists.length,
                          itemBuilder: (context, index) {
                            final playlist = libraryState.playlists[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: GlassContainer(
                                borderRadius: 16,
                                padding: const EdgeInsets.all(16),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => PlaylistDetailScreen(playlist: playlist),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: MaoneArtTheme.primaryPurple.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.music_note, color: Colors.white),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            playlist.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "${playlist.songs.length} Lagu",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withOpacity(0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () async {
                                        final confirm = await MaoneArtGlassModal.showConfirmModal(
                                          context: context,
                                          title: "Hapus Playlist?",
                                          message: "Apakah Anda yakin ingin menghapus playlist '${playlist.name}'?",
                                          confirmText: "Hapus",
                                          cancelText: "Batal",
                                          icon: Icons.delete_forever,
                                          iconColor: Colors.redAccent,
                                        );
                                        if (confirm == true) {
                                          ref.read(libraryProvider).deletePlaylist(playlist.id);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
