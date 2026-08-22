import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../services/youtube_audio_extractor.dart';
import '../services/audio_handler.dart';

enum PlayerLoadingStatus { idle, loading, playing, paused, error }
enum RepeatMode { off, all, one }

class PlayerStateNotifier extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;
  PlayerLoadingStatus _status = PlayerLoadingStatus.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isShuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;
  String? _errorMessage;
  int _playRequestId = 0;

  Song? get currentSong => _currentSong;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  PlayerLoadingStatus get status => _status;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isShuffle => _isShuffle;
  RepeatMode get repeatMode => _repeatMode;
  String? get errorMessage => _errorMessage;
  AudioPlayer get audioPlayer => _audioPlayer;

  PlayerStateNotifier() {
    _initListeners();
  }

  void _initListeners() {
    _audioPlayer.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      final isPlaying = state.playing;
      final processingState = state.processingState;

      if (processingState == ProcessingState.completed) {
        if (_duration.inSeconds > 0 && _position.inSeconds >= _duration.inSeconds - 5) {
          next();
        } else {
          _status = PlayerLoadingStatus.paused;
        }
      } else if (isPlaying) {
        _status = PlayerLoadingStatus.playing;
      } else if (processingState == ProcessingState.ready && !isPlaying) {
        _status = PlayerLoadingStatus.paused;
      } else if (processingState == ProcessingState.idle) {
        _status = PlayerLoadingStatus.idle;
      }
      notifyListeners();
    });

    _audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        print("AudioPlayer playbackEvent error: $e");
      },
    );
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeatMode() {
    if (_repeatMode == RepeatMode.off) {
      _repeatMode = RepeatMode.all;
    } else if (_repeatMode == RepeatMode.all) {
      _repeatMode = RepeatMode.one;
    } else {
      _repeatMode = RepeatMode.off;
    }
    notifyListeners();
  }

  /// Musify-style Playback Engine (Instant UI response & YouTube stream extraction)
  Future<void> playSong(Song song, {List<Song>? newQueue, List<Song>? queue, int? index}) async {
    final int currentRequestId = ++_playRequestId;
    final List<Song>? targetQueue = newQueue ?? queue;

    // 1. Queue Management
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

    // 2. Update MediaSession metadata immediately for Android notification
    if (globalAudioHandler is MyAudioHandler && _currentSong != null) {
      (globalAudioHandler as MyAudioHandler).setMediaItem(
        id: _currentSong!.id,
        title: _currentSong!.title,
        artist: _currentSong!.artist,
        album: _currentSong!.album,
        artUri: _currentSong!.artworkUrl,
        duration: Duration(seconds: _currentSong!.durationSeconds),
      );
    }

    // 3. Instant UI feedback (Musify style: set to playing state immediately!)
    _status = PlayerLoadingStatus.playing;
    _position = Duration.zero;
    _duration = Duration(seconds: _currentSong!.durationSeconds);
    _errorMessage = null;
    notifyListeners();

    // 4. Trigger background pre-fetching for adjacent tracks
    if (_queue.length > 1) {
      final int nextIndex = (_currentIndex + 1) % _queue.length;
      final int prevIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
      YoutubeAudioExtractor.preFetchStreamUrl(_queue[nextIndex]);
      YoutubeAudioExtractor.preFetchStreamUrl(_queue[prevIndex]);
    }

    try {
      // 5. Asynchronously extract stream URL (YouTube / Audio CDN)
      String? streamUrl;
      try {
        streamUrl = await YoutubeAudioExtractor.getAudioStreamUrl(_currentSong!).timeout(const Duration(seconds: 4));
      } catch (_) {}

      if ((streamUrl == null || streamUrl.isEmpty) && song.streamUrl != null && song.streamUrl!.isNotEmpty) {
        print("⚡ Musify Instant Stream Fallback for: ${song.title}");
        streamUrl = song.streamUrl;
      }

      if (_playRequestId != currentRequestId) return;

      if (streamUrl == null || streamUrl.isEmpty) {
        _status = PlayerLoadingStatus.error;
        _errorMessage = "Gagal memutar audio '${_currentSong!.title}'. Coba lagu lain.";
        notifyListeners();
        return;
      }

      // 6. Set URL and start playback
      await _audioPlayer.setUrl(streamUrl);

      if (_playRequestId != currentRequestId) return;

      await _audioPlayer.play();
      _status = PlayerLoadingStatus.playing;
      notifyListeners();
    } catch (e) {
      if (_playRequestId != currentRequestId) return;
      print("Musify Playback error for ${_currentSong?.title}: $e");

      if (song.streamUrl != null && song.streamUrl!.isNotEmpty) {
        try {
          await _audioPlayer.setUrl(song.streamUrl!);
          await _audioPlayer.play();
          _status = PlayerLoadingStatus.playing;
          notifyListeners();
          return;
        } catch (fallbackErr) {
          print("Fallback error: $fallbackErr");
        }
      }

      _status = PlayerLoadingStatus.error;
      _errorMessage = "Gagal memutar audio. Periksa koneksi internet Anda.";
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _status = PlayerLoadingStatus.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
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
    await _audioPlayer.stop();
    _status = PlayerLoadingStatus.idle;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
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
    _audioPlayer.dispose();
    super.dispose();
  }
}

final playerProvider = ChangeNotifierProvider<PlayerStateNotifier>((ref) {
  return PlayerStateNotifier();
});
