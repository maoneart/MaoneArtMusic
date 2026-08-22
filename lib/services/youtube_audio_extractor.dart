import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class YoutubeAudioExtractor {
  static const List<String> _pipedInstances = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.lunar.icu',
    'https://api.piped.privacydev.net',
  ];

  /// Extract highest quality audio stream URL for a song
  static Future<String?> getAudioStreamUrl(Song song) async {
    // 1. Try Piped API for direct unthrottled audio streams
    try {
      String searchQuery = '${song.title} ${song.artist}';
      for (final instance in _pipedInstances) {
        try {
          final searchUri = Uri.parse('$instance/search?q=${Uri.encodeComponent(searchQuery)}&filter=music_songs');
          final searchResp = await http.get(searchUri).timeout(const Duration(seconds: 3));
          if (searchResp.statusCode == 200) {
            final searchData = json.decode(searchResp.body);
            final items = searchData['items'] as List?;
            if (items != null && items.isNotEmpty) {
              final videoId = items.first['url']?.toString().replaceAll('/watch?v=', '');
              if (videoId != null && videoId.isNotEmpty) {
                final streamUri = Uri.parse('$instance/streams/$videoId');
                final streamResp = await http.get(streamUri).timeout(const Duration(seconds: 3));
                if (streamResp.statusCode == 200) {
                  final streamData = json.decode(streamResp.body);
                  final audioStreams = streamData['audioStreams'] as List?;
                  if (audioStreams != null && audioStreams.isNotEmpty) {
                    final bestAudio = audioStreams.firstWhere(
                      (s) => s['mimeType']?.toString().contains('audio/mp4') ?? false,
                      orElse: () => audioStreams.first,
                    );
                    final url = bestAudio['url']?.toString();
                    if (url != null && url.isNotEmpty) {
                      print('Piped audio stream resolved: $url');
                      return url;
                    }
                  }
                }
              }
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      print('Piped API search error: $e');
    }

    // 2. Try YoutubeExplode Dart library
    final yt = YoutubeExplode();
    try {
      String searchQuery = '${song.title} ${song.artist} audio';
      final searchResults = await yt.search.search(searchQuery).timeout(const Duration(seconds: 4));
      if (searchResults.isNotEmpty) {
        final video = searchResults.first;
        final videoId = video.id.value;
        final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 4));
        final audioStreams = manifest.audioOnly;
        if (audioStreams.isNotEmpty) {
          final highestBitrateAudio = audioStreams.withHighestBitrate();
          final url = highestBitrateAudio.url.toString();
          print('YoutubeExplode stream resolved: $url');
          return url;
        }
      }
    } catch (e) {
      print('YoutubeExplode search error: $e');
    } finally {
      yt.close();
    }

    // 3. Fallback to iTunes previewUrl if YouTube search is unavailable or throttled
    if (song.previewUrl != null && song.previewUrl!.isNotEmpty) {
      print('Fallback to iTunes previewUrl stream');
      return song.previewUrl;
    }

    return null;
  }
}
