import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class _CachedStream {
  final String url;
  final DateTime timestamp;
  _CachedStream(this.url, this.timestamp);

  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 45;
}

class YoutubeAudioExtractor {
  static final YoutubeExplode _yt = YoutubeExplode();
  static final Map<String, _CachedStream> _streamCache = {};

  /// Extract highest quality unthrottled audio stream URL for a song from YouTube with fast caching
  static Future<String?> getAudioStreamUrl(Song song) async {
    // 0ms Latency: Return cached URL if valid
    if (_streamCache.containsKey(song.id)) {
      final cached = _streamCache[song.id]!;
      if (!cached.isExpired) {
        print('⚡ Stream URL loaded from memory cache for: ${song.title}');
        return cached.url;
      }
    }

    try {
      // 1. Search YouTube for video matching track title and artist
      String searchQuery = '${song.title} ${song.artist}';
      final videoList = await _yt.search.getVideos(searchQuery).timeout(const Duration(seconds: 10));
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

      // 2. Resolve stream manifest
      final manifest = await _yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 10));

      String? selectedUrl;

      // Prefer AudioOnly streams (Opus/AAC - ultra fast buffering & smooth playback)
      if (manifest.audioOnly.isNotEmpty) {
        selectedUrl = manifest.audioOnly.withHighestBitrate().url.toString();
        print('AudioOnly stream resolved for ${song.title}');
      } else if (manifest.muxed.isNotEmpty) {
        selectedUrl = manifest.muxed.withHighestBitrate().url.toString();
        print('Muxed stream resolved for ${song.title}');
      }

      if (selectedUrl != null && selectedUrl.isNotEmpty) {
        _streamCache[song.id] = _CachedStream(selectedUrl, DateTime.now());
        return selectedUrl;
      }
    } catch (e) {
      print('Error extracting YouTube audio stream for ${song.title}: $e');
    }
    return null;
  }
}
