import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../services/music_service.dart';

class MusicStateNotifier extends ChangeNotifier {
  final MusicService _musicService = MusicService();

  List<Song> _trendingSongs = [];
  List<Song> _searchResults = [];
  bool _isLoadingTrending = false;
  bool _isSearching = false;
  String _currentQuery = '';

  List<Song> get trendingSongs => _trendingSongs;
  List<Song> get searchResults => _searchResults;
  bool get isLoadingTrending => _isLoadingTrending;
  bool get isSearching => _isSearching;
  String get currentQuery => _currentQuery;

  MusicStateNotifier() {
    fetchTrending();
  }

  Future<void> fetchTrending() async {
    _isLoadingTrending = true;
    notifyListeners();

    try {
      _trendingSongs = await _musicService.getTrendingSongs();
    } catch (e) {
      print('Error fetching trending: $e');
    }

    _isLoadingTrending = false;
    notifyListeners();
  }

  Future<void> search(String query) async {
    _currentQuery = query;
    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await _musicService.searchSongs(query);
    } catch (e) {
      print('Error searching: $e');
    }

    _isSearching = false;
    notifyListeners();
  }
}

final musicProvider = ChangeNotifierProvider<MusicStateNotifier>((ref) {
  return MusicStateNotifier();
});
