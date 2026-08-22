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

  /// Asynchronously pre-fetch stream URL for a song in background (0ms latency on next/prev)
  static void preFetchStreamUrl(Song song) {
    if (_streamCache.containsKey(song.id) && !_streamCache[song.id]!.isExpired) return;
    getAudioStreamUrl(song).then((_) {}).catchError((_) {});
  }

  /// Extract highest quality unthrottled audio stream URL for a song with instant CDN priority and YouTube fallback
  static Future<String?> getAudioStreamUrl(Song song) async {
    // 1. Return cached YouTube URL if valid (max 45 mins)
    if (_streamCache.containsKey(song.id)) {
      final cached = _streamCache[song.id]!;
      if (!cached.isExpired) {
        print('⚡ YouTube stream loaded from cache for: ${song.title}');
        return cached.url;
      }
    }

    // 2. Direct high-speed CDN stream (iTunes/Deezer/Apple audio CDN) -> INSTANT 0ms PLAYBACK!
    if (song.streamUrl != null && song.streamUrl!.isNotEmpty) {
      print('⚡ Using instant high-speed audio CDN for: ${song.title}');
      return song.streamUrl;
    }

    // 3. Fallback to YouTube Explode extraction for custom tracks with 3s timeout
    try {
      final String searchQuery = '${song.title} ${song.artist}'.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '').trim();
      List<Video> videoList = [];
      try {
        final searchResults = await _yt.search.search(searchQuery).timeout(const Duration(seconds: 3));
        videoList = searchResults.whereType<Video>().toList();
      } catch (_) {}

      if (videoList.isEmpty) {
        try {
          final fallbackResults = await _yt.search.search(song.title).timeout(const Duration(seconds: 3));
          videoList.addAll(fallbackResults.whereType<Video>());
        } catch (_) {}
      }

      if (videoList.isNotEmpty) {
        final candidates = List<Video>.from(videoList.take(3));
        for (final selectedVideo in candidates) {
          try {
            final videoId = selectedVideo.id.value;
            final manifest = await _yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 3));

            String? selectedUrl;
            if (manifest.audioOnly.isNotEmpty) {
              final audioStreams = manifest.audioOnly.toList();
              final preferredStream = audioStreams.firstWhere(
                (s) => s.container.name.toLowerCase().contains('mp4') || s.container.name.toLowerCase().contains('m4a') || s.audioCodec.toLowerCase().contains('mp4a'),
                orElse: () => manifest.audioOnly.withHighestBitrate(),
              );
              selectedUrl = preferredStream.url.toString();
            } else if (manifest.muxed.isNotEmpty) {
              selectedUrl = manifest.muxed.withHighestBitrate().url.toString();
            }

            if (selectedUrl != null && selectedUrl.isNotEmpty) {
              _streamCache[song.id] = _CachedStream(selectedUrl, DateTime.now());
              return selectedUrl;
            }
          } catch (_) {
            continue;
          }
        }
      }
    } catch (e) {
      print('YouTube extraction notice for ${song.title}: $e');
    }

    return null;
  }
}


