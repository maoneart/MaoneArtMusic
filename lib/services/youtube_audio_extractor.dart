import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class _CachedStream {
  final List<String> urls;
  final DateTime timestamp;
  _CachedStream(this.urls, this.timestamp);

  // YouTube audio stream tokens are valid for up to 90-120 mins
  bool get isExpired => DateTime.now().difference(timestamp).inMinutes >= 90;
}

class YoutubeAudioExtractor {
  static final YoutubeExplode _yt = YoutubeExplode();
  static final Map<String, _CachedStream> _streamCache = {};
  static final Map<String, Future<List<String>>> _inFlightRequests = {};

  // Exact Musify fallback clients order (visionOs is currently the only tokenless client)
  static const fallbackClients = [YoutubeApiClient.visionOs, YoutubeApiClient.android];

  // Map of videoId -> client that served its stream URLs
  static final Map<String, YoutubeApiClient> _songClients = {};

  static void clearCache() {
    _streamCache.clear();
    _inFlightRequests.clear();
    _songClients.clear();
  }

  /// Evict stale or broken stream URLs for a specific song ID immediately
  static void evict(String songId) {
    final cleanId = songId.startsWith('yt_') ? songId.substring(3) : songId;
    _songClients.remove(songId);
    _songClients.remove(cleanId);
    _streamCache.removeWhere((k, _) => k.contains(songId) || k.contains(cleanId));
    _inFlightRequests.removeWhere((k, _) => k.contains(songId) || k.contains(cleanId));
    SharedPreferences.getInstance().then((prefs) {
      final keys = prefs.getKeys().where((k) => k.contains(songId) || k.contains(cleanId));
      for (final k in keys) {
        prefs.remove(k);
      }
    }).catchError((_) {});
  }

  /// Returns exact headers required by Google Video CDN for the client that minted the stream URL.
  /// Mismatched User-Agent will cause Google CDN to return HTTP 403 Forbidden!
  static Map<String, String> getStreamHeaders(String? songId) {
    final cleanId = (songId != null && songId.startsWith('yt_')) ? songId.substring(3) : songId;
    final client = _songClients[songId] ?? _songClients[cleanId] ?? fallbackClients.first;
    final userAgent = client.payload['context']?['client']?['userAgent'];
    return {
      if (userAgent is String) 'User-Agent': userAgent,
      'Accept': '*/*',
      'Connection': 'keep-alive',
      for (final entry in client.headers.entries) entry.key: '${entry.value}',
    };
  }

