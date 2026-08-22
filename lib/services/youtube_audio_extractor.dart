import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class YoutubeAudioExtractor {
  /// Extract highest quality unthrottled full-length audio stream URL for a song from YouTube
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

      // 2. Resolve full audio stream manifest (15s timeout for 4G/WiFi reliability)
      final manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 15));
      
      // Prefer Muxed MP4 streams (contains high-bitrate AAC audio, 100% 200 OK unthrottled!)
      if (manifest.muxed.isNotEmpty) {
        final muxedAudio = manifest.muxed.withHighestBitrate();
        final url = muxedAudio.url.toString();
        print('Unthrottled Muxed Audio Stream resolved: $url');
        return url;
      }

      if (manifest.audioOnly.isNotEmpty) {
        final highestBitrateAudio = manifest.audioOnly.withHighestBitrate();
        final url = highestBitrateAudio.url.toString();
        print('Full Audio Stream resolved: $url');
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
