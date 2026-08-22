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

  /// Get top trending songs / charts
  Future<List<Song>> getTrendingSongs() async {
    final List<String> trendingQueries = [
      'Top Hits 2026',
      'Indonesian Hits',
      'Pop Music',
      'Lo-Fi Beats',
      'Rock Anthems'
    ];

    List<Song> songs = [];
    for (final q in trendingQueries.take(2)) {
      final res = await searchSongs(q, limit: 10);
      songs.addAll(res);
    }
    return songs;
  }
}
