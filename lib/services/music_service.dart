import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';
import '../models/artist.dart';

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

  /// Direct YouTube Search Engine (Fast, 100% Real-Time Official YouTube Results)
  Future<List<Song>> _searchDirectYouTube(String cleanQuery, {int limit = 30}) async {
    final List<Song> songList = [];
    final Set<String> seenIds = {};

    try {
      final uri = Uri.parse(
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent(cleanQuery)}',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7',
      }).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final html = res.body;
        if (html.contains('var ytInitialData =')) {
          final start = html.indexOf('var ytInitialData =') + 'var ytInitialData ='.length;
          final end = html.indexOf(';</script>', start);
          if (end != -1) {
            final jsonStr = html.substring(start, end).trim();
            final data = json.decode(jsonStr);

            final contents = data['contents']?['twoColumnSearchResultsRenderer']?['primaryContents']?['sectionListRenderer']?['contents'] as List? ?? [];

            int index = 0;
            for (final sec in contents) {
              final itemSection = sec['itemSectionRenderer']?['contents'] as List? ?? [];
              for (final item in itemSection) {
                final v = item['videoRenderer'];
                if (v != null) {
                  final vid = v['videoId'] as String?;
                  final rawTitle = v['title']?['runs']?[0]?['text'] as String? ?? '';
                  final rawOwner = v['ownerText']?['runs']?[0]?['text'] as String? ?? '';
                  final lenText = v['lengthText']?['simpleText'] as String? ?? '';
                  final thumbnails = v['thumbnail']?['thumbnails'] as List? ?? [];
                  final thumb = thumbnails.isNotEmpty
                      ? (thumbnails.last['url'] as String? ?? 'https://i.ytimg.com/vi/$vid/hqdefault.jpg')
                      : 'https://i.ytimg.com/vi/$vid/hqdefault.jpg';

                  if (vid == null || vid.isEmpty || rawTitle.isEmpty) continue;

                  final seconds = _parseDuration(lenText);
                  final titleLower = rawTitle.toLowerCase();

                  // Skip long compilations > 20 mins unless requested
                  if (seconds > 1200 || (seconds > 0 && seconds < 20)) continue;
                  if (titleLower.contains('full album') ||
                      titleLower.contains('kompilasi') ||
                      titleLower.contains('nonstop') ||
                      titleLower.contains('2 jam') ||
                      titleLower.contains('1 jam')) {
                    continue;
                  }

                  if (seenIds.add(vid)) {
                    final sep = rawTitle.indexOf(' - ');
                    final artist = sep != -1 ? rawTitle.substring(0, sep).trim() : rawOwner;
                    final titlePart = sep != -1 ? rawTitle.substring(sep + 3).trim() : rawTitle;
                    final formattedTitle = formatSongTitle(titlePart);

                    songList.add(Song(
                      id: 'yt_$vid',
                      youtubeId: vid,
                      title: formattedTitle.isNotEmpty ? formattedTitle : rawTitle,
                      artist: artist.isNotEmpty ? artist : rawOwner,
                      album: 'YouTube Music',
                      artworkUrl: thumb,
                      durationSeconds: seconds,
                      isLive: lenText.toLowerCase().contains('live'),
                    ));

                    if (songList.length >= limit) return songList;
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Direct YouTube search notice: $e');
    }

    return songList;
  }

  static int _parseDuration(String lenText) {
    if (lenText.isEmpty) return 0;
    final parts = lenText.replaceAll('.', ':').split(':');
    try {
      if (parts.length == 2) {
        return (int.parse(parts[0]) * 60) + int.parse(parts[1]);
      } else if (parts.length == 3) {
        return (int.parse(parts[0]) * 3600) + (int.parse(parts[1]) * 60) + int.parse(parts[2]);
      }
    } catch (_) {}
    return 0;
  }

  /// Official YouTube InnerTube Search Engine (Pure JSON, 0 Blocks, 100% Complete & Fast)
  Future<List<Song>> _searchInnerTube(String cleanQuery, {int limit = 40}) async {
    final List<Song> songList = [];
    final Set<String> seenIds = {};

    try {
      final uri = Uri.parse('https://www.youtube.com/youtubei/v1/search?prettyPrint=false');
      final payload = json.encode({
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': '2.20240401.01.00',
            'hl': 'id',
            'gl': 'ID',
          }
        },
        'query': cleanQuery,
      });

      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        },
        body: payload,
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        void extractVideos(dynamic obj) {
          if (songList.length >= limit) return;
          if (obj is Map) {
            Map? v;
            if (obj.containsKey('videoRenderer')) {
              v = obj['videoRenderer'] as Map?;
            } else if (obj.containsKey('compactVideoRenderer')) {
              v = obj['compactVideoRenderer'] as Map?;
            }

            if (v != null) {
              final vid = v['videoId'] as String?;
              String rawTitle = '';
              if (v['title'] is Map) {
                final runs = v['title']['runs'] as List?;
                if (runs != null && runs.isNotEmpty) {
                  rawTitle = runs[0]['text'] as String? ?? '';
                } else if (v['title']['simpleText'] != null) {
                  rawTitle = v['title']['simpleText'] as String? ?? '';
                }
              }

              String rawOwner = '';
              if (v['ownerText'] is Map) {
                final runs = v['ownerText']['runs'] as List?;
                if (runs != null && runs.isNotEmpty) {
                  rawOwner = runs[0]['text'] as String? ?? '';
                }
              } else if (v['shortBylineText'] is Map) {
                final runs = v['shortBylineText']['runs'] as List?;
                if (runs != null && runs.isNotEmpty) {
                  rawOwner = runs[0]['text'] as String? ?? '';
                }
              }

              final lenText = v['lengthText']?['simpleText'] as String? ?? '';
              final thumbnails = v['thumbnail']?['thumbnails'] as List? ?? [];
              final thumb = thumbnails.isNotEmpty
                  ? (thumbnails.last['url'] as String? ?? 'https://i.ytimg.com/vi/$vid/hqdefault.jpg')
                  : 'https://i.ytimg.com/vi/$vid/hqdefault.jpg';

              if (vid != null && vid.isNotEmpty && rawTitle.isNotEmpty && seenIds.add(vid)) {
                final seconds = _parseDuration(lenText);
                final titleLower = rawTitle.toLowerCase();

                // Skip full album compilations > 30 minutes
                if (seconds <= 2400 &&
                    !titleLower.contains('full album') &&
                    !titleLower.contains('2 jam') &&
                    !titleLower.contains('3 jam')) {
                  final sep = rawTitle.indexOf(' - ');
                  final artist = sep != -1 ? rawTitle.substring(0, sep).trim() : rawOwner;
                  final titlePart = sep != -1 ? rawTitle.substring(sep + 3).trim() : rawTitle;
                  final formattedTitle = formatSongTitle(titlePart);

                  songList.add(Song(
                    id: 'yt_$vid',
                    youtubeId: vid,
                    title: formattedTitle.isNotEmpty ? formattedTitle : rawTitle,
                    artist: artist.isNotEmpty ? artist : (rawOwner.isNotEmpty ? rawOwner : 'Various Artists'),
                    album: 'YouTube Music',
                    artworkUrl: thumb,
                    durationSeconds: seconds,
                    isLive: lenText.toLowerCase().contains('live'),
                  ));
                }
              }
            } else {
              for (final val in obj.values) {
                extractVideos(val);
              }
            }
          } else if (obj is List) {
            for (final item in obj) {
              extractVideos(item);
            }
          }
        }

        extractVideos(data);
      }
    } catch (e) {
      print('InnerTube search notice: $e');
    }

    return songList;
  }

  /// Search songs using InnerTube YouTube search engine with Direct HTML and Explode fallbacks
  Future<List<Song>> searchSongs(String query, {int limit = 40}) async {
    final cleanQuery = query.replaceAll('*', '').trim();
    if (cleanQuery.isEmpty) return [];

    // Direct YouTube Video/Playlist URL support (Only run if query is an actual URL)
    if (cleanQuery.startsWith('http://') ||
        cleanQuery.startsWith('https://') ||
        cleanQuery.contains('youtube.com/') ||
        cleanQuery.contains('youtu.be/')) {
      try {
        final videoId = VideoId.parseVideoId(cleanQuery);
        if (videoId != null) {
          final video = await _yt.videos.get(videoId);
          return [returnSongFromVideo(video, 0)];
        }
      } catch (_) {}

      try {
        final playlistId = PlaylistId.parsePlaylistId(cleanQuery);
        if (playlistId != null) {
          return await getSongsFromPlaylist(playlistId, limit: limit);
        }
      } catch (_) {}
    }

    // 1. YouTube Official InnerTube API Engine (Fastest & 100% Reliable JSON)
    final innerTubeResults = await _searchInnerTube(cleanQuery, limit: limit);
    if (innerTubeResults.isNotEmpty) {
      return innerTubeResults;
    }

    // 2. Direct High-Speed YouTube Search Engine
    final directResults = await _searchDirectYouTube(cleanQuery, limit: limit);
    if (directResults.isNotEmpty) {
      return directResults;
    }

    // 3. Fallback to youtube_explode_dart
    final List<Song> songList = [];
    final Set<String> seenIds = {};

    try {
      final searchResults = await _yt.search.search(cleanQuery).timeout(const Duration(seconds: 6));
      int index = 0;
      for (final item in searchResults) {
        final seconds = item.duration?.inSeconds ?? 0;
        final titleLower = item.title.toLowerCase();

        // Skip compilation/1-hour loops
        if (seconds > 1200 || (seconds > 0 && seconds < 20)) continue;
        if (titleLower.contains('full album') ||
            titleLower.contains('kompilasi') ||
            titleLower.contains('nonstop') ||
            titleLower.contains('2 jam') ||
            titleLower.contains('1 jam')) {
          continue;
        }

        if (seenIds.add(item.id.value)) {
          final sep = item.title.indexOf(' - ');
          final artist = sep != -1 ? item.title.substring(0, sep).trim() : item.author;
          final rawTitle = sep != -1 ? item.title.substring(sep + 3).trim() : item.title;
          final title = formatSongTitle(rawTitle);

          songList.add(Song(
            id: 'yt_${item.id.value}',
            youtubeId: item.id.value,
            title: title.isEmpty ? rawTitle : title,
            artist: artist.isEmpty ? item.author : artist,
            album: 'YouTube Music',
            artworkUrl: item.thumbnails.highResUrl,
            durationSeconds: seconds,
            isLive: false,
          ));
          if (songList.length >= limit) break;
        }
      }
    } catch (e) {
      print('Explode search fallback notice: $e');
    }

    return songList;
  }

  /// Musify-Style Official YouTube Music Canonical Artist Search
  Future<List<Artist>> searchArtists(String query) async {
    final cleanQuery = query.replaceAll('*', '').trim();
    if (cleanQuery.isEmpty) return [];

    final List<Artist> artists = [];
    final Set<String> seenIds = {};

    try {
      final uri = Uri.parse('https://music.youtube.com/youtubei/v1/search?prettyPrint=false');
      final payload = json.encode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240401.01.00',
            'hl': 'id',
            'gl': 'ID',
          }
        },
        'query': cleanQuery,
        'params': 'EgWKAQIgAWoMEA4QChADEAQQCRAF', // Musify canonical artist filter
      });

      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        },
        body: payload,
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        void extractArtists(dynamic obj) {
          if (artists.length >= 6) return;
          if (obj is Map) {
            if (obj.containsKey('musicResponsiveListItemRenderer')) {
              final r = obj['musicResponsiveListItemRenderer'] as Map;
              final nav = r['navigationEndpoint']?['browseEndpoint'];
              final browseId = nav?['browseId'] as String?;
              if (browseId != null && browseId.isNotEmpty && seenIds.add(browseId)) {
                final flexCols = r['flexColumns'] as List? ?? [];
                String name = '';
                String subtitle = 'Artis Resmi';

                if (flexCols.isNotEmpty) {
                  final runs = flexCols[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List?;
                  if (runs != null && runs.isNotEmpty) {
                    name = runs[0]['text'] as String? ?? '';
                  }
                }
                if (flexCols.length > 1) {
                  final runs = flexCols[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List?;
                  if (runs != null && runs.isNotEmpty) {
                    subtitle = runs.map((e) => e['text'] ?? '').join('');
                  }
                }

                final thumbList = r['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List? ?? [];
                String? thumbUrl;
                if (thumbList.isNotEmpty) {
                  thumbUrl = thumbList.last['url'] as String?;
                }

                if (name.isNotEmpty) {
                  artists.add(Artist(
                    id: browseId,
                    name: name,
                    avatarUrl: thumbUrl,
                    subtitle: subtitle.isNotEmpty ? subtitle : 'Artis Resmi',
                    isVerified: true,
                  ));
                }
              }
            } else {
              for (final val in obj.values) {
                extractArtists(val);
              }
            }
          } else if (obj is List) {
            for (final item in obj) {
              extractArtists(item);
            }
          }
        }

        extractArtists(data);
      }
    } catch (e) {
      print('YouTube Music searchArtists notice: $e');
    }

    return artists;
  }

  /// Fetches canonical top popular songs for a resolved artist browseId (Musify standard)
  Future<List<Song>> getArtistTopSongs(String browseId, String artistName, {int limit = 30}) async {
    final List<Song> songs = [];
    final Set<String> seenIds = {};

    if (browseId.isNotEmpty) {
      try {
        final uri = Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false');
        final payload = json.encode({
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': '1.20240401.01.00',
              'hl': 'id',
              'gl': 'ID',
            }
          },
          'browseId': browseId,
        });

        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          },
          body: payload,
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = json.decode(res.body);

          void extractSongs(dynamic obj) {
            if (songs.length >= limit) return;
            if (obj is Map) {
              if (obj.containsKey('musicResponsiveListItemRenderer')) {
                final r = obj['musicResponsiveListItemRenderer'] as Map;
                final vid = r['playlistItemData']?['videoId'] as String?;
                if (vid != null && vid.isNotEmpty && seenIds.add(vid)) {
                  final flexCols = r['flexColumns'] as List? ?? [];
                  String title = '';
                  String songArtist = artistName;

                  if (flexCols.isNotEmpty) {
                    final runs = flexCols[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List?;
                    if (runs != null && runs.isNotEmpty) {
                      title = runs[0]['text'] as String? ?? '';
                    }
                  }
                  if (flexCols.length > 1) {
                    final runs = flexCols[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List?;
                    if (runs != null && runs.isNotEmpty) {
                      songArtist = runs[0]['text'] as String? ?? artistName;
                    }
                  }

                  final thumbList = r['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List? ?? [];
                  final thumb = thumbList.isNotEmpty
                      ? (thumbList.last['url'] as String? ?? 'https://i.ytimg.com/vi/$vid/hqdefault.jpg')
                      : 'https://i.ytimg.com/vi/$vid/hqdefault.jpg';

                  if (title.isNotEmpty) {
                    songs.add(Song(
                      id: 'yt_$vid',
                      youtubeId: vid,
                      title: formatSongTitle(title),
                      artist: songArtist.isNotEmpty ? songArtist : artistName,
                      album: 'YouTube Music',
                      artworkUrl: thumb,
                      durationSeconds: 0,
                    ));
                  }
                }
              } else {
                for (final val in obj.values) {
                  extractSongs(val);
                }
              }
            } else if (obj is List) {
              for (final item in obj) {
                extractSongs(item);
              }
            }
          }

          extractSongs(data);

          // If there's a full playlist endpoint for "Lagu teratas" / "Top songs" (e.g. VLOLAK...), query it
          String? topSongsPlaylistId;
          void findTopSongsPlaylist(dynamic obj) {
            if (topSongsPlaylistId != null) return;
            if (obj is Map) {
              if (obj.containsKey('musicShelfRenderer')) {
                final shelf = obj['musicShelfRenderer'] as Map;
                final bp = shelf['bottomEndpoint']?['browseEndpoint']?['browseId'] as String?;
                if (bp != null && bp.isNotEmpty) {
                  topSongsPlaylistId = bp;
                  return;
                }
              }
              for (final val in obj.values) {
                findTopSongsPlaylist(val);
              }
            } else if (obj is List) {
              for (final item in obj) {
                findTopSongsPlaylist(item);
              }
            }
          }

          findTopSongsPlaylist(data);

          if (topSongsPlaylistId != null && songs.length < limit) {
            try {
              final plPayload = json.encode({
                'context': {
                  'client': {
                    'clientName': 'WEB_REMIX',
                    'clientVersion': '1.20240401.01.00',
                    'hl': 'id',
                    'gl': 'ID',
                  }
                },
                'browseId': topSongsPlaylistId,
              });

              final plRes = await http.post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                },
                body: plPayload,
              ).timeout(const Duration(seconds: 4));

              if (plRes.statusCode == 200) {
                extractSongs(json.decode(plRes.body));
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        print('getArtistTopSongs browse notice: $e');
      }
    }

    // Fallback: search "$artistName songs" if browse returned fewer than 10 tracks
    if (songs.length < 10) {
      try {
        final fallback = await searchSongs('$artistName official songs', limit: limit);
        for (final s in fallback) {
          final sid = s.youtubeId ?? s.id;
          if (seenIds.add(sid)) {
            songs.add(s);
          }
        }
      } catch (_) {}
    }

    return songs;
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

  /// Fetch real-time YouTube search suggestions (as user types)
  Future<List<String>> getSearchSuggestions(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];
    try {
      final uri = Uri.parse(
        'https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=${Uri.encodeComponent(clean)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List && data.length > 1 && data[1] is List) {
          return List<String>.from(data[1].take(6));
        }
      }
    } catch (_) {}
    return [];
  }

  /// Parallel fetch exactly 1 distinct top song per seed query to guarantee 10 distinct hit tracks
  Future<List<Song>> _fetchTopDistinctSongs(List<String> seeds, {int limit = 10}) async {
    try {
      final results = await Future.wait(
        seeds.take(limit).map((seed) async {
          final list = await searchSongs(seed, limit: 1);
          return list.isNotEmpty ? list.first : null;
        }),
      );

      final List<Song> distinctSongs = [];
      final Set<String> seenIds = {};

      for (final song in results) {
        if (song != null && seenIds.add(song.id)) {
          distinctSongs.add(song);
        }
      }
      return distinctSongs;
    } catch (e) {
      print('Distinct fetch notice: $e');
      return [];
    }
  }

  /// Dynamic Daily Rotating & Refreshable Top Charts (Fresh Daily Rotation + Real-Time Live YouTube Charts on Refresh)
  Future<List<Song>> getTrendingSongs({String category = 'Trending', bool refresh = false}) async {
    List<Song> songs = [];

    // 1. Dynamic live queries based on category & daily rotation salt
    final now = DateTime.now();
    final int daySeed = now.year * 1000 + now.month * 32 + now.day;
    final int rotationIndex = refresh ? (now.millisecond + now.second) % 8 : (now.day + now.weekday) % 8;

    final Map<String, List<String>> liveQueryVariations = {
      'Trending': [
        'Lagu Trending Indonesia 2026 Hits Terbaru',
        'Top Hits Indonesia 2026 Viral Terpopuler',
        'Lagu Viral Terbaru 2026 Bernadya Sal Priadi Mahalini',
        'Populer Hari Ini Indonesia 2026 YouTube Music',
        'Tangga Lagu Indonesia 2026 Terpopuler Resmi',
        'Lagu Hits Indonesia 2026 Pop Akustik',
        'Top 50 Indonesia 2026 Lagu Viral Terkini',
        'Hits Indonesia Terbaru 2026 Pilihan Pendengar',
      ],
      'Indonesia': [
        'Top Lagu Pop Indonesia 2026 Terbaru',
        'Lagu Galau Indonesia 2026 Hits Akustik',
        'Lagu Populer Indonesia Denny Caknan Hindia Bernadya',
        'Lagu Indie Pop Indonesia 2026 Viral Terkini',
        'Lagu Enak Didengar 2026 Indonesia Hits',
        'Lagu Koplo Pop Jawa 2026 Denny Caknan Happy Asmara',
        'Lagu Santai Indonesia 2026 Viral Akustik',
        'Pop Romantis Indonesia 2026 Hits Terbaru',
      ],
      'Global': [
        'Top Global Hits 2026 Billboard Pop Viral',
        'Today Top Hits 2026 Bruno Mars Billie Eilish',
        'Global Viral Hits 2026 Sabrina Carpenter Lady Gaga',
        'Billboard Hot 100 2026 Official Music',
        'Pop Global Hits 2026 The Weeknd Dua Lipa',
        'Top English Hits 2026 Trending Music',
        'Viral Worldwide Songs 2026 New Release',
        'International Top Charts 2026 Official Video',
      ],
      'Viral TikTok': [
        'Lagu Viral TikTok 2026 FYP Paling Candu Hits',
        'Sound Viral TikTok 2026 Terbaru Indonesia',
        'Lagu FYP TikTok 2026 Populer Enak Didengar',
        'Remix Viral TikTok 2026 Hits Indonesia',
        'Sound TikTok Indonesia 2026 Candu Banget',
        'TikTok Trending Music 2026 FYP Terbaru',
        'Lagu TikTok Santai 2026 Galau Trending',
        'Kompilasi Sound TikTok Viral 2026 Terbaru',
      ],
    };

    final queries = liveQueryVariations[category] ?? liveQueryVariations['Trending']!;
    final selectedQuery = queries[rotationIndex % queries.length];

    // Try live fast InnerTube search first (Instant single-pass query)
    try {
      final liveSongs = await _searchInnerTube(selectedQuery, limit: 16);
      if (liveSongs.length >= 6) {
        if (refresh) {
          liveSongs.shuffle();
        }
        return liveSongs.take(12).toList();
      }
    } catch (e) {
      print('Live trending query notice for $selectedQuery: $e');
    }

    // Curated rich catalog (Rotates systematically by day of year and random salt on refresh)
    final List<String> curatedTrendingPool = [
      'Bernadya Satu Bulan Official Music Video',
      'Rose Bruno Mars APT Official Music Video',
      'Sal Priadi Gala Bunga Matahari Official Music Video',
      'Lady Gaga Bruno Mars Die With A Smile Official Music Video',
      'Mahalini Mati Matian Official Music Video',
      'Billie Eilish Birds of a Feather Official Video',
      'Juicy Luicy Lampu Kuning Official Music Video',
      'Sabrina Carpenter Espresso Official Music Video',
      'Nadhif Basalamah Penjaga Hati Official Music Video',
      'Tiara Andini Kupu Kupu Official Music Video',
      'Denny Caknan Sigar Official Music Video',
      'Hindia Kita Ke Sana Official Video',
      'Yura Yunita Risalah Hati Official Video',
      'Anggi Marito Kisah Yang Salah Official Video',
      'Sheila On 7 Sahabat Sejati Official Audio',
      'NIKI High School in Jakarta Official Music Video',
      'Tulus Hati Hati di Jalan Official Music Video',
      'Dewa 19 Kangen Official Audio',
      'Raim Laode Lesung Pipi Official Video',
      'Juicy Luicy Adrian Khalif Sialan Official Video',
      'Ghea Indrawari Jiwa Yang Bersedih Official Music Video',
      'Salma Salsabil Boleh Juga Official Music Video',
      'Feby Putri Fiersa Besari Runtuh Official Video',
      'Nadin Amizah Semua Aku Dirayakan Official Video',
      'Chappell Roan Good Luck Babe Official Video',
      'Benson Boone Beautiful Things Official Video',
      'Taylor Swift Fortnight Official Music Video',
      'The Weeknd Playboi Carti Timeless Official Video',
      'Dua Lipa Houdini Official Music Video',
      'Post Malone Morgan Wallen I Had Some Help Official Video',
    ];

    final randomGen = Random(refresh ? DateTime.now().microsecondsSinceEpoch : daySeed);
    final rotatedPool = List<String>.from(curatedTrendingPool)..shuffle(randomGen);
    songs = await _fetchTopDistinctSongs(rotatedPool.take(10).toList(), limit: 10);

    if (songs.isEmpty) {
      songs = await searchSongs('Top Hits Indonesia 2026 Bernadya Sal Priadi Bruno Mars Sabrina Carpenter', limit: 10);
    }

    return songs;
  }

  /// Fetch lyrics from LRCLIB API with multi-tier cascade fallback and duration matching
  Future<String?> getSongLyrics(String title, String artist, {int? durationSeconds}) async {
    final cleanTitle = formatSongTitle(title);
    final cleanArtist = artist.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '').trim();

    // 1. Exact LRCLIB match with duration filter
    try {
      String url = 'https://lrclib.net/api/get?artist_name=${Uri.encodeComponent(cleanArtist)}&track_name=${Uri.encodeComponent(cleanTitle)}';
      if (durationSeconds != null && durationSeconds > 0) {
        url += '&duration=$durationSeconds';
      }
      final uri = Uri.parse(url);
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final synced = data['syncedLyrics'];
        if (synced != null && synced.toString().isNotEmpty) return synced;
        final plain = data['plainLyrics'];
        if (plain != null && plain.toString().isNotEmpty) return plain;
      }
    } catch (_) {}

    // 2. Exact LRCLIB match without duration (in case duration varies slightly)
    try {
      final uri = Uri.parse(
        'https://lrclib.net/api/get?artist_name=${Uri.encodeComponent(cleanArtist)}&track_name=${Uri.encodeComponent(cleanTitle)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final synced = data['syncedLyrics'];
        if (synced != null && synced.toString().isNotEmpty) return synced;
        final plain = data['plainLyrics'];
        if (plain != null && plain.toString().isNotEmpty) return plain;
      }
    } catch (_) {}

    // 3. LRCLIB query search sorted by closest duration match
    try {
      final queryUri = Uri.parse(
        'https://lrclib.net/api/search?q=${Uri.encodeComponent('$cleanTitle $cleanArtist')}',
      );
      final res = await http.get(queryUri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List && data.isNotEmpty) {
          // Sort items by closeness to audio duration if available
          if (durationSeconds != null && durationSeconds > 0) {
            data.sort((a, b) {
              final durA = (a['duration'] as num?)?.toDouble() ?? 0.0;
              final durB = (b['duration'] as num?)?.toDouble() ?? 0.0;
              final diffA = (durA - durationSeconds).abs();
              final diffB = (durB - durationSeconds).abs();
              return diffA.compareTo(diffB);
            });
          }

          for (final item in data) {
            final synced = item['syncedLyrics'];
            if (synced != null && synced.toString().isNotEmpty) return synced;
          }
          final plain = data[0]['plainLyrics'];
          if (plain != null && plain.toString().isNotEmpty) return plain;
        }
      }
    } catch (_) {}

    // 4. LRCLIB title only search
    try {
      final titleUri = Uri.parse(
        'https://lrclib.net/api/search?track_name=${Uri.encodeComponent(cleanTitle)}',
      );
      final res = await http.get(titleUri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List && data.isNotEmpty) {
          for (final item in data) {
            final synced = item['syncedLyrics'];
            if (synced != null && synced.toString().isNotEmpty) return synced;
          }
          final plain = data[0]['plainLyrics'];
          if (plain != null && plain.toString().isNotEmpty) return plain;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Fetch Artist Radio / Trending tracks for endless continuous playback ("ga putus-putus")
  Future<List<Song>> getArtistRadioSongs(String artist, {String? currentSongTitle, int limit = 15}) async {
    final cleanArtist = artist
        .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '')
        .replaceAll('Various Artists', '')
        .replaceAll('- Topic', '')
        .replaceAll('Topic', '')
        .trim();

    if (cleanArtist.isEmpty) return [];

    final List<Song> radioSongs = [];
    final Set<String> seenIds = {};

    // 1. Search artist top popular hits and trending releases
    final searchQueries = [
      '$cleanArtist top songs hits trending',
      '$cleanArtist lagu populer terbaru',
    ];

    for (final q in searchQueries) {
      try {
        final results = await searchSongs(q, limit: limit);
        for (final s in results) {
          final sTitle = s.title.toLowerCase();
          final sArtist = s.artist.toLowerCase();
          final artistLower = cleanArtist.toLowerCase();

          // Don't add identical song if currentSongTitle is provided
          if (currentSongTitle != null && sTitle == currentSongTitle.toLowerCase()) continue;

          // Ensure it matches the artist
          final isArtistMatch = sArtist.contains(artistLower) || sTitle.contains(artistLower);
          if (isArtistMatch && seenIds.add(s.id)) {
            radioSongs.add(s);
          }
        }
      } catch (_) {}
      if (radioSongs.length >= limit) break;
    }

    // 2. Fallback: if not enough tracks found, do broader search
    if (radioSongs.length < 5) {
      try {
        final fallback = await searchSongs('$cleanArtist songs', limit: limit);
        for (final s in fallback) {
          if (seenIds.add(s.id)) {
            radioSongs.add(s);
          }
        }
      } catch (_) {}
    }

    // Shuffle the results so next songs feel dynamic, fresh, and randomized!
    radioSongs.shuffle();
    return radioSongs;
  }
}
