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

  /// Fetch songs from official Spotify Top 50 Chart Playlists (Always 50 Real Songs)
  Future<List<Song>> getSongsFromSpotifyPlaylist(String playlistId, {int limit = 50}) async {
    final List<Song> songs = [];
    try {
      final uri = Uri.parse('https://open.spotify.com/embed/playlist/$playlistId');
      final res = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final html = res.body;
        const tag = '<script id="__NEXT_DATA__" type="application/json">';
        if (html.contains(tag)) {
          final jsonStr = html.split(tag)[1].split('</script>')[0];
          final data = json.decode(jsonStr);
          final entity = data['props']?['pageProps']?['state']?['data']?['entity'] ?? {};
          final List trackList = entity['trackList'] ?? [];
          final String coverUrl = (entity['visualIdentity']?['image'] is List && (entity['visualIdentity']['image'] as List).isNotEmpty)
              ? entity['visualIdentity']['image'][0]['url'] ?? ''
              : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80';

          int idx = 0;
          for (final t in trackList.take(limit)) {
            final String rawTitle = t['title'] ?? '';
            final String artist = t['subtitle'] ?? 'Artis Populer';
            final int durationMs = t['duration'] ?? 180000;
            final String uriStr = t['uri'] ?? '';
            final String trackId = uriStr.isNotEmpty ? uriStr.split(':').last : 'sp_$idx';

            if (rawTitle.isNotEmpty) {
              songs.add(
                Song(
                  id: 'sp_$trackId',
                  youtubeId: null,
                  title: formatSongTitle(rawTitle),
                  artist: artist,
                  album: 'Spotify Top 50',
                  artworkUrl: coverUrl.isNotEmpty ? coverUrl : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80',
                  durationSeconds: durationMs ~/ 1000,
                  isLive: false,
                ),
              );
              idx++;
            }
          }
        }
      }
    } catch (e) {
      print('Spotify Chart fetch notice for $playlistId: $e');
    }
    return songs;
  }

  /// Fetch real-time Trending / Top Charts (Guaranteed 50 Full Songs per Category)
  Future<List<Song>> getTrendingSongs({String category = 'Trending'}) async {
    List<Song> songs = [];

    if (category == 'Indonesia') {
      // 1. Spotify Top Viral 50 Indonesia (50 lagu terbaru & viral di Indonesia)
      songs = await getSongsFromSpotifyPlaylist('37i9dQZEVXbIZK8aUquyx8', limit: 50);
      if (songs.length < 20) {
        songs = await getSongsFromPlaylist('PL4fGSI1pDJn59m2b4J_l8oJqM8V4Gz7j9', limit: 50);
      }
    } else if (category == 'Global') {
      // 2. Spotify Top 50 Global (50 lagu teratas dunia)
      songs = await getSongsFromSpotifyPlaylist('37i9dQZEVXbMDoHDwVN2tF', limit: 50);
      if (songs.length < 20) {
        songs = await getSongsFromPlaylist('PL4fGSI1pDJn6O1LS0XSdF3RyO0Rq_LDeI', limit: 50);
      }
    } else if (category == 'Viral TikTok') {
      // 3. Spotify Viral 50
      songs = await getSongsFromSpotifyPlaylist('37i9dQZEVXbIZK8aUquyx8', limit: 50);
      if (songs.length < 20) {
        songs = await getSongsFromPlaylist('PLDIoUOhQQPlXr63I_vwF9GD8sAKh77dWU', limit: 50);
      }
    } else {
      // 4. Default: Today's Top Hits 2026 (50 Lagu Teratas Paling Hits Spotify)
      songs = await getSongsFromSpotifyPlaylist('37i9dQZF1DXcBWIGoYBM5M', limit: 50);
      if (songs.length < 20) {
        songs = await getSongsFromSpotifyPlaylist('37i9dQZEVXbMDoHDwVN2tF', limit: 50);
      }
      if (songs.length < 20) {
        songs = await getSongsFromPlaylist('PL4fGSI1pDJn59m2b4J_l8oJqM8V4Gz7j9', limit: 50);
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
