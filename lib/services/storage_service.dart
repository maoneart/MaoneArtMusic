import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/playlist.dart';

class StorageService {
  static const String _favoritesKey = 'maoneart_favorites';
  static const String _playlistsKey = 'maoneart_playlists';
  static const String _recentKey = 'maoneart_recent';

  /// Save Favorite Songs
  Future<void> saveFavorites(List<Song> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = json.encode(songs.map((s) => s.toMap()).toList());
    await prefs.setString(_favoritesKey, data);
  }

  /// Get Favorite Songs
  Future<List<Song>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_favoritesKey);
    if (data == null || data.isEmpty) return [];

    try {
      final List decoded = json.decode(data);
      return decoded.map((item) => Song.fromMap(item)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Save Playlists
  Future<void> savePlaylists(List<Playlist> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = json.encode(playlists.map((p) => p.toMap()).toList());
    await prefs.setString(_playlistsKey, data);
  }

  /// Get Playlists
  Future<List<Playlist>> getPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_playlistsKey);
    if (data == null || data.isEmpty) return [];

    try {
      final List decoded = json.decode(data);
      return decoded.map((item) => Playlist.fromMap(item)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Save Recently Played
  Future<void> saveRecent(List<Song> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = json.encode(songs.map((s) => s.toMap()).toList());
    await prefs.setString(_recentKey, data);
  }

  /// Get Recently Played
  Future<List<Song>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_recentKey);
    if (data == null || data.isEmpty) return [];

    try {
      final List decoded = json.decode(data);
      return decoded.map((item) => Song.fromMap(item)).toList();
    } catch (e) {
      return [];
    }
  }
}
