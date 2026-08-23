import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class _CachedStream {
  final String url;
  final DateTime timestamp;
  _CachedStream(this.url, this.timestamp);

  bool get isExpired => DateTime.now().difference(timestamp).inHours > 4;
}

class YoutubeAudioExtractor {
  static final YoutubeExplode _yt = YoutubeExplode();
  static final Map<String, _CachedStream> _streamCache = {};

  static void clearCache() {
    _streamCache.clear();
  }

  /// Selects audio stream based on quality preferences (Musify approach)
  static AudioStreamInfo _selectAudioQuality(List<AudioStreamInfo> sources, String quality) {
    if (sources.isEmpty) throw Exception("No audio sources found");
    final sorted = sources.sortByBitrate();

    if (quality == 'low') {
      return sorted.last;
    } else if (quality == 'medium') {
      return sorted[sorted.length ~/ 2];
    } else {
      // High / default: Prefer AAC/M4A (tag 140) or highest bitrate
      return sorted.firstWhere(
        (s) => s.tag == 140 || s.container.name.toLowerCase() == 'm4a' || s.audioCodec.toLowerCase().contains('mp4a'),
        orElse: () => sorted.withHighestBitrate(),
      );
    }
  }

  /// Asynchronously pre-fetch stream URL for a song in background (0ms next song playback)
  static void preFetchStreamUrl(Song song, {String quality = 'high'}) {
    final cacheKey = '${song.id}_$quality';
    if (_streamCache.containsKey(cacheKey) && !_streamCache[cacheKey]!.isExpired) return;
    getAudioStreamUrl(song, quality: quality).then((_) {}).catchError((_) {});
  }

  /// Extract audio stream URL for a song using direct Musify stream engine
  static Future<String?> getAudioStreamUrl(Song song, {String quality = 'high'}) async {
    final cacheKey = '${song.id}_$quality';

    // 1. Check in-memory cache
    if (_streamCache.containsKey(cacheKey)) {
      final cached = _streamCache[cacheKey]!;
      if (!cached.isExpired) {
        return cached.url;
      }
    }

    final String? directVideoId = song.youtubeId;

    // 2. Direct Video ID extraction (Musify standard)
    if (directVideoId != null && directVideoId.isNotEmpty) {
      if (song.isLive) {
        try {
          final liveUrl = await _yt.videos.streamsClient
              .getHttpLiveStreamUrl(VideoId(directVideoId))
              .timeout(const Duration(seconds: 6));
          if (liveUrl.isNotEmpty) {
            _streamCache[cacheKey] = _CachedStream(liveUrl, DateTime.now());
            return liveUrl;
          }
        } catch (e) {
          print('Live stream extraction notice: $e');
        }
      }

      try {
        final manifest = await _yt.videos.streamsClient
            .getManifest(directVideoId)
            .timeout(const Duration(seconds: 6));

        if (manifest.audioOnly.isNotEmpty) {
          final selectedStream = _selectAudioQuality(manifest.audioOnly.toList(), quality);
          final url = selectedStream.url.toString();
          _streamCache[cacheKey] = _CachedStream(url, DateTime.now());
          return url;
        } else if (manifest.muxed.isNotEmpty) {
          final url = manifest.muxed.withHighestBitrate().url.toString();
          _streamCache[cacheKey] = _CachedStream(url, DateTime.now());
          return url;
        }
      } catch (e) {
        print('Direct video ID extraction notice for $directVideoId: $e');
      }
    }

    // 3. YouTube Explode Search Extraction with Compilation Video Filtering
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
        // Strict Filter: EXCLUDE compilation/mix videos (>10 mins, <45s, or titles with "full album", "kompilasi", "2 jam", "nonstop")
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
          }).take(5),
        );

        if (candidates.isEmpty) {
          candidates.addAll(videoList.where((v) => (v.duration?.inSeconds ?? 0) <= 600).take(3));
        }

        candidates.sort((a, b) {
          final aTopic = a.author.toLowerCase().contains('- topic') ||
              a.title.toLowerCase().contains('audio') ||
              a.title.toLowerCase().contains('official');
          final bTopic = b.author.toLowerCase().contains('- topic') ||
              b.title.toLowerCase().contains('audio') ||
              b.title.toLowerCase().contains('official');
          if (aTopic && !bTopic) return -1;
          if (!aTopic && bTopic) return 1;
          return 0;
        });

        for (final selectedVideo in candidates) {
          try {
            final videoId = selectedVideo.id.value;
            final manifest = await _yt.videos.streamsClient
                .getManifest(videoId)
                .timeout(const Duration(seconds: 5));

            String? selectedUrl;
            if (manifest.audioOnly.isNotEmpty) {
              final stream = _selectAudioQuality(manifest.audioOnly.toList(), quality);
              selectedUrl = stream.url.toString();
            } else if (manifest.muxed.isNotEmpty) {
              selectedUrl = manifest.muxed.withHighestBitrate().url.toString();
            }

            if (selectedUrl != null && selectedUrl.isNotEmpty) {
              _streamCache[cacheKey] = _CachedStream(selectedUrl, DateTime.now());
              return selectedUrl;
            }
          } catch (_) {
            continue;
          }
        }
      }
    } catch (e) {
      print('YouTube full stream search notice for ${song.title}: $e');
    }

    // 4. Invidious REST API fallback for Full-Length Audio Stream
    try {
      final String searchQuery = '${song.title} ${song.artist}'
          .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '')
          .trim();
      final invidiousInstances = [
        'https://inv.tux.pizza',
        'https://invidious.nerdvpn.de',
        'https://yewtu.be',
      ];

      for (final instance in invidiousInstances) {
        try {
          final searchRes = await http
              .get(Uri.parse('$instance/api/v1/search?q=${Uri.encodeComponent(searchQuery)}&type=video'))
              .timeout(const Duration(seconds: 4));
          if (searchRes.statusCode == 200) {
            final List results = json.decode(searchRes.body);
            final filtered = results.where((item) {
              final sec = item['lengthSeconds']?.toInt() ?? 0;
              return sec >= 45 && sec <= 600;
            }).toList();

            if (filtered.isNotEmpty) {
              final videoId = filtered.first['videoId'];
              final videoRes = await http
                  .get(Uri.parse('$instance/api/v1/videos/$videoId'))
                  .timeout(const Duration(seconds: 4));
              if (videoRes.statusCode == 200) {
                final data = json.decode(videoRes.body);
                final List adaptive = data['adaptiveFormats'] ?? [];
                final audioStreams = adaptive.where((s) => s['type'].toString().contains('audio/')).toList();
                if (audioStreams.isNotEmpty) {
                  final fullUrl = audioStreams.first['url'].toString();
                  _streamCache[cacheKey] = _CachedStream(fullUrl, DateTime.now());
                  return fullUrl;
                }
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    return null;
  }
}
