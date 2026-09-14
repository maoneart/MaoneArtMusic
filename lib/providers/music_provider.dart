import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../models/artist.dart';
import '../services/music_service.dart';
import '../services/youtube_audio_extractor.dart';

class MusicStateNotifier extends ChangeNotifier {
  final MusicService _musicService = MusicService();

  List<Song> _trendingSongs = [];
  List<Song> _searchResults = [];
  List<Artist> _searchedArtists = [];
  Artist? _selectedArtist;
  List<String> _suggestions = [];
  bool _isLoadingTrending = false;
  bool _isSearching = false;
  String _currentQuery = '';
  String _selectedCategory = 'Trending';
  int _searchRequestId = 0;
  Timer? _debounceTimer;

  List<Song> get trendingSongs => _trendingSongs;
  List<Song> get searchResults => _searchResults;
  List<Artist> get searchedArtists => _searchedArtists;
  Artist? get selectedArtist => _selectedArtist;
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

  Future<void> fetchTrending({String? category, bool refresh = false}) async {
    if (category != null) {
      _selectedCategory = category;
    }
    _isLoadingTrending = true;
    notifyListeners();

    try {
      _trendingSongs = await _musicService.getTrendingSongs(
        category: _selectedCategory,
        refresh: refresh,
      );
      // Pre-fetch stream for top 3 tracks smoothly in background
      YoutubeAudioExtractor.preFetchBatch(_trendingSongs, limit: 3);
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
      _searchedArtists = [];
      _selectedArtist = null;
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
      _searchedArtists = [];
      _selectedArtist = null;
      _suggestions = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      // Concurrently query official songs and canonical artists (Musify pattern)
      final songsFuture = _musicService.searchSongs(query);
      final artistsFuture = _musicService.searchArtists(query);

      final results = await Future.wait([songsFuture, artistsFuture]);
      if (_searchRequestId == reqId) {
        _searchResults = results[0] as List<Song>;
        _searchedArtists = results[1] as List<Artist>;

        // Fallback: If artist query returned empty, resolve artist from top song
        if (_searchedArtists.isEmpty && _searchResults.isNotEmpty) {
          final topSong = _searchResults.first;
          if (topSong.artist.isNotEmpty &&
              topSong.artist != 'Unknown Artist' &&
              topSong.artist != 'Various Artists') {
            _searchedArtists = [
              Artist(
                id: '',
                name: topSong.artist,
                avatarUrl: topSong.artworkUrl,
                subtitle: 'Artis Populer',
                isVerified: true,
              )
            ];
          }
        }

        // Pre-fetch stream for top 3 search results smoothly without congestion
        YoutubeAudioExtractor.preFetchBatch(_searchResults, limit: 3);
      }
    } catch (e) {
      print('Error searching: $e');
    }

    if (_searchRequestId == reqId) {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Selects an artist and fetches their canonical popular songs (Musify top tracks)
  Future<void> selectArtist(Artist artist) async {
    _selectedArtist = artist;
    _isSearching = true;
    notifyListeners();

    try {
      final songs = await _musicService.getArtistTopSongs(artist.id, artist.name);
      if (songs.isNotEmpty) {
        _searchResults = songs;
        YoutubeAudioExtractor.preFetchBatch(_searchResults, limit: 3);
      }
    } catch (e) {
      print('Error selecting artist: $e');
    }

    _isSearching = false;
    notifyListeners();
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    _currentQuery = '';
    _searchResults = [];
    _searchedArtists = [];
    _selectedArtist = null;
    _suggestions = [];
    _isSearching = false;
    notifyListeners();
  }
}

final musicProvider = ChangeNotifierProvider<MusicStateNotifier>((ref) {
  return MusicStateNotifier();
});
