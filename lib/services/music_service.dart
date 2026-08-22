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
          final String artwork100 = item['artworkUrl100'] ?? '';
          // High resolution artwork upgrade
          final String highResArtwork = artwork100.replaceAll('100x100bb', '600x600bb');

          return Song(
            id: 'itunes_${item['trackId']}',
            title: item['trackName'] ?? 'Unknown Track',
            artist: item['artistName'] ?? 'Unknown Artist',
            album: item['collectionName'] ?? 'Single',
            artworkUrl: highResArtwork.isNotEmpty ? highResArtwork : 'https://picsum.photos/600',
            durationSeconds: (item['trackTimeMillis'] ?? 0) ~/ 1000,
            previewUrl: item['previewUrl'],
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
