import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/library_provider.dart';
import '../theme/maoneart_theme.dart';
import 'glass_container.dart';
import 'app_artwork.dart';

class PlaylistPickerModal {
  static Future<void> show(BuildContext context, WidgetRef ref, Song song) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final libraryState = ref.watch(libraryProvider);
            final playlists = libraryState.playlists;

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1422).withOpacity(0.92),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Drag Handle
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Modal Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.star_rounded, color: Colors.amberAccent, size: 24),
                              SizedBox(width: 8),
                              Text(
                                "Tambahkan ke Playlist",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Selected Song Preview Tile
                      GlassContainer(
                        borderRadius: 14,
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            AppArtwork(
                              artworkUrl: song.artworkUrl,
                              width: 44,
                              height: 44,
                              borderRadius: 8,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Create New Playlist Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MaoneArtTheme.spotifyGreen,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 22),
                          label: const Text(
                            "Buat Playlist Baru",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onPressed: () => _showCreatePlaylistDialog(context, ref, song),
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 12),

                      // Playlists List
                      Flexible(
                        child: playlists.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.queue_music_rounded, size: 48, color: Colors.white.withOpacity(0.3)),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Belum ada playlist.\nBuat playlist pertamamu di atas!",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                padding: const EdgeInsets.only(bottom: 24),
                                itemCount: playlists.length,
                                itemBuilder: (context, index) {
                                  final playlist = playlists[index];
                                  final isInPlaylist = playlist.songs.any((s) => s.id == song.id);

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: GlassContainer(
                                      borderRadius: 14,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      onTap: () async {
                                        if (isInPlaylist) {
                                          await ref.read(libraryProvider).removeSongFromPlaylist(playlist.id, song.id);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("Dihapus dari '${playlist.name}'"),
                                              duration: const Duration(seconds: 2),
                                              backgroundColor: Colors.redAccent.shade700,
                                            ),
                                          );
                                        } else {
                                          await ref.read(libraryProvider).addSongToPlaylist(playlist.id, song);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("⭐ Ditambahkan ke '${playlist.name}'"),
                                              duration: const Duration(seconds: 2),
                                              backgroundColor: MaoneArtTheme.spotifyGreen,
                                            ),
                                          );
                                        }
                                      },
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: isInPlaylist
                                                  ? MaoneArtTheme.spotifyGreen.withOpacity(0.2)
                                                  : Colors.white.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              Icons.queue_music_rounded,
                                              color: isInPlaylist ? MaoneArtTheme.spotifyGreenBright : Colors.white70,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  playlist.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: isInPlaylist ? MaoneArtTheme.spotifyGreenBright : Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  "${playlist.songs.length} lagu",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white.withOpacity(0.5),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            isInPlaylist ? Icons.check_circle_rounded : Icons.star_border_rounded,
                                            color: isInPlaylist ? MaoneArtTheme.spotifyGreenBright : Colors.amberAccent,
                                            size: 24,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref, Song song) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF141927).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.playlist_add_rounded, color: MaoneArtTheme.primaryCyan, size: 36),
                    const SizedBox(height: 12),
                    const Text(
                      "Playlist Baru",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Nama Playlist (misal: Favoritku)",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: MaoneArtTheme.primaryCyan),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.of(dialogCtx).pop(),
                              child: const Text("Batal", style: TextStyle(color: Colors.white70)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MaoneArtTheme.primaryCyan,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                final name = controller.text.trim();
                                if (name.isNotEmpty) {
                                  Navigator.of(dialogCtx).pop();
                                  await ref.read(libraryProvider).createPlaylist(name);
                                  // Auto add song to the new playlist
                                  final updatedPlaylists = ref.read(libraryProvider).playlists;
                                  final newPl = updatedPlaylists.lastWhere((p) => p.name == name);
                                  await ref.read(libraryProvider).addSongToPlaylist(newPl.id, song);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("⭐ Playlist '$name' dibuat & lagu ditambahkan!"),
                                      backgroundColor: MaoneArtTheme.spotifyGreen,
                                    ),
                                  );
                                }
                              },
                              child: const Text("Buat & Tambah", style: TextStyle(fontWeight: FontWeight.bold)),
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
}
