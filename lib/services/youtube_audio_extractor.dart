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

  /// Extract highest quality unthrottled audio stream URL for a song from YouTube with candidate retries
  static Future<String?> getAudioStreamUrl(Song song) async {
    // Return cached URL if valid (max 45 mins)
    if (_streamCache.containsKey(song.id)) {
      final cached = _streamCache[song.id]!;
      if (!cached.isExpired) {
        print('⚡ Stream URL loaded from memory cache for: ${song.title}');
        return cached.url;
      }
    }

    try {
      // 1. Direct search query
      final String searchQuery = '${song.title} ${song.artist}'.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '').trim();
      final searchResults = await _yt.search.search(searchQuery).timeout(const Duration(seconds: 8));
      final videoList = searchResults.whereType<Video>().toList();

      if (videoList.isEmpty) {
        // Fallback: try title only
        final fallbackResults = await _yt.search.search(song.title).timeout(const Duration(seconds: 6));
        videoList.addAll(fallbackResults.whereType<Video>());
      }

      if (videoList.isEmpty) return null;

      // 2. Prioritize official Topic channels (- Topic) or official audio
      final candidates = List<Video>.from(videoList.take(5));
      candidates.sort((a, b) {
        final aTopic = a.author.toLowerCase().contains('- topic') || a.title.toLowerCase().contains('audio') || a.title.toLowerCase().contains('official');
        final bTopic = b.author.toLowerCase().contains('- topic') || b.title.toLowerCase().contains('audio') || b.title.toLowerCase().contains('official');
        if (aTopic && !bTopic) return -1;
        if (!aTopic && bTopic) return 1;
        return 0;
      });

      // 3. Try top candidates in order
      for (final selectedVideo in candidates) {
        try {
          final videoId = selectedVideo.id.value;
          print('YouTube Video Candidate Matched: ${selectedVideo.title} by ${selectedVideo.author}');

          final manifest = await _yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 6));

          String? selectedUrl;
          if (manifest.audioOnly.isNotEmpty) {
            final audioStreams = manifest.audioOnly.toList();
            // Prefer mp4 / m4a container for max ExoPlayer / AVPlayer compatibility
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
        } catch (candidateError) {
          print('Candidate failed, trying next candidate: $candidateError');
          continue;
        }
      }
    } catch (e) {
      print('Error extracting YouTube audio stream for ${song.title}: $e');
    }
    return null;
  }
}

