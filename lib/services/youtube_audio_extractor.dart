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

  static String _cleanQuery(String title, String artist) {
    String cleanTitle = title
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'- Single|- EP|Official Audio|Official Video|Lyric Video|Audio', caseSensitive: false), '')
        .trim();
    return '$cleanTitle $artist audio'.trim();
  }

  /// Asynchronously pre-fetch stream URL for a song in background (0ms latency on next/prev)
  static void preFetchStreamUrl(Song song) {
    if (_streamCache.containsKey(song.id) && !_streamCache[song.id]!.isExpired) return;
    getAudioStreamUrl(song).then((_) {}).catchError((_) {});
  }

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
      // 1. Clean query for high accuracy YouTube search
      final searchQuery = _cleanQuery(song.title, song.artist);
      final videoList = await _yt.search.getVideos(searchQuery).timeout(const Duration(seconds: 6));

      Video? selectedVideo;
      if (videoList.isNotEmpty) {
        final songFirstWord = song.title.trim().toLowerCase().split(' ').firstWhere(
              (w) => w.length > 2,
              orElse: () => song.title.trim().toLowerCase().split(' ').first,
            );

        selectedVideo = videoList.firstWhere(
          (v) => v.title.toLowerCase().contains(songFirstWord),
          orElse: () => videoList.first,
        );
      } else {
        // Fallback: try raw query
        final fallbackList = await _yt.search.getVideos('${song.title} ${song.artist}').timeout(const Duration(seconds: 5));
        if (fallbackList.isNotEmpty) {
          selectedVideo = fallbackList.first;
        }
      }

      if (selectedVideo == null) return null;

      final videoId = selectedVideo.id.value;
      print('Exact YouTube Video Matched: ${selectedVideo.title} (Duration: ${selectedVideo.duration})');

      // 2. Resolve stream manifest
      final manifest = await _yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 6));

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
