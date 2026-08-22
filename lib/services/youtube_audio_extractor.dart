import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class YoutubeAudioExtractor {
  /// Extract highest quality full-length audio stream URL for a song from YouTube
  static Future<String?> getAudioStreamUrl(Song song) async {
    final yt = YoutubeExplode();
    try {
      String searchQuery = '${song.title} ${song.artist} audio';
      
      // 1. Search YouTube for full track (give 12s timeout for full manifest resolution)
      final searchResults = await yt.search.search(searchQuery).timeout(const Duration(seconds: 12));
      if (searchResults.isEmpty) {
        return null;
      }

      final video = searchResults.first;
      final videoId = video.id.value;

      // 2. Get full stream manifest
      final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 12));
      final audioStreams = manifest.audioOnly;

      if (audioStreams.isNotEmpty) {
        // Get highest bitrate full-length audio stream
        final highestBitrateAudio = audioStreams.withHighestBitrate();
        final url = highestBitrateAudio.url.toString();
        print('Full YouTube Audio Stream resolved: $url');
        return url;
      }
    } catch (e) {
      print('Error extracting full YouTube audio stream: $e');
    } finally {
      yt.close();
    }
    return null;
  }
}
