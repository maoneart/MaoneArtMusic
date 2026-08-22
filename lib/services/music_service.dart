import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class MusicService {
  static const String _iTunesSearchUrl = 'https://itunes.apple.com/search';

  /// Search tracks by query (e.g. artist, title, album)
  Future<List<Song>> searchSongs(String query, {int limit = 25}) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse('$_iTunesSearchUrl?term=${Uri.encodeComponent(query)}&media=music&entity=song&limit=$limit');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results.map((item) {
          final String rawArtwork = item['artworkUrl100'] ?? item['artworkUrl60'] ?? item['artworkUrl30'] ?? '';
          final String highResArtwork = rawArtwork.isNotEmpty
              ? rawArtwork.replaceAll('100x100bb', '600x600bb').replaceAll('100x100', '600x600').replaceAll('60x60bb', '600x600bb')
              : 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&auto=format&fit=crop&q=80';

          return Song(
            id: 'itunes_${item['trackId']}',
            title: item['trackName'] ?? 'Unknown Track',
            artist: item['artistName'] ?? 'Unknown Artist',
            album: item['collectionName'] ?? 'Single',
            artworkUrl: highResArtwork,
            durationSeconds: (item['trackTimeMillis'] ?? 0) ~/ 1000,
          );
        }).toList();
      }
    } catch (e) {
      print('Error searching songs: $e');
    }
    return [];
  }

  /// Fetch real-time iTunes Top Songs RSS Feed (Indonesia / Global)
  Future<List<Song>> getItunesRssTrending({String country = 'id', int limit = 30}) async {
    try {
      final uri = Uri.parse('https://itunes.apple.com/$country/rss/topsongs/limit=$limit/json');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List entries = data['feed']?['entry'] ?? [];

        return entries.map((item) {
          final String title = item['im:name']?['label'] ?? 'Unknown Title';
          final String artist = item['im:artist']?['label'] ?? 'Unknown Artist';
          final String album = item['im:collection']?['im:name']?['label'] ?? 'Single';

          final List images = item['im:image'] ?? [];
          final String rawArtwork = images.isNotEmpty ? images.last['label'] ?? '' : '';
          final String highResArtwork = rawArtwork.isNotEmpty
              ? rawArtwork.replaceAll('170x170bb', '600x600bb').replaceAll('100x100bb', '600x600bb').replaceAll('55x55bb', '600x600bb')
              : 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&auto=format&fit=crop&q=80';

          final String trackId = item['id']?['attributes']?['im:id'] ?? '${title}_$artist'.hashCode.toString();

          return Song(
            id: 'itunes_rss_${country}_$trackId',
            title: title,
            artist: artist,
            album: album,
            artworkUrl: highResArtwork,
            durationSeconds: 210,
          );
        }).toList();
      }
    } catch (e) {
      print('Error fetching iTunes RSS trending ($country): $e');
    }
    return [];
  }

  /// Fetch Deezer Top Global Charts
  Future<List<Song>> getDeezerChart({int limit = 25}) async {
    try {
      final uri = Uri.parse('https://api.deezer.com/chart/0/tracks?limit=$limit');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List tracks = data['data'] ?? [];

        return tracks.map((item) {
          final String rawArtwork = item['album']?['cover_big'] ?? item['album']?['cover_medium'] ?? '';

          return Song(
            id: 'deezer_${item['id']}',
            title: item['title'] ?? 'Unknown Title',
            artist: item['artist']?['name'] ?? 'Unknown Artist',
            album: item['album']?['title'] ?? 'Single',
            artworkUrl: rawArtwork.isNotEmpty ? rawArtwork : 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&auto=format&fit=crop&q=80',
            durationSeconds: item['duration'] ?? 180,
          );
        }).toList();
      }
    } catch (e) {
      print('Error fetching Deezer charts: $e');
    }
    return [];
  }

  /// Get top trending songs / charts combined from live iTunes Top Charts & Deezer
  Future<List<Song>> getTrendingSongs({String category = 'Trending'}) async {
    final Map<String, Song> uniqueSongs = {};

    if (category == 'Indonesia') {
      final indoRss = await getItunesRssTrending(country: 'id', limit: 30);
      for (final s in indoRss) {
        uniqueSongs[s.id] = s;
      }
      if (uniqueSongs.length < 15) {
        final searchIndo = await searchSongs('Lagu Pop Indonesia Terbaru 2026', limit: 15);
        for (final s in searchIndo) {
          uniqueSongs[s.id] = s;
        }
      }
    } else if (category == 'Global') {
      final globalRss = await getItunesRssTrending(country: 'us', limit: 25);
      for (final s in globalRss) {
        uniqueSongs[s.id] = s;
      }
      final deezer = await getDeezerChart(limit: 20);
      for (final s in deezer) {
        uniqueSongs[s.id] = s;
      }
    } else if (category == 'Viral TikTok') {
      final tiktokHits = await searchSongs('Viral TikTok Song Hits', limit: 25);
      for (final s in tiktokHits) {
        uniqueSongs[s.id] = s;
      }
    } else {
      // Default 'Trending' (Mix of Indo & Global Top Hits)
      final indoRss = await getItunesRssTrending(country: 'id', limit: 20);
      for (final s in indoRss) {
        uniqueSongs[s.id] = s;
      }
      final globalRss = await getItunesRssTrending(country: 'us', limit: 15);
      for (final s in globalRss) {
        uniqueSongs[s.id] = s;
      }
      final deezer = await getDeezerChart(limit: 15);
      for (final s in deezer) {
        uniqueSongs[s.id] = s;
      }
    }

    // Fallback if APIs failed
    if (uniqueSongs.isEmpty) {
      final fallback = await searchSongs('Bernadya Mahalini Juicy Luicy Tulus', limit: 20);
      for (final s in fallback) {
        uniqueSongs[s.id] = s;
      }
    }

    return uniqueSongs.values.toList();
  }
}
