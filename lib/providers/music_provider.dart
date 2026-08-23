import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../services/music_service.dart';
import '../services/youtube_audio_extractor.dart';

class MusicStateNotifier extends ChangeNotifier {
  final MusicService _musicService = MusicService();

  List<Song> _trendingSongs = [];
  List<Song> _searchResults = [];
  List<String> _suggestions = [];
  bool _isLoadingTrending = false;
  bool _isSearching = false;
  String _currentQuery = '';
  String _selectedCategory = 'Trending';
  int _searchRequestId = 0;
  Timer? _debounceTimer;

  List<Song> get trendingSongs => _trendingSongs;
  List<Song> get searchResults => _searchResults;
  List<String> get suggestions => _suggestions;
  bool get isLoadingTrending => _isLoadingTrending;
  bool get isSearching => _isSearching;
  String get currentQuery => _currentQuery;
  String get selectedCategory => _selectedCategory;

  MusicStateNotifier() {
    fetchTrending();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchTrending({String? category}) async {
    if (category != null) {
      _selectedCategory = category;
    }
    _isLoadingTrending = true;
    notifyListeners();

    try {
      _trendingSongs = await _musicService.getTrendingSongs(category: _selectedCategory);
      // Pre-fetch streams for all top trending songs so tapping plays instantly
      YoutubeAudioExtractor.preFetchBatch(_trendingSongs, limit: 10);
    } catch (e) {
      print('Error fetching trending: $e');
    }

    _isLoadingTrending = false;
    notifyListeners();
  }

  void onSearchQueryChanged(String query) {
    _currentQuery = query;
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      _searchResults = [];
      _suggestions = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    // 1. Fetch autocomplete suggestions instantly
    _musicService.getSearchSuggestions(query).then((sug) {
      if (_currentQuery == query) {
        _suggestions = sug;
        notifyListeners();
      }
    });

    // 2. Debounce full search by 250ms
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      search(query);
    });
  }

  Future<void> search(String query) async {
    _currentQuery = query;
    final int reqId = ++_searchRequestId;

    if (query.trim().isEmpty) {
      _searchResults = [];
      _suggestions = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final results = await _musicService.searchSongs(query);
      if (_searchRequestId == reqId) {
        _searchResults = results;
        YoutubeAudioExtractor.preFetchBatch(_searchResults, limit: 6);
      }
    } catch (e) {
      print('Error searching: $e');
    }

    if (_searchRequestId == reqId) {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    _currentQuery = '';
    _searchResults = [];
    _suggestions = [];
    _isSearching = false;
    notifyListeners();
  }
}

final musicProvider = ChangeNotifierProvider<MusicStateNotifier>((ref) {
  return MusicStateNotifier();
});
