import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class _CachedStream {
  final List<String> urls;
  final DateTime timestamp;
  _CachedStream(this.urls, this.timestamp);

  // YouTube audio stream URLs are generally valid for 5 to 6 hours
  bool get isExpired => DateTime.now().difference(timestamp).inHours >= 5;
}

class YoutubeAudioExtractor {
  static final YoutubeExplode _yt = YoutubeExplode();
  static final Map<String, _CachedStream> _streamCache = {};
  static final Map<String, Future<List<String>>> _inFlightRequests = {};

  static void clearCache() {
    _streamCache.clear();
    _inFlightRequests.clear();
  }

  /// Selects audio stream based on quality preferences (Prioritizing AAC/M4A 140 for 0ms startup)
  static AudioStreamInfo _selectAudioQuality(List<AudioStreamInfo> sources, String quality) {
    if (sources.isEmpty) throw Exception("No audio sources found");
    final sorted = sources.sortByBitrate();

    if (quality == 'low') {
      return sorted.first;
    } else if (quality == 'medium') {
      return sorted[sorted.length ~/ 2];
    } else {
      // High / default: Prefer AAC/M4A (tag 140) which starts instantly on Android ExoPlayer
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
    if (_inFlightRequests.containsKey(cacheKey)) return;

    getAudioStreamCandidateUrls(song, quality: quality).then((_) {}).catchError((_) {});
  }

  /// Batch pre-fetch streams sequentially with delay to avoid choking network bandwidth
  static void preFetchBatch(List<Song> songs, {String quality = 'high', int limit = 2}) {
    int count = 0;
    for (final song in songs) {
      if (count >= limit) break;
      final delayMs = count * 750;
      Future.delayed(Duration(milliseconds: delayMs), () {
        preFetchStreamUrl(song, quality: quality);
      });
      count++;
    }
  }

  /// Returns candidate audio stream URLs in priority order with instant caching & deduplication
  static Future<List<String>> getAudioStreamCandidateUrls(Song song, {String quality = 'high'}) async {
    final cacheKey = '${song.id}_$quality';

    // 1. In-memory RAM Cache Check (0 ms)
    if (_streamCache.containsKey(cacheKey)) {
      final cached = _streamCache[cacheKey]!;
      if (!cached.isExpired && cached.urls.isNotEmpty) {
        return cached.urls;
      }
    }

    // 2. In-Flight Deduplication (Join existing ongoing request if already running)
    if (_inFlightRequests.containsKey(cacheKey)) {
      return await _inFlightRequests[cacheKey]!;
    }

    // 3. Persistent Disk Cache Check (< 5 ms)
    try {
      final prefs = await SharedPreferences.getInstance();
      final diskData = prefs.getString('yt_stream_cache_$cacheKey');
      if (diskData != null && diskData.isNotEmpty) {
        final Map<String, dynamic> jsonMap = json.decode(diskData);
        final ts = DateTime.tryParse(jsonMap['ts'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (DateTime.now().difference(ts).inHours < 5) {
          final List<dynamic> rawUrls = jsonMap['urls'] ?? [];
          final urls = rawUrls.map((u) => u.toString()).toList();
          if (urls.isNotEmpty) {
            _streamCache[cacheKey] = _CachedStream(urls, ts);
            return urls;
          }
        }
      }
    } catch (_) {}

    // 4. Start single-flight network extraction
    final extractionFuture = _extractCandidateUrlsInternal(song, quality: quality, cacheKey: cacheKey);
    _inFlightRequests[cacheKey] = extractionFuture;

    try {
      final urls = await extractionFuture;
      return urls;
    } finally {
      _inFlightRequests.remove(cacheKey);
    }
  }

  static Future<List<String>> _extractCandidateUrlsInternal(Song song, {required String quality, required String cacheKey}) async {
    final List<String> candidateUrls = [];
    final String? directVideoId = song.youtubeId;

    // A. Direct Video ID Extraction
    if (directVideoId != null && directVideoId.isNotEmpty) {
      if (song.isLive) {
        try {
          final liveUrl = await _yt.videos.streamsClient
              .getHttpLiveStreamUrl(VideoId(directVideoId))
              .timeout(const Duration(seconds: 6));
          if (liveUrl.isNotEmpty) {
            candidateUrls.add(liveUrl);
            _saveToCaches(cacheKey, candidateUrls);
            return candidateUrls;
          }
        } catch (_) {}
      }

      try {
        final manifest = await _yt.videos.streamsClient
            .getManifest(directVideoId)
            .timeout(const Duration(seconds: 7));

        if (manifest.audioOnly.isNotEmpty) {
          // Primary selected stream (AAC / Tag 140)
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

        // Add muxed video stream as extra fallback
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
          _saveToCaches(cacheKey, candidateUrls);
          return candidateUrls;
        }
      } catch (e) {
        print('Direct manifest extraction notice for $directVideoId: $e');
      }
    }

    // B. Search Fallback (Only if directVideoId was missing or failed)
    try {
      final String searchQuery = '${song.title} ${song.artist}'
          .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '')
          .trim();

      List<Video> videoList = [];
      try {
        final searchResults = await _yt.search.search(searchQuery).timeout(const Duration(seconds: 5));
        videoList = searchResults.whereType<Video>().toList();
      } catch (_) {}

      if (videoList.isEmpty) {
        try {
          final fallbackResults = await _yt.search.search(song.title).timeout(const Duration(seconds: 5));
          videoList.addAll(fallbackResults.whereType<Video>());
        } catch (_) {}
      }

      if (videoList.isNotEmpty) {
        final candidates = videoList.where((v) {
          final seconds = v.duration?.inSeconds ?? 0;
          return seconds <= 600 && seconds >= 30;
        }).take(3);

        for (final video in candidates) {
          try {
            final manifest = await _yt.videos.streamsClient
                .getManifest(video.id.value)
                .timeout(const Duration(seconds: 5));

            if (manifest.audioOnly.isNotEmpty) {
              final primary = _selectAudioQuality(manifest.audioOnly.toList(), quality);
              candidateUrls.add(primary.url.toString());
            } else if (manifest.muxed.isNotEmpty) {
              candidateUrls.add(manifest.muxed.withHighestBitrate().url.toString());
            }

            if (candidateUrls.isNotEmpty) {
              _saveToCaches(cacheKey, candidateUrls);
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

  static void _saveToCaches(String cacheKey, List<String> urls) {
    final now = DateTime.now();
    _streamCache[cacheKey] = _CachedStream(urls, now);

    // Save to Disk Cache asynchronously in background
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = json.encode({
          'urls': urls,
          'ts': now.toIso8601String(),
        });
        await prefs.setString('yt_stream_cache_$cacheKey', data);
      } catch (_) {}
    });
  }

  /// Convenience method to get top audio stream URL
  static Future<String?> getAudioStreamUrl(Song song, {String quality = 'high'}) async {
    final urls = await getAudioStreamCandidateUrls(song, quality: quality);
    return urls.isNotEmpty ? urls.first : null;
  }
}
