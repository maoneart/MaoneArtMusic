import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class YoutubeAudioExtractor {
  /// Fast unthrottled audio stream extractor for a song
  static Future<String?> getAudioStreamUrl(Song song) async {
    final yt = YoutubeExplode();
    try {
      // 1. Fast video search with 5s timeout
      String searchQuery = '${song.title} ${song.artist}';
      final videoList = await yt.search.getVideos(searchQuery).timeout(const Duration(seconds: 5));
      if (videoList.isEmpty) return null;

      final video = videoList.firstWhere(
        (v) => v.title.toLowerCase().contains(song.title.toLowerCase().split(' ').first),
        orElse: () => videoList.first,
      );

      final videoId = video.id.value;

      // 2. Fast stream manifest resolution with 5s timeout
      final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 5));
      
      // Prefer Muxed MP4 stream (unthrottled 200 OK)
      if (manifest.muxed.isNotEmpty) {
        return manifest.muxed.withHighestBitrate().url.toString();
      }

      if (manifest.audioOnly.isNotEmpty) {
        return manifest.audioOnly.withHighestBitrate().url.toString();
      }
    } catch (e) {
      print('Fast YouTube Audio Extractor error: $e');
    } finally {
      yt.close();
    }
    return null;
  }
}
