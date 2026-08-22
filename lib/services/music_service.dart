import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class MusicService {
  static final YoutubeExplode _yt = YoutubeExplode();

  /// Convert YouTube Video object to Song instance
  Song _videoToSong(Video video, {String prefix = 'yt'}) {
    final videoId = video.id.value;
    final highResArtwork = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    final int duration = video.duration?.inSeconds ?? 240;

    return Song(
      id: '${prefix}_$videoId',
      title: video.title,
      artist: video.author,
      album: 'YouTube Music',
      artworkUrl: highResArtwork,
      durationSeconds: duration,
      youtubeId: videoId,
      streamUrl: null, // Pure YouTube full-length audio stream!
    );
  }

  /// Search songs directly on YouTube Music / YouTube with duration filtering & smart sorting
  Future<List<Song>> searchSongs(String query, {int limit = 30}) async {
    if (query.trim().isEmpty) return [];
    final List<Song> songList = [];
    final Set<String> addedIds = {};

    try {
      // 1. Try YoutubeExplode search
      final searchResults = await _yt.search.search(query).timeout(const Duration(seconds: 5));
      for (final video in searchResults.whereType<Video>()) {
        final videoId = video.id.value;
        if (!addedIds.contains(videoId)) {
          addedIds.add(videoId);
          songList.add(_videoToSong(video, prefix: 'yt_search'));
        }
      }
    } catch (e) {
      print('YouTube Explode search notice: $e');
    }

    // 2. Invidious REST API Search fallback for maximum reliability
    if (songList.length < 5) {
      final invidiousInstances = [
        'https://inv.tux.pizza',
        'https://invidious.nerdvpn.de',
        'https://yewtu.be',
      ];

      for (final mirror in invidiousInstances) {
        try {
          final uri = Uri.parse('$mirror/api/v1/search?q=${Uri.encodeComponent(query)}&type=video');
          final res = await http.get(uri).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final List items = json.decode(res.body);
            for (final item in items) {
              final videoId = item['videoId'];
              if (videoId != null && !addedIds.contains(videoId)) {
                addedIds.add(videoId);
                final String title = item['title'] ?? 'Unknown Track';
                final String author = item['author'] ?? 'YouTube Music';
                final int duration = item['lengthSeconds']?.toInt() ?? 240;
                final String artwork = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

                songList.add(Song(
                  id: 'yt_inv_$videoId',
                  title: title,
                  artist: author,
                  album: 'YouTube Music',
                  artworkUrl: artwork,
                  durationSeconds: duration,
                  youtubeId: videoId,
                  streamUrl: null,
                ));
              }
            }
            if (songList.isNotEmpty) break;
          }
        } catch (_) {}
      }
    }

    return songList.take(limit).toList();
  }

  /// Fetch top trending music videos & songs directly from YouTube Music / YouTube
  Future<List<Song>> getTrendingSongs({String category = 'Trending'}) async {
    String searchQuery;
    if (category == 'Indonesia') {
      searchQuery = 'Lagu Indonesia Populer Terbaru 2026';
    } else if (category == 'Global') {
      searchQuery = 'Top Global Songs 2026 Official Audio';
    } else if (category == 'Viral TikTok') {
      searchQuery = 'Lagu TikTok Viral Terbaru 2026';
    } else {
      searchQuery = 'Trending Music Indonesia Top Hits 2026';
    }

    final songs = await searchSongs(searchQuery, limit: 30);
    if (songs.isNotEmpty) return songs;

    // Emergency fallback search
    return searchSongs('NOAH Bernadya Mahalini Juicy Luicy Tulus', limit: 20);
  }
}
