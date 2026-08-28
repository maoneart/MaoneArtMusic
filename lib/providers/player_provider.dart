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

  /// Musify-style Ultra-Fast Direct Playback Engine with 0ms Offline Cache Support
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

    // 3. UI Status Update
    _status = PlayerLoadingStatus.loading;
    _position = Duration.zero;
    _duration = Duration(seconds: _currentSong!.durationSeconds);
    _errorMessage = null;
    _currentLyrics = null;
    _parsedLyrics = [];
    _plainLyrics = null;
    _isPlayingOffline = false;
    notifyListeners();

    // 4. Save to Recent History
    _recordRecentSong(_currentSong!);

    // 5. Pre-fetch next tracks in background
    if (_queue.length > 1) {
      final int nextIndex = (_currentIndex + 1) % _queue.length;
      YoutubeAudioExtractor.preFetchStreamUrl(_queue[nextIndex], quality: _audioQuality);
      if (_queue.length > 2) {
        final int afterNextIndex = (_currentIndex + 2) % _queue.length;
        YoutubeAudioExtractor.preFetchStreamUrl(_queue[afterNextIndex], quality: _audioQuality);
      }
    }

    // 6. Fetch Lyrics asynchronously in background
    _loadLyricsAsync(_currentSong!);

    // ⚡ 7. Check Offline Audio Cache First (0ms Instant Playback!)
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

        await _player.setAudioSource(audioSource);
        _player.play();
        _status = PlayerLoadingStatus.playing;
        _isPlayingOffline = true;
        notifyListeners();
        return;
      }
    } catch (cacheErr) {
      print("Offline cache check notice: $cacheErr");
    }

    try {
      // 8. Extract Stream Candidate URLs for Online Streaming
      final candidateUrls = await YoutubeAudioExtractor.getAudioStreamCandidateUrls(_currentSong!, quality: _audioQuality)
          .timeout(const Duration(seconds: 10));

      if (_playRequestId != currentRequestId) return;

      if (candidateUrls.isEmpty) {
        _status = PlayerLoadingStatus.error;
        _errorMessage = "Gagal menemukan stream '${_currentSong!.title}'. Coba lagu lain.";
        notifyListeners();
        return;
      }

      // 9. Low-Latency Streaming Playback with Failover + Auto-Cache in Background
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

          await _player.setAudioSource(audioSource);
          _player.play();
          sourceSet = true;

          // 🔥 Otomatis simpan ke cache lokal di background untuk pemutaran 0ms berikutnya
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
    } catch (e) {
      if (_playRequestId != currentRequestId) return;
      print("Playback error: $e");
      _status = PlayerLoadingStatus.error;
      _errorMessage = "Gagal memutar audio. Periksa koneksi internet.";
      notifyListeners();
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
      final lyrics = await _musicService.getSongLyrics(song.title, song.artist);
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
      _currentIndex = (DateTime.now().millisecondsSinceEpoch) % _queue.length;
    } else {
      _currentIndex = (_currentIndex + 1) % _queue.length;
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
