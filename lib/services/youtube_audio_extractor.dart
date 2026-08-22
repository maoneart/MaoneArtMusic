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

  /// Extract highest quality FULL-LENGTH audio stream URL for a song from YouTube (like YouTube Music)
  static Future<String?> getAudioStreamUrl(Song song) async {
    // 1. Return cached full-length YouTube URL if valid (max 45 mins)
    if (_streamCache.containsKey(song.id)) {
      final cached = _streamCache[song.id]!;
      if (!cached.isExpired) {
        print('⚡ Full YouTube stream loaded from cache for: ${song.title}');
        return cached.url;
      }
    }

    // 2. PRIMARY: Extract FULL-LENGTH audio stream from YouTube using YoutubeExplode
    try {
      final String searchQuery = '${song.title} ${song.artist}'.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '').trim();
      List<Video> videoList = [];
      try {
        final searchResults = await _yt.search.search(searchQuery).timeout(const Duration(seconds: 4));
        videoList = searchResults.whereType<Video>().toList();
      } catch (_) {}

      if (videoList.isEmpty) {
        try {
          final fallbackResults = await _yt.search.search(song.title).timeout(const Duration(seconds: 4));
          videoList.addAll(fallbackResults.whereType<Video>());
        } catch (_) {}
      }

      if (videoList.isNotEmpty) {
        // Prioritize full-length tracks (> 60 seconds)
        final candidates = List<Video>.from(
          videoList.where((v) => v.duration == null || v.duration!.inSeconds > 60).take(5),
        );
        if (candidates.isEmpty) candidates.addAll(videoList.take(3));

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
              print('✅ Full-length YouTube stream extracted for: ${song.title}');
              _streamCache[song.id] = _CachedStream(selectedUrl, DateTime.now());
              return selectedUrl;
            }
          } catch (_) {
            continue;
          }
        }
      }
    } catch (e) {
      print('YouTube full stream extraction notice for ${song.title}: $e');
    }

    // 3. SECONDARY: Invidious REST API fallback for Full-Length Audio Stream
    try {
      final String searchQuery = '${song.title} ${song.artist}'.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '').trim();
      final invidiousInstances = [
        'https://inv.tux.pizza',
        'https://invidious.nerdvpn.de',
        'https://yewtu.be',
      ];

      for (final instance in invidiousInstances) {
        try {
          final searchRes = await http.get(Uri.parse('$instance/api/v1/search?q=${Uri.encodeComponent(searchQuery)}&type=video')).timeout(const Duration(seconds: 3));
          if (searchRes.statusCode == 200) {
            final List results = json.decode(searchRes.body);
            if (results.isNotEmpty) {
              final videoId = results.first['videoId'];
              final videoRes = await http.get(Uri.parse('$instance/api/v1/videos/$videoId')).timeout(const Duration(seconds: 3));
              if (videoRes.statusCode == 200) {
                final data = json.decode(videoRes.body);
                final List adaptive = data['adaptiveFormats'] ?? [];
                final audioStreams = adaptive.where((s) => s['type'].toString().contains('audio/')).toList();
                if (audioStreams.isNotEmpty) {
                  final fullUrl = audioStreams.first['url'].toString();
                  print('✅ Invidious Full-Length Stream URL: ${song.title}');
                  _streamCache[song.id] = _CachedStream(fullUrl, DateTime.now());
                  return fullUrl;
                }
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    // 4. TERTIARY / EMERGENCY FALLBACK: Only if full-length YouTube extraction fails completely, use song.streamUrl
    if (song.streamUrl != null && song.streamUrl!.isNotEmpty) {
      print('⚠️ Emergency Fallback Audio Stream for: ${song.title}');
      return song.streamUrl;
    }

    return null;
  }
}
