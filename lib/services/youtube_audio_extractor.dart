import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class _CachedStream {
  final List<String> urls;
  final DateTime timestamp;
  _CachedStream(this.urls, this.timestamp);

  bool get isExpired => DateTime.now().difference(timestamp).inHours > 3;
}

class YoutubeAudioExtractor {
  static final YoutubeExplode _yt = YoutubeExplode();
  static final Map<String, _CachedStream> _streamCache = {};

  static void clearCache() {
    _streamCache.clear();
  }

  /// Selects audio stream based on quality preferences
  static AudioStreamInfo _selectAudioQuality(List<AudioStreamInfo> sources, String quality) {
    if (sources.isEmpty) throw Exception("No audio sources found");
    final sorted = sources.sortByBitrate();

    if (quality == 'low') {
      return sorted.first;
    } else if (quality == 'medium') {
      return sorted[sorted.length ~/ 2];
    } else {
      // High / default: Prefer AAC/M4A (tag 140) or highest bitrate
      return sorted.firstWhere(
        (s) => s.tag == 140 || s.container.name.toLowerCase() == 'm4a' || s.audioCodec.toLowerCase().contains('mp4a'),
        orElse: () => sorted.last,
      );
    }
  }

  /// Asynchronously pre-fetch stream URLs for next track in background
  static void preFetchStreamUrl(Song song, {String quality = 'high'}) {
    final cacheKey = '${song.id}_$quality';
    if (_streamCache.containsKey(cacheKey) && !_streamCache[cacheKey]!.isExpired) return;
    getAudioStreamCandidateUrls(song, quality: quality).then((_) {}).catchError((_) {});
  }

  /// Batch pre-fetch streams for a list of songs in background for instant 0ms playback
  static void preFetchBatch(List<Song> songs, {String quality = 'high', int limit = 8}) {
    for (final song in songs.take(limit)) {
      preFetchStreamUrl(song, quality: quality);
    }
  }

  /// Returns candidate audio stream URLs in priority order for robust failover
  static Future<List<String>> getAudioStreamCandidateUrls(Song song, {String quality = 'high'}) async {
    final cacheKey = '${song.id}_$quality';

    // 1. Check in-memory cache
    if (_streamCache.containsKey(cacheKey)) {
      final cached = _streamCache[cacheKey]!;
      if (!cached.isExpired && cached.urls.isNotEmpty) {
        return cached.urls;
      }
    }

    final List<String> candidateUrls = [];
    final String? directVideoId = song.youtubeId;

    // 2. Direct Video ID Manifest Extraction
    if (directVideoId != null && directVideoId.isNotEmpty) {
      if (song.isLive) {
        try {
          final liveUrl = await _yt.videos.streamsClient
              .getHttpLiveStreamUrl(VideoId(directVideoId))
              .timeout(const Duration(seconds: 8));
          if (liveUrl.isNotEmpty) {
            candidateUrls.add(liveUrl);
            _streamCache[cacheKey] = _CachedStream(candidateUrls, DateTime.now());
            return candidateUrls;
          }
        } catch (e) {
          print('Live stream extraction notice: $e');
        }
      }

      try {
        final manifest = await _yt.videos.streamsClient
            .getManifest(directVideoId)
            .timeout(const Duration(seconds: 8));

        if (manifest.audioOnly.isNotEmpty) {
          // Primary selected stream
          try {
            final primary = _selectAudioQuality(manifest.audioOnly.toList(), quality);
            candidateUrls.add(primary.url.toString());
          } catch (_) {}

          // Add remaining audio streams as failovers
          final sortedAudio = manifest.audioOnly.sortByBitrate();
          for (final a in sortedAudio) {
            final urlStr = a.url.toString();
            if (!candidateUrls.contains(urlStr)) {
              candidateUrls.add(urlStr);
            }
          }
        }

        // Add muxed video streams as extra fallback
        if (manifest.muxed.isNotEmpty) {
          final muxedSorted = manifest.muxed.sortByBitrate();
          for (final m in muxedSorted) {
            final urlStr = m.url.toString();
            if (!candidateUrls.contains(urlStr)) {
              candidateUrls.add(urlStr);
            }
          }
        }

        if (candidateUrls.isNotEmpty) {
          _streamCache[cacheKey] = _CachedStream(candidateUrls, DateTime.now());
          return candidateUrls;
        }
      } catch (e) {
        print('Direct video ID extraction notice for $directVideoId: $e');
      }
    }

    // 3. YouTube Explode Search Fallback
    try {
      final String searchQuery = '${song.title} ${song.artist}'
          .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '')
          .trim();

      List<Video> videoList = [];
      try {
        final searchResults = await _yt.search.search(searchQuery).timeout(const Duration(seconds: 6));
        videoList = searchResults.whereType<Video>().toList();
      } catch (_) {}

      if (videoList.isEmpty) {
        try {
          final fallbackResults = await _yt.search.search(song.title).timeout(const Duration(seconds: 6));
          videoList.addAll(fallbackResults.whereType<Video>());
        } catch (_) {}
      }

      if (videoList.isNotEmpty) {
        // Filter out very long compilation loops
        final candidates = List<Video>.from(
          videoList.where((v) {
            final seconds = v.duration?.inSeconds ?? 0;
            final titleLower = v.title.toLowerCase();
            if (seconds > 600 || (seconds > 0 && seconds < 45)) return false;
            if (titleLower.contains('full album') ||
                titleLower.contains('kompilasi') ||
                titleLower.contains('nonstop') ||
                titleLower.contains('2 jam') ||
                titleLower.contains('1 jam')) {
              return false;
            }
            return true;
          }).take(4),
        );

        if (candidates.isEmpty) {
          candidates.addAll(videoList.where((v) => (v.duration?.inSeconds ?? 0) <= 600).take(2));
        }

        for (final video in candidates) {
          try {
            final manifest = await _yt.videos.streamsClient
                .getManifest(video.id.value)
                .timeout(const Duration(seconds: 6));

            if (manifest.audioOnly.isNotEmpty) {
              final primary = _selectAudioQuality(manifest.audioOnly.toList(), quality);
              candidateUrls.add(primary.url.toString());
            } else if (manifest.muxed.isNotEmpty) {
              candidateUrls.add(manifest.muxed.withHighestBitrate().url.toString());
            }

            if (candidateUrls.isNotEmpty) {
              _streamCache[cacheKey] = _CachedStream(candidateUrls, DateTime.now());
              return candidateUrls;
            }
          } catch (_) {
            continue;
          }
        }
      }
    } catch (e) {
      print('Search fallback notice for ${song.title}: $e');
    }

    return candidateUrls;
  }

  /// Convenience method to get top audio stream URL
  static Future<String?> getAudioStreamUrl(Song song, {String quality = 'high'}) async {
    final urls = await getAudioStreamCandidateUrls(song, quality: quality);
    return urls.isNotEmpty ? urls.first : null;
  }
}
