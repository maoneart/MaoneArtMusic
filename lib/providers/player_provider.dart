import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../models/lyric_line.dart';
import '../services/youtube_audio_extractor.dart';
import '../services/audio_handler.dart';
import '../services/storage_service.dart';
import '../services/music_service.dart';
import '../services/audio_cache_service.dart';

enum PlayerLoadingStatus { idle, loading, playing, paused, error }
enum MusicRepeatMode { off, all, one }

class PlayerStateNotifier extends ChangeNotifier {
  final AudioPlayer _localPlayer = AudioPlayer();
  final StorageService _storageService = StorageService();
  final MusicService _musicService = MusicService();

  AudioPlayer get _player => globalAudioHandler?.player ?? _localPlayer;

  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;
  PlayerLoadingStatus _status = PlayerLoadingStatus.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isShuffle = false;
  MusicRepeatMode _repeatMode = MusicRepeatMode.off;
  String _audioQuality = 'high'; // 'high', 'medium', 'low'
  String? _errorMessage;
  String? _currentLyrics;
  List<LyricLine> _parsedLyrics = [];
  String? _plainLyrics;
  bool _isLoadingLyrics = false;
  bool _isPlayingOffline = false;
  int _playRequestId = 0;
  bool _isExtendingQueue = false;
  String? _lastPreloadedSongId;

  Song? get currentSong => _currentSong;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  PlayerLoadingStatus get status => _status;
  bool get isPlaying => _status == PlayerLoadingStatus.playing;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isShuffle => _isShuffle;
  MusicRepeatMode get repeatMode => _repeatMode;
  String get audioQuality => _audioQuality;
  String? get errorMessage => _errorMessage;
  String? get currentLyrics => _currentLyrics;
  List<LyricLine> get parsedLyrics => _parsedLyrics;
  String? get plainLyrics => _plainLyrics;
  bool get isSyncedLyrics => _parsedLyrics.isNotEmpty;
  bool get isLoadingLyrics => _isLoadingLyrics;
  bool get isPlayingOffline => _isPlayingOffline;
  AudioPlayer get audioPlayer => _player;

  PlayerStateNotifier() {
    _initListeners();
    _bindGlobalHandlerCallbacks();
  }

  void _bindGlobalHandlerCallbacks() {
    if (globalAudioHandler != null) {
      globalAudioHandler!.onSkipToNextCallback = next;
      globalAudioHandler!.onSkipToPreviousCallback = previous;
      globalAudioHandler!.onPlayCallback = resume;
      globalAudioHandler!.onPauseCallback = pause;
      globalAudioHandler!.onSeekCallback = seek;
    }
  }

