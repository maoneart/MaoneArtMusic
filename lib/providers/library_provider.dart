import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../services/storage_service.dart';

class LibraryStateNotifier extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  List<Song> _favorites = [];
  List<Playlist> _playlists = [];
  bool _isLoading = false;

  List<Song> get favorites => _favorites;
  List<Playlist> get playlists => _playlists;
  bool get isLoading => _isLoading;

  LibraryStateNotifier() {
    loadLibrary();
  }

  Future<void> loadLibrary() async {
    _isLoading = true;
    notifyListeners();

    _favorites = await _storageService.getFavorites();
    _playlists = await _storageService.getPlaylists();

    _isLoading = false;
    notifyListeners();
  }

  bool isFavorite(Song song) {
    return _favorites.any((s) => s.id == song.id);
  }

  Future<void> toggleFavorite(Song song) async {
    if (isFavorite(song)) {
      _favorites.removeWhere((s) => s.id == song.id);
    } else {
      _favorites.add(song);
    }
    await _storageService.saveFavorites(_favorites);
    notifyListeners();
  }

  Future<void> createPlaylist(String name, {String description = ''}) async {
    final newPlaylist = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      songs: [],
    );
    _playlists.add(newPlaylist);
    await _storageService.savePlaylists(_playlists);
    notifyListeners();
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    await _storageService.savePlaylists(_playlists);
    notifyListeners();
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final currentPlaylist = _playlists[idx];
      if (!currentPlaylist.songs.any((s) => s.id == song.id)) {
        final updatedSongs = List<Song>.from(currentPlaylist.songs)..add(song);
        _playlists[idx] = currentPlaylist.copyWith(songs: updatedSongs);
        await _storageService.savePlaylists(_playlists);
        notifyListeners();
      }
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final currentPlaylist = _playlists[idx];
      final updatedSongs = List<Song>.from(currentPlaylist.songs)..removeWhere((s) => s.id == songId);
      _playlists[idx] = currentPlaylist.copyWith(songs: updatedSongs);
      await _storageService.savePlaylists(_playlists);
      notifyListeners();
    }
  }
}

final libraryProvider = ChangeNotifierProvider<LibraryStateNotifier>((ref) {
  return LibraryStateNotifier();
});