  /// Pre-warm YouTube disk cache into RAM at app launch
  static void warmUp() {
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs.getKeys().where((k) => k.startsWith('yt_stream_cache_'));
        for (final k in keys) {
          final diskData = prefs.getString(k);
          if (diskData != null && diskData.isNotEmpty) {
            try {
              final Map<String, dynamic> jsonMap = json.decode(diskData);
              final ts = DateTime.tryParse(jsonMap['ts'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
              if (DateTime.now().difference(ts).inMinutes < 90) {
                final List<dynamic> rawUrls = jsonMap['urls'] ?? [];
                final urls = rawUrls.map((u) => u.toString()).toList();
                if (urls.isNotEmpty) {
                  final cacheKey = k.replaceFirst('yt_stream_cache_', '');
                  _streamCache[cacheKey] = _CachedStream(urls, ts);
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    });
  }

  /// Musify's exact audio compatibility scoring:
  /// Filter out Dolby codecs (ec-3, ac-3, eac3, dolby) which cause ExoPlayer hangs.
  /// Score 3 = AAC / M4A (starts 0ms on Android ExoPlayer without transcoding).
  /// Score 2 = Opus / Vorbis.
  /// Score 0 = Incompatible Dolby codec.
  static int _audioCompatibilityScore(AudioStreamInfo stream) {
    final codec = stream.audioCodec.toLowerCase();
    final container = stream.container.name.toLowerCase();

    if (codec.contains('ec-3') ||
        codec.contains('ac-3') ||
        codec.contains('eac3') ||
        codec.contains('dolby')) {
      return 0;
    }

    if ((codec.contains('mp4a') || codec.contains('aac')) &&
        (container == 'mp4' || container == 'm4a')) {
      return 3;
    }

    if (codec.contains('opus') || codec.contains('vorbis')) {
      return 2;
    }

    return 1;
  }

  /// Selects audio stream based on quality preferences using Musify's ranking algorithm
  static AudioStreamInfo _selectAudioQuality(List<AudioStreamInfo> sources, String quality) {
    if (sources.isEmpty) throw Exception("No audio sources found");
    final compatible = sources.where((s) => _audioCompatibilityScore(s) >= 2).toList();
    final pool = (compatible.isNotEmpty ? compatible : List<AudioStreamInfo>.from(sources))
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

    if (quality == 'low') {
      return pool.last;
    } else if (quality == 'medium') {
      return pool[(pool.length - 1) ~/ 2];
    } else {
      return pool.first;
    }
  }

  /// Asynchronously pre-fetch stream URLs for next track in background
  static void preFetchStreamUrl(Song song, {String quality = 'high'}) {
    final cacheKey = '${song.id}_$quality';
    if (_streamCache.containsKey(cacheKey) && !_streamCache[cacheKey]!.isExpired) return;
    if (_inFlightRequests.containsKey(cacheKey)) return;

    getAudioStreamCandidateUrls(song, quality: quality).then((_) {}).catchError((_) {});
  }

  /// Batch pre-fetch streams sequentially with micro-delay to avoid choking network bandwidth
  static void preFetchBatch(List<Song> songs, {String quality = 'high', int limit = 4}) {
    int count = 0;
    for (final song in songs) {
      if (count >= limit) break;
      final delayMs = count * 350;
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
        if (DateTime.now().difference(ts).inMinutes < 90) {
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

  /// Multi-client manifest fetcher with exact Musify client fallback chain
  static Future<StreamManifest?> _fetchManifestSafely(String videoId) async {
    for (final client in fallbackClients) {
      try {
        final manifest = await _yt.videos.streamsClient
            .getManifest(videoId, ytClients: [client], requireWatchPage: false)
            .timeout(const Duration(seconds: 5));
        if (manifest.audioOnly.isNotEmpty) {
          _songClients[videoId] = client;
          return manifest;
        }
      } catch (_) {}
    }

    // Secondary fallback: TV and Safari clients
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(
            videoId,
            ytClients: [
              YoutubeApiClient.tv,
              YoutubeApiClient.safari,
            ],
            requireWatchPage: false,
          )
          .timeout(const Duration(seconds: 4));
      if (manifest.audioOnly.isNotEmpty) {
        _songClients[videoId] = YoutubeApiClient.tv;
        return manifest;
      }
    } catch (_) {}

    // Final fallback: Standard getManifest
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 4));
      if (manifest.audioOnly.isNotEmpty) {
        _songClients[videoId] = fallbackClients.first;
        return manifest;
      }
    } catch (_) {}

    return null;
  }

  static Future<List<String>> _extractCandidateUrlsInternal(Song song, {required String quality, required String cacheKey}) async {
    final List<String> candidateUrls = [];
    final String? directVideoId = song.youtubeId ??
        (song.id.startsWith('yt_')
            ? song.id.substring(3)
            : (song.id.length == 11 ? song.id : null));

    // A. Direct Video ID Extraction
    if (directVideoId != null && directVideoId.isNotEmpty) {
      if (song.isLive) {
        try {
          final liveUrl = await _yt.videos.streamsClient
              .getHttpLiveStreamUrl(VideoId(directVideoId))
              .timeout(const Duration(seconds: 4));
          if (liveUrl.isNotEmpty) {
            candidateUrls.add(liveUrl);
            _saveToCaches(cacheKey, candidateUrls);
            return candidateUrls;
          }
        } catch (_) {}
      }

      final manifest = await _fetchManifestSafely(directVideoId);

      if (manifest != null && (manifest.audioOnly.isNotEmpty || manifest.muxed.isNotEmpty)) {
        if (manifest.audioOnly.isNotEmpty) {
          try {
            final primary = _selectAudioQuality(manifest.audioOnly.toList(), quality);
            candidateUrls.add(primary.url.toString());
          } catch (_) {}

          // Add remaining audio streams as failovers (sorted by bitrate)
          final sortedAudio = manifest.audioOnly.sortByBitrate().reversed;
          for (final a in sortedAudio) {
            if (_audioCompatibilityScore(a) > 0) {
              final urlStr = a.url.toString();
              if (!candidateUrls.contains(urlStr)) {
                candidateUrls.add(urlStr);
              }
            }
          }
        }

        // Add muxed video stream as extra fallback
        if (manifest.muxed.isNotEmpty) {
          final muxedSorted = manifest.muxed.sortByBitrate().reversed;
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
            final manifest = await _fetchManifestSafely(video.id.value);

            if (manifest != null && (manifest.audioOnly.isNotEmpty || manifest.muxed.isNotEmpty)) {
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