  void _initListeners() {
    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();

      // ⚡ Seamless Next-Track Preload: Saat lagu berjalan 60%, pre-cache URL lagu berikutnya
      if (_duration.inSeconds > 20 && pos.inSeconds > (_duration.inSeconds * 0.6).toInt()) {
        _preloadNextTrack();
      }
    });

    _player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });

    _player.playerStateStream.listen((state) {
      final playing = state.playing;
      final processingState = state.processingState;

      if (processingState == ProcessingState.completed) {
        _handleTrackCompletion();
      } else if (processingState == ProcessingState.buffering || processingState == ProcessingState.loading) {
        _status = PlayerLoadingStatus.loading;
      } else if (playing) {
        _status = PlayerLoadingStatus.playing;
      } else if (processingState == ProcessingState.ready && !playing) {
        _status = PlayerLoadingStatus.paused;
      } else if (processingState == ProcessingState.idle) {
        _status = PlayerLoadingStatus.idle;
      }
      notifyListeners();
    });

    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        print("AudioPlayer playbackEvent notice: $e");
      },
    );
  }

  void setAudioQuality(String quality) {
    if (quality.contains('320') || quality.toLowerCase().contains('tinggi')) {
      _audioQuality = 'high';
    } else if (quality.contains('160') || quality.toLowerCase().contains('sedang')) {
      _audioQuality = 'medium';
    } else {
      _audioQuality = 'low';
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeatMode() {
    if (_repeatMode == MusicRepeatMode.off) {
      _repeatMode = MusicRepeatMode.all;
    } else if (_repeatMode == MusicRepeatMode.all) {
      _repeatMode = MusicRepeatMode.one;
    } else {
      _repeatMode = MusicRepeatMode.off;
    }
    notifyListeners();
  }

  void _handleTrackCompletion() {
    if (_repeatMode == MusicRepeatMode.one && _currentSong != null) {
      seek(Duration.zero);
      resume();
    } else {
      next();
    }
  }

  /// ⚡ Musify-style Ultra-Fast Direct Playback Engine with 0ms Cache Support & Endless Queue
  Future<void> playSong(Song song, {List<Song>? newQueue, List<Song>? queue, int? index}) async {
    final int currentRequestId = ++_playRequestId;
    final List<Song>? targetQueue = newQueue ?? queue;

    // 1. Queue Configuration
    if (targetQueue != null && targetQueue.isNotEmpty) {
      _queue = List.from(targetQueue);
      _currentIndex = index ?? _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) _currentIndex = 0;
      _currentSong = _queue[_currentIndex];
    } else {
      if (_queue.isEmpty || !_queue.any((s) => s.id == song.id)) {
        _queue = [song];
        _currentIndex = 0;
      } else {
        _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      }
      _currentSong = _queue[_currentIndex];
    }

    _bindGlobalHandlerCallbacks();

    // 2. Set MediaNotification metadata immediately
    if (globalAudioHandler != null && _currentSong != null) {
      globalAudioHandler!.setMediaItem(
        id: _currentSong!.id,
        title: _currentSong!.title,
        artist: _currentSong!.artist,
        album: _currentSong!.album,
        artUri: _currentSong!.artworkUrl,
        duration: Duration(seconds: _currentSong!.durationSeconds),
      );
    }

    // 3. Instant UI Status Update
    _status = PlayerLoadingStatus.loading;
    _position = Duration.zero;
    _duration = Duration(seconds: _currentSong!.durationSeconds);
    _errorMessage = null;
    _currentLyrics = null;
    _parsedLyrics = [];
    _plainLyrics = null;
    _isPlayingOffline = false;
    notifyListeners();

    // 4. Save to Recent History in Background (Non-blocking)
    Future.microtask(() => _recordRecentSong(_currentSong!));

    // ⚡ 5. Check Offline Audio Cache First (0ms Instant Local Playback!)
    try {
      final localPath = await AudioCacheService.instance.getLocalAudioPath(_currentSong!);
      if (localPath != null && await File(localPath).exists()) {
        final audioSource = AudioSource.file(
          localPath,
          tag: MediaItem(
            id: _currentSong!.id,
            title: _currentSong!.title,
            artist: _currentSong!.artist,
            album: _currentSong!.album,
            artUri: Uri.tryParse(_currentSong!.artworkUrl),
            duration: Duration(seconds: _currentSong!.durationSeconds),
          ),
        );

        if (_playRequestId != currentRequestId) return;

        final playFuture = _player.play();
        await _player.setAudioSource(audioSource);
        await playFuture;

        _status = PlayerLoadingStatus.playing;
        _isPlayingOffline = true;
        notifyListeners();

        _triggerPostPlaybackTasks(_currentSong!);
        return;
      }
    } catch (cacheErr) {
      print("Offline cache check notice: $cacheErr");
    }

    try {
      // 6. Fast-Track Stream Extraction (Using RAM/Disk Cache & In-flight Deduplication)
      final candidateUrls = await YoutubeAudioExtractor.getAudioStreamCandidateUrls(_currentSong!, quality: _audioQuality)
          .timeout(const Duration(seconds: 9));

      if (_playRequestId != currentRequestId) return;

      if (candidateUrls.isEmpty) {
        _status = PlayerLoadingStatus.error;
        _errorMessage = "Gagal menemukan stream '${_currentSong!.title}'. Coba lagu lain.";
        notifyListeners();
        return;
      }

      // 7. Low-Latency Streaming Playback with Immediate Play Trigger
      bool sourceSet = false;
      for (final streamUrl in candidateUrls) {
        if (_playRequestId != currentRequestId) return;
        try {
          final audioSource = AudioSource.uri(
            Uri.parse(streamUrl),
            headers: const {
              'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
            },
            tag: MediaItem(
              id: _currentSong!.id,
              title: _currentSong!.title,
              artist: _currentSong!.artist,
              album: _currentSong!.album,
              artUri: Uri.tryParse(_currentSong!.artworkUrl),
              duration: Duration(seconds: _currentSong!.durationSeconds),
            ),
          );

          // Panggil play bersamaan agar ExoPlayer langsung bersuara di chunk pertama
          final playFuture = _player.play();
          await _player.setAudioSource(audioSource);
          await playFuture;

          sourceSet = true;

          // Otomatis simpan ke cache lokal di background untuk pemutaran 0ms berikutnya
          AudioCacheService.instance.autoCacheStreamInBackground(_currentSong!, streamUrl);
          break;
        } catch (sourceErr) {
          print("AudioSource load notice for candidate URL: $sourceErr");
          continue;
        }
      }

      if (_playRequestId != currentRequestId) return;

      if (!sourceSet) {
        _status = PlayerLoadingStatus.error;
        _errorMessage = "Gagal memuat format audio untuk '${_currentSong!.title}'.";
        notifyListeners();
        return;
      }

      _status = PlayerLoadingStatus.playing;
      _isPlayingOffline = false;
      notifyListeners();

      // 8. Trigger Post-Playback Tasks (Non-blocking: Lyrics, Radio Extension, Next-Song Preload)
      _triggerPostPlaybackTasks(_currentSong!);
    } catch (e) {
      if (_playRequestId != currentRequestId) return;
      print("Playback error: $e");
      _status = PlayerLoadingStatus.error;
      _errorMessage = "Gagal memutar audio. Periksa koneksi internet.";
      notifyListeners();
    }
  }

  /// Menjalankan tugas latar belakang setelah audio mulai diputar agar tidak memblokir playback
  void _triggerPostPlaybackTasks(Song song) {
    // A. Muat lirik tanpa mengganggu bandwidth audio
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_currentSong?.id == song.id) {
        _loadLyricsAsync(song);
      }
    });

    // B. Perluas antrean dengan lagu-lagu artis & trending agar musik tidak putus-putus
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_currentSong?.id == song.id) {
        _checkAndExtendQueue();
      }
    });

    // C. Pre-load lagu berikutnya
    Future.delayed(const Duration(seconds: 2), () {
      if (_currentSong?.id == song.id) {
        _preloadNextTrack();
      }
    });
  }

  /// 🎵 Memperluas antrean otomatis dengan lagu-lagu artis / trending (Endless Radio - Ga Putus-Putus)
  Future<void> _checkAndExtendQueue() async {
    if (_isExtendingQueue || _currentSong == null) return;

    // Jika antrean tersisa 3 lagu atau kurang, otomatis tambahkan lagu-lagu penyanyi/band ini
    if (_queue.length - _currentIndex <= 3) {
      await _extendArtistRadioQueue(_currentSong!);
    }
  }

  Future<void> _extendArtistRadioQueue(Song anchorSong) async {
    if (_isExtendingQueue) return;
    _isExtendingQueue = true;

    try {
      final radioTracks = await _musicService.getArtistRadioSongs(
        anchorSong.artist,
        currentSongTitle: anchorSong.title,
        limit: 15,
      );

      if (radioTracks.isNotEmpty) {
        final existingIds = _queue.map((s) => s.id).toSet();
        final toAdd = radioTracks.where((s) => !existingIds.contains(s.id)).toList();

        if (toAdd.isNotEmpty) {
          // Jika mode shuffle aktif, acak urutan lagu yang baru ditambahkan
          if (_isShuffle) {
            toAdd.shuffle();
          }
          _queue.addAll(toAdd);
          notifyListeners();

          // Segera pre-cache lagu berikutnya
          if (_currentIndex + 1 < _queue.length) {
            YoutubeAudioExtractor.preFetchStreamUrl(_queue[_currentIndex + 1], quality: _audioQuality);
          }
        }
      }
    } catch (e) {
      print("Artist radio extend notice: $e");
    } finally {
      _isExtendingQueue = false;
    }
  }

  /// Pre-fetch URL stream lagu berikutnya agar transisi antar lagu 0ms (tanpa jeda)
  void _preloadNextTrack() {
    if (_queue.isEmpty) return;
    final int nextIndex = (_currentIndex + 1) % _queue.length;
    final nextSong = _queue[nextIndex];
    if (_lastPreloadedSongId == nextSong.id) return;
    _lastPreloadedSongId = nextSong.id;

    YoutubeAudioExtractor.preFetchStreamUrl(nextSong, quality: _audioQuality);

    // Cek juga apakah antrean perlu diperpanjang
    if (_queue.length - _currentIndex <= 3) {
      _checkAndExtendQueue();
    }
  }

  void _recordRecentSong(Song song) async {
    try {
      final recent = await _storageService.getRecent();
      recent.removeWhere((s) => s.id == song.id);
      recent.insert(0, song);
      if (recent.length > 50) recent.removeLast();
      await _storageService.saveRecent(recent);
    } catch (_) {}
  }

  void _loadLyricsAsync(Song song) async {
    _isLoadingLyrics = true;
    _parsedLyrics = [];
    _plainLyrics = null;
    notifyListeners();
    try {
      final lyrics = await _musicService.getSongLyrics(
        song.title,
        song.artist,
        durationSeconds: song.durationSeconds,
      );
      if (_currentSong?.id == song.id && lyrics != null && lyrics.trim().isNotEmpty) {
        _currentLyrics = lyrics;
        if (lyrics.contains('[') && lyrics.contains(']')) {
          _parsedLyrics = LyricLine.parseLrc(lyrics);
          if (_parsedLyrics.isEmpty) {
            _plainLyrics = lyrics;
          }
        } else {
          _plainLyrics = lyrics;
        }
      }
    } catch (_) {}
    _isLoadingLyrics = false;
    notifyListeners();
  }

  Future<void> pause() async {
    await _player.pause();
    _status = PlayerLoadingStatus.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    await _player.play();
    _status = PlayerLoadingStatus.playing;
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_status == PlayerLoadingStatus.playing) {
      await pause();
    } else if (_status == PlayerLoadingStatus.paused) {
      await resume();
    } else if (_currentSong != null) {
      await playSong(_currentSong!);
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _status = PlayerLoadingStatus.idle;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _position = position;
    notifyListeners();
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;

    if (_isShuffle) {
      if (_queue.length > 1) {
        final availableIndices = List.generate(_queue.length, (i) => i)..remove(_currentIndex);
        availableIndices.shuffle();
        _currentIndex = availableIndices.first;
      }
    } else {
      _currentIndex = _currentIndex + 1;
      if (_currentIndex >= _queue.length) {
        if (_repeatMode == MusicRepeatMode.all) {
          _currentIndex = 0;
        } else {
          // Endless Radio: Ambil lebih banyak lagu artis jika sudah di ujung antrean!
          await _extendArtistRadioQueue(_currentSong ?? _queue.last);
          if (_currentIndex >= _queue.length) {
            _currentIndex = 0;
          }
        }
      }
    }

    await playSong(_queue[_currentIndex]);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_isShuffle) {
      _currentIndex = (DateTime.now().millisecondsSinceEpoch) % _queue.length;
    } else {
      _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    }
    await playSong(_queue[_currentIndex]);
  }

  @override
  void dispose() {
    _localPlayer.dispose();
    super.dispose();
  }
}

final playerProvider = ChangeNotifierProvider<PlayerStateNotifier>((ref) {
  return PlayerStateNotifier();
});
