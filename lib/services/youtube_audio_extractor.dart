import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class YoutubeAudioExtractor {
  /// Extract highest quality audio stream URL for a song
  static Future<String?> getAudioStreamUrl(Song song) async {
    final yt = YoutubeExplode();
    try {
      String searchQuery = '${song.title} ${song.artist} audio';
      
      // 1. Search YouTube for the video
      final searchResults = await yt.search.search(searchQuery);
      if (searchResults.isEmpty) {
        return null;
      }

      final video = searchResults.first;
      final videoId = video.id.value;

      // 2. Get manifest for audio stream
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly;

      if (audioStreams.isNotEmpty) {
        // Get highest bitrate audio stream
        final highestBitrateAudio = audioStreams.withHighestBitrate();
        return highestBitrateAudio.url.toString();
      }
    } catch (e) {
      print('Error extracting YouTube audio stream: $e');
    } finally {
      yt.close();
    }
    return null;
  }
}
