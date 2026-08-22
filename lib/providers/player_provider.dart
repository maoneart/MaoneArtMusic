import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../services/youtube_audio_extractor.dart';
import '../services/audio_handler.dart';

enum PlayerLoadingStatus { idle, loading, playing, paused, error }
enum RepeatMode { off, all, one }

class PlayerStateNotifier extends ChangeNotifier {
  final AudioPlayer _fallbackPlayer = AudioPlayer();

  AudioPlayer get _audioPlayer {
    if (globalAudioHandler is MyAudioHandler) {
      return (globalAudioHandler as MyAudioHandler).player;
    }
    return _fallbackPlayer;
  }

  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;
  PlayerLoadingStatus _status = PlayerLoadingStatus.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _errorMessage;

  // Track concurrency & playback options
  int _playRequestId = 0;
  bool _isShuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;

  // Getters
  AudioPlayer get audioPlayer => _audioPlayer;
  Song? get currentSong => _currentSong;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  PlayerLoadingStatus get status => _status;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get errorMessage => _errorMessage;
  bool get isPlaying => _audioPlayer.playing;
  bool get isShuffle => _isShuffle;
  RepeatMode get repeatMode => _repeatMode;

  PlayerStateNotifier() {
    _initListeners();
    _setupAudioHandlerCallbacks();
  }

  void _setupAudioHandlerCallbacks() {
    if (globalAudioHandler is MyAudioHandler) {
      final handler = globalAudioHandler as MyAudioHandler;
      handler.onSkipToNextCallback = () => next();
      handler.onSkipToPreviousCallback = () => previous();
    }
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
      // Do not overwrite UI status while loading a new track
      if (_status == PlayerLoadingStatus.loading) {
        return;
      }

      if (state.processingState == ProcessingState.completed) {
        next();
      } else if (state.playing) {
        _status = PlayerLoadingStatus.playing;
      } else if (state.processingState == ProcessingState.ready) {
        _status = state.playing ? PlayerLoadingStatus.playing : PlayerLoadingStatus.paused;
      }
      notifyListeners();
    });
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

  /// Play a song or queue of songs with instant UI feedback & concurrency guards
  Future<void> playSong(Song song, {List<Song>? newQueue, int index = 0}) async {
    _setupAudioHandlerCallbacks();

    // 1. Increment Play Request ID to invalidate old pending extractions
    _playRequestId++;
    final int currentRequestId = _playRequestId;

    // 2. Pause audio immediately so old track audio stops playing
    try {
      await _audioPlayer.pause();
    } catch (_) {}

    // 3. Update Queue and Current Index
    if (newQueue != null && newQueue.isNotEmpty) {
      _queue = List.from(newQueue);
      _currentIndex = index.clamp(0, _queue.length - 1);
      _currentSong = _queue[_currentIndex];
    } else {
      if (!_queue.any((s) => s.id == song.id)) {
        _queue.add(song);
        _currentIndex = _queue.length - 1;
      } else {
        _currentIndex = index >= 0 && index < _queue.length
            ? index
            : _queue.indexWhere((s) => s.id == song.id);
      }
      _currentSong = _queue[_currentIndex];
    }

    // 4. Instant UI state update
    _status = PlayerLoadingStatus.loading;
    _position = Duration.zero;
    _duration = Duration.zero;
    _errorMessage = null;
    notifyListeners();

    // Update MediaSession metadata immediately for Android notification
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

    try {
      // 5. Asynchronously extract stream URL
      String? streamUrl = await YoutubeAudioExtractor.getAudioStreamUrl(_currentSong!);

      // Check if user clicked Next/Prev or another track during network fetch
      if (_playRequestId != currentRequestId) {
        print("Discarding stale play request ($currentRequestId vs $_playRequestId)");
        return;
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        _status = PlayerLoadingStatus.error;
        _errorMessage = "Gagal mengambil audio YouTube untuk '${_currentSong!.title}'.";
        notifyListeners();

        // Auto-advance to next song if queue is available
        Future.delayed(const Duration(seconds: 2), () {
          if (_playRequestId == currentRequestId && _status == PlayerLoadingStatus.error) {
            next();
          }
        });
        return;
      }

      // 6. Set AudioSource and play
      final audioSource = AudioSource.uri(Uri.parse(streamUrl));
      await _audioPlayer.setAudioSource(audioSource, initialPosition: Duration.zero);

      if (_playRequestId != currentRequestId) return;

      await _audioPlayer.play();
      _status = PlayerLoadingStatus.playing;
    } catch (e) {
      if (_playRequestId != currentRequestId) return;
      print("Full YouTube Playback error for ${_currentSong?.title}: $e");
      _status = PlayerLoadingStatus.error;
      _errorMessage = "Gagal memutar '${_currentSong?.title}': $e";
    }
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    notifyListeners();
  }

  Future<void> seek(Duration newPosition) async {
    await _audioPlayer.seek(newPosition);
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;

    if (_repeatMode == RepeatMode.one && _currentSong != null) {
      await playSong(_currentSong!, index: _currentIndex);
      return;
    }

    int nextIdx;
    if (_isShuffle && _queue.length > 1) {
      final availableIndices = List.generate(_queue.length, (i) => i)..remove(_currentIndex);
      availableIndices.shuffle(Random());
      nextIdx = availableIndices.first;
    } else {
      nextIdx = _currentIndex + 1;
      if (nextIdx >= _queue.length) {
        nextIdx = 0;
      }
    }

    await playSong(_queue[nextIdx], index: nextIdx);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;

    // If current position is > 3 seconds, restart current track
    if (_position.inSeconds > 3 && _currentSong != null) {
      await seek(Duration.zero);
      return;
    }

    int prevIdx;
    if (_isShuffle && _queue.length > 1) {
      final availableIndices = List.generate(_queue.length, (i) => i)..remove(_currentIndex);
      availableIndices.shuffle(Random());
      prevIdx = availableIndices.first;
    } else {
      prevIdx = _currentIndex - 1;
      if (prevIdx < 0) {
        prevIdx = _queue.length - 1;
      }
    }

    await playSong(_queue[prevIdx], index: prevIdx);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _fallbackPlayer.dispose();
    super.dispose();
  }
}

final playerProvider = ChangeNotifierProvider<PlayerStateNotifier>((ref) {
  return PlayerStateNotifier();
});
