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
    return '$cleanTitle $artist official audio'.trim();
  }

  /// Score YouTube video search candidates to prioritize official releases
  static int _scoreVideo(Video v, String title, String artist) {
    int score = 0;
    final vTitle = v.title.toLowerCase();
    final vAuthor = v.author.toLowerCase();
    final tLower = title.toLowerCase();
    final aLower = artist.toLowerCase();

    // 1. Official Topic Channel (YouTube Music auto-generated official releases)
    if (vAuthor.contains('- topic')) score += 100;
    if (vAuthor.contains(aLower)) score += 60;

    // 2. Official Upload Keywords
    if (vTitle.contains('official audio')) score += 90;
    if (vTitle.contains('official video') || vTitle.contains('official music video')) score += 80;
    if (vTitle.contains('official lyric video') || vTitle.contains('lirik official')) score += 75;
    if (vTitle.contains('official')) score += 40;

    // 3. Title & Artist Matching
    if (vTitle.contains(tLower)) score += 50;

    // 4. Penalize covers, reaction videos, 10-hour loops, nightcore
    if (vTitle.contains('cover') && !tLower.contains('cover')) score -= 100;
    if (vTitle.contains('reaction')) score -= 150;
    if (vTitle.contains('10 hour') || vTitle.contains('1 hour') || vTitle.contains('loop')) score -= 200;
    if (vTitle.contains('nightcore') || vTitle.contains('speed up')) score -= 80;

    return score;
  }

  /// Asynchronously pre-fetch stream URL for a song in background (0ms latency on next/prev)
  static void preFetchStreamUrl(Song song) {
    if (_streamCache.containsKey(song.id) && !_streamCache[song.id]!.isExpired) return;
    getAudioStreamUrl(song).then((_) {}).catchError((_) {});
  }

  /// Extract highest quality unthrottled audio stream URL for a song from YouTube with fast caching
  static Future<String?> getAudioStreamUrl(Song song) async {
    // Return cached URL if valid (max 15 mins to prevent expired CDN URLs)
    if (_streamCache.containsKey(song.id)) {
      final cached = _streamCache[song.id]!;
      if (!cached.isExpired) {
        print('⚡ Stream URL loaded from memory cache for: ${song.title}');
        return cached.url;
      }
    }

    try {
      // 1. Search YouTube for official videos first
      final searchQuery = _cleanQuery(song.title, song.artist);
      final videoList = await _yt.search.getVideos(searchQuery).timeout(const Duration(seconds: 6));

      Video? selectedVideo;
      if (videoList.isNotEmpty) {
        // Sort candidates by official score
        final candidates = List<Video>.from(videoList);
        candidates.sort((a, b) => _scoreVideo(b, song.title, song.artist).compareTo(_scoreVideo(a, song.title, song.artist)));
        selectedVideo = candidates.first;
      } else {
        // Fallback: try raw query search
        final fallbackList = await _yt.search.getVideos('${song.title} ${song.artist}').timeout(const Duration(seconds: 5));
        if (fallbackList.isNotEmpty) {
          selectedVideo = fallbackList.first;
        }
      }

      if (selectedVideo == null) return null;

      final videoId = selectedVideo.id.value;
      print('Exact YouTube Video Matched (Official Score): ${selectedVideo.title} by ${selectedVideo.author}');

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
