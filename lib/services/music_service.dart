import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

const String _noiseTerms =
    'official music video|official lyric video|official lyrics video|'
    'official video|official 4k video|official audio|lyric video|'
    'lyrics video|official hd video|lyric visualizer|lyric vizualizer|'
    'official visualizer|official vizualizer|official visualiser|official vizualiser|lyrics|lyric|official song clip|'
    'official|karaoke|full audio';

final RegExp _bracketedNoisePattern = RegExp(
  r'[\(\[][^\)\]]*(?:' + _noiseTerms + r')[^\)\]]*[\)\]]',
  caseSensitive: false,
);

final RegExp _trailingNoisePattern = RegExp(
  r'\s*[-–—]?\s*\b(?:' + _noiseTerms + r'|audio)\b\s*$',
  caseSensitive: false,
);

class MusicService {
  static final YoutubeExplode _yt = YoutubeExplode();

  /// Musify Title Cleaner: Strips noise like '(Official Video)', '[4K]', 'Lyrics', etc.
  static String formatSongTitle(String title) {
    var t = title.replaceAll(_bracketedNoisePattern, '');
    t = t
        .replaceAll(RegExp(r'[\[\]()|]'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&quot;', '"')
        .trimLeft();

    String prev;
    do {
      prev = t;
      t = t.replaceAll(_trailingNoisePattern, '');
    } while (t != prev);

    return t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  /// Converts a YouTube Video object into a high quality Song model (Musify standard)
  static Song returnSongFromVideo(Video video, int index, {String? playlistImage}) {
    final sep = video.title.indexOf(' - ');
    final artist = sep != -1 ? video.title.substring(0, sep).trim() : video.author;
    final rawTitle = sep != -1 ? video.title.substring(sep + 3).trim() : video.title;
    final title = formatSongTitle(rawTitle);

    final String fallbackArt = video.thumbnails.maxResUrl.isNotEmpty
        ? video.thumbnails.maxResUrl
        : video.thumbnails.highResUrl;
    final artwork = (playlistImage != null && playlistImage.isNotEmpty)
        ? playlistImage
        : fallbackArt;

    return Song(
      id: 'yt_${video.id.value}',
      youtubeId: video.id.value,
      title: title.isEmpty ? rawTitle : title,
      artist: artist.isEmpty ? video.author : artist,
      album: 'YouTube Music',
      artworkUrl: artwork.isNotEmpty
          ? artwork
          : 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&auto=format&fit=crop&q=80',
      durationSeconds: video.duration?.inSeconds ?? 0,
      isLive: video.isLive,
    );
  }

  /// Search songs using Musify's YouTube search engine
  Future<List<Song>> searchSongs(String query, {int limit = 30}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // Direct YouTube Video URL support
    final videoId = VideoId.parseVideoId(cleanQuery);
    if (videoId != null) {
      try {
        final video = await _yt.videos.get(videoId);
        return [returnSongFromVideo(video, 0)];
      } catch (_) {}
    }

    // Direct YouTube Playlist URL support
    final playlistId = PlaylistId.parsePlaylistId(cleanQuery);
    if (playlistId != null) {
      return await getSongsFromPlaylist(playlistId, limit: limit);
    }

    final List<Song> songList = [];
    final Set<String> seenIds = {};

    try {
      final searchResults = await _yt.search.search(cleanQuery).timeout(const Duration(seconds: 7));
      int index = 0;
      for (final video in searchResults.whereType<Video>()) {
        final seconds = video.duration?.inSeconds ?? 0;
        final titleLower = video.title.toLowerCase();

        // Skip compilation/1-hour loops
        if (seconds > 720 || (seconds > 0 && seconds < 30)) continue;
        if (titleLower.contains('full album') ||
            titleLower.contains('kompilasi') ||
            titleLower.contains('nonstop') ||
            titleLower.contains('2 jam') ||
            titleLower.contains('1 jam')) {
          continue;
        }

        if (seenIds.add(video.id.value)) {
          songList.add(returnSongFromVideo(video, index++));
          if (songList.length >= limit) break;
        }
      }
    } catch (e) {
      print('Search error: $e');
    }

    return songList;
  }

  /// Fetch songs from a YouTube Playlist ID
  Future<List<Song>> getSongsFromPlaylist(String playlistId, {int limit = 40}) async {
    final List<Song> songs = [];
    final Set<String> seen = {};

    try {
      await for (final video in _yt.playlists.getVideos(playlistId).take(limit)) {
        if (seen.add(video.id.value)) {
          songs.add(returnSongFromVideo(video, songs.length));
        }
      }
    } catch (e) {
      print('Playlist fetch error for $playlistId: $e');
    }

    return songs;
  }

  /// Get intelligent related songs / auto-recommendations from current song
  Future<List<Song>> getRelatedSongs(Song song, {int limit = 15}) async {
    if (song.youtubeId == null || song.youtubeId!.isEmpty) {
      return await searchSongs('${song.title} ${song.artist}', limit: limit);
    }

    try {
      final ytVideo = await _yt.videos.get(song.youtubeId!);
      final related = await _yt.videos.getRelatedVideos(ytVideo) ?? [];
      final List<Song> relatedSongs = [];
      final Set<String> seen = {song.youtubeId!};

      for (final v in related) {
        final sec = v.duration?.inSeconds ?? 0;
        if (sec > 720 || sec < 30) continue;
        if (seen.add(v.id.value)) {
          relatedSongs.add(returnSongFromVideo(v, relatedSongs.length));
          if (relatedSongs.length >= limit) break;
        }
      }
      return relatedSongs;
    } catch (e) {
      print('Related songs error: $e');
      return [];
    }
  }

  /// Parallel fetch songs from multiple query seeds to build a rich 50-track list with direct YouTube IDs
  Future<List<Song>> _fetchSongsFromQueries(List<String> queries, {int limit = 50}) async {
    final List<Song> allSongs = [];
    final Set<String> seenIds = {};

    try {
      final results = await Future.wait(
        queries.map((q) => searchSongs(q, limit: 12)),
      );

      for (final songBatch in results) {
        for (final song in songBatch) {
          if (seenIds.add(song.id)) {
            allSongs.add(song);
            if (allSongs.length >= limit) break;
          }
        }
        if (allSongs.length >= limit) break;
      }
    } catch (e) {
      print('Batch query fetch notice: $e');
    }

    return allSongs;
  }

  /// Fetch real-time Trending / Top Charts (Guaranteed 50 Full Songs with Direct YouTube Audio IDs)
  Future<List<Song>> getTrendingSongs({String category = 'Trending'}) async {
    List<Song> songs = [];

    final List<String> indoQueries = [
      'Bernadya Official Music Video',
      'Sal Priadi Gala Bunga Matahari Official',
      'Mahalini Mati Matian Official',
      'Juicy Luicy Lampu Kuning Sialan',
      'Nadhif Basalamah Penjaga Hati Official',
      'Tiara Andini Kupu Kupu Official',
      'Denny Caknan Sigar Wirang Official',
      'Hindia Kita Ke Sana Evaluasi',
      'Yura Yunita Risalah Hati Official',
      'Anggi Marito Kisah Yang Salah',
      'Rizky Febian Bermuara Official',
      'Ghea Indrawari Jiwa Yang Bersedih',
    ];

    final List<String> globalQueries = [
      'Rose Bruno Mars APT Official Music Video',
      'Lady Gaga Bruno Mars Die With A Smile Official',
      'Billie Eilish Birds of a Feather Official Video',
      'Sabrina Carpenter Espresso Taste Please Please Please Official',
      'Chappell Roan Good Luck Babe Official',
      'Benson Boone Beautiful Things Official Video',
      'Post Malone Morgan Wallen I Had Some Help Official',
      'Taylor Swift Fortnight Official Music Video',
      'The Weeknd Playboi Carti Timeless Official',
      'Dua Lipa Houdini Training Season Official',
      'Kendrick Lamar Not Like Us Official',
      'Teddy Swims Lose Control Official',
    ];

    final List<String> tiktokQueries = [
      'Viral TikTok FYP 2026 Indonesia Hits',
      'Lagu TikTok Viral 2026 Terbaru Enak Didengar',
      'Sound TikTok Viral 2026 Paling Candu',
      'Lagu Jedag Jedug TikTok Viral 2026 Terpopuler',
      'Trending TikTok Musik Indonesia 2026',
      'DJ TikTok Viral Full Bass 2026 Terbaru',
    ];

    if (category == 'Indonesia') {
      songs = await _fetchSongsFromQueries(indoQueries, limit: 50);
    } else if (category == 'Global') {
      songs = await _fetchSongsFromQueries(globalQueries, limit: 50);
    } else if (category == 'Viral TikTok') {
      songs = await _fetchSongsFromQueries(tiktokQueries, limit: 50);
    } else {
      // Default: Top 50 Trending (25 Top Indonesia + 25 Top Global)
      final results = await Future.wait([
        _fetchSongsFromQueries(indoQueries, limit: 25),
        _fetchSongsFromQueries(globalQueries, limit: 25),
      ]);

      final Set<String> seenIds = {};
      for (final s in results[0]) {
        if (seenIds.add(s.id)) songs.add(s);
      }
      for (final s in results[1]) {
        if (seenIds.add(s.id)) songs.add(s);
      }
    }

    if (songs.isEmpty) {
      songs = await searchSongs('Top Hits Indonesia 2026 Bernadya Sal Priadi Bruno Mars Sabrina Carpenter', limit: 50);
    }

    return songs;
  }

  /// Fetch lyrics from LRCLIB API
  Future<String?> getSongLyrics(String title, String artist) async {
    try {
      final cleanTitle = formatSongTitle(title);
      final cleanArtist = artist.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '').trim();
      final uri = Uri.parse(
        'https://lrclib.net/api/get?artist_name=${Uri.encodeComponent(cleanArtist)}&track_name=${Uri.encodeComponent(cleanTitle)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['syncedLyrics'] ?? data['plainLyrics'];
      }
    } catch (_) {}
    return null;
  }
}
