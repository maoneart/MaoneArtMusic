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

    // Determine target videoId or search query
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

    // 3. YouTube Explode Search Extraction
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
        final candidates = List<Video>.from(
          videoList.where((v) => v.duration == null || v.duration!.inSeconds > 60).take(5),
        );
        if (candidates.isEmpty) candidates.addAll(videoList.take(3));

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
      print('YouTube full stream search notice for ${song.title}: $e');
    }

    // 4. Invidious REST API fallback for Full-Length Audio Stream
    try {
      final targetId = directVideoId ?? song.id.replaceAll('yt_', '').replaceAll('yt_search_', '').replaceAll('yt_inv_', '');
      final invidiousInstances = [
        'https://inv.tux.pizza',
        'https://invidious.nerdvpn.de',
        'https://yewtu.be',
      ];

      for (final instance in invidiousInstances) {
        try {
          final videoRes = await http.get(Uri.parse('$instance/api/v1/videos/$targetId')).timeout(const Duration(seconds: 3));
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
        } catch (_) {}
      }
    } catch (_) {}

    return null;
  }
}
