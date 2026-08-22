import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class YoutubeAudioExtractor {
  /// Extract highest quality full-length audio stream URL for a song from YouTube
  static Future<String?> getAudioStreamUrl(Song song) async {
    final yt = YoutubeExplode();
    try {
      // 1. Search YouTube specifically for individual videos matching track title and artist
      String searchQuery = '${song.title} ${song.artist}';
      final videoList = await yt.search.getVideos(searchQuery).timeout(const Duration(seconds: 15));
      if (videoList.isEmpty) {
        return null;
      }

      // Filter for best video match
      final video = videoList.firstWhere(
        (v) => v.title.toLowerCase().contains(song.title.toLowerCase().split(' ').first),
        orElse: () => videoList.first,
      );

      final videoId = video.id.value;
      print('Exact YouTube Video Matched: ${video.title} (Duration: ${video.duration})');

      // 2. Resolve full audio stream manifest
      final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 15));
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
