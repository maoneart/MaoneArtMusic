import 'dart:convert';
import 'package:http/http.dart' as http;
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

  /// Asynchronously pre-fetch stream URL for a song in background
  static void preFetchStreamUrl(Song song) {
    if (_streamCache.containsKey(song.id) && !_streamCache[song.id]!.isExpired) return;
    getAudioStreamUrl(song).then((_) {}).catchError((_) {});
  }

  /// Extract highest quality FULL-LENGTH audio stream URL for a song from YouTube
  static Future<String?> getAudioStreamUrl(Song song) async {
    // 1. Return cached full-length YouTube URL if valid (max 45 mins)
    if (_streamCache.containsKey(song.id)) {
      final cached = _streamCache[song.id]!;
      if (!cached.isExpired) {
        print('⚡ Full YouTube stream loaded from memory cache for: ${song.title}');
        return cached.url;
      }
    }

    final String? directVideoId = song.youtubeId;

    // 2. Direct Video ID extraction if available
    if (directVideoId != null && directVideoId.isNotEmpty) {
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(directVideoId).timeout(const Duration(seconds: 5));
        if (manifest.audioOnly.isNotEmpty) {
          final audioStreams = manifest.audioOnly.toList();
          final preferredStream = audioStreams.firstWhere(
            (s) => s.container.name.toLowerCase().contains('mp4') || s.container.name.toLowerCase().contains('m4a') || s.audioCodec.toLowerCase().contains('mp4a'),
            orElse: () => manifest.audioOnly.withHighestBitrate(),
          );
          final url = preferredStream.url.toString();
          print('✅ Direct YouTube stream extracted for videoId $directVideoId (${song.title})');
          _streamCache[song.id] = _CachedStream(url, DateTime.now());
          return url;
        }
      } catch (e) {
        print('Direct video ID extraction notice for $directVideoId: $e');
      }
    }

    // 3. YouTube Explode Search Extraction with Compilation Video Filtering
    try {
      final String searchQuery = '${song.title} ${song.artist}'.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '').trim();
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
            if (titleLower.contains('full album') || titleLower.contains('kompilasi') || titleLower.contains('nonstop') || titleLower.contains('2 jam') || titleLower.contains('1 jam')) return false;
            return true;
          }).take(5),
        );

        if (candidates.isEmpty) {
          candidates.addAll(videoList.where((v) => (v.duration?.inSeconds ?? 0) <= 600).take(3));
        }

        candidates.sort((a, b) {
          final aTopic = a.author.toLowerCase().contains('- topic') || a.title.toLowerCase().contains('audio') || a.title.toLowerCase().contains('official');
          final bTopic = b.author.toLowerCase().contains('- topic') || b.title.toLowerCase().contains('audio') || b.title.toLowerCase().contains('official');
          if (aTopic && !bTopic) return -1;
          if (!aTopic && bTopic) return 1;
          return 0;
        });

        for (final selectedVideo in candidates) {
          try {
            final videoId = selectedVideo.id.value;
            final manifest = await _yt.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 4));

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
              print('✅ Full-length YouTube stream extracted for: ${song.title} (${selectedVideo.title})');
              _streamCache[song.id] = _CachedStream(selectedUrl, DateTime.now());
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
      final String searchQuery = '${song.title} ${song.artist}'.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '').trim();
      final invidiousInstances = [
        'https://inv.tux.pizza',
        'https://invidious.nerdvpn.de',
        'https://yewtu.be',
      ];

      for (final instance in invidiousInstances) {
        try {
          final searchRes = await http.get(Uri.parse('$instance/api/v1/search?q=${Uri.encodeComponent(searchQuery)}&type=video')).timeout(const Duration(seconds: 4));
          if (searchRes.statusCode == 200) {
            final List results = json.decode(searchRes.body);
            final filtered = results.where((item) {
              final sec = item['lengthSeconds']?.toInt() ?? 0;
              return sec > 0 && sec <= 600;
            }).toList();

            if (filtered.isNotEmpty) {
              final videoId = filtered.first['videoId'];
              final videoRes = await http.get(Uri.parse('$instance/api/v1/videos/$videoId')).timeout(const Duration(seconds: 4));
              if (videoRes.statusCode == 200) {
                final data = json.decode(videoRes.body);
                final List adaptive = data['adaptiveFormats'] ?? [];
                final audioStreams = adaptive.where((s) => s['type'].toString().contains('audio/')).toList();
                if (audioStreams.isNotEmpty) {
                  final fullUrl = audioStreams.first['url'].toString();
                  print('✅ Invidious Full-Length Stream URL for: ${song.title}');
                  _streamCache[song.id] = _CachedStream(fullUrl, DateTime.now());
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
