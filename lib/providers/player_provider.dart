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
      final isPlaying = state.playing;
      final processingState = state.processingState;

      if (processingState == ProcessingState.completed) {
        // ONLY advance to next song if track played to end (within 5 seconds of duration)
        if (_duration.inSeconds > 0 && _position.inSeconds >= _duration.inSeconds - 5) {
          next();
        } else {
          _status = PlayerLoadingStatus.paused;
        }
      } else if (isPlaying && (processingState == ProcessingState.ready || processingState == ProcessingState.buffering)) {
        _status = PlayerLoadingStatus.playing;
      } else if (!isPlaying && (processingState == ProcessingState.buffering || processingState == ProcessingState.loading)) {
        _status = PlayerLoadingStatus.loading;
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
        _status = PlayerLoadingStatus.error;
        _errorMessage = "Gagal memutar audio: $e";
        notifyListeners();
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

  /// Play a song or queue of songs with instant UI feedback & concurrency guards
  Future<void> playSong(Song song, {List<Song>? newQueue, int index = 0}) async {
    _setupAudioHandlerCallbacks();

    // 1. Increment Play Request ID to invalidate old pending extractions
    _playRequestId++;
    final int currentRequestId = _playRequestId;

    // 2. Stop current audio immediately so old track stops playing
    try {
      await _audioPlayer.stop();
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

    // 5. Trigger background pre-fetching for adjacent tracks (0ms delay for Next / Previous)
    if (_queue.length > 1) {
      final int nextIndex = (_currentIndex + 1) % _queue.length;
      final int prevIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
      YoutubeAudioExtractor.preFetchStreamUrl(_queue[nextIndex]);
      YoutubeAudioExtractor.preFetchStreamUrl(_queue[prevIndex]);
    }

    try {
      // 6. Asynchronously extract stream URL
      String? streamUrl = await YoutubeAudioExtractor.getAudioStreamUrl(_currentSong!);

      // Check if user clicked Next/Prev or another track during network fetch
      if (_playRequestId != currentRequestId) {
        print("Discarding stale play request ($currentRequestId vs $_playRequestId)");
        return;
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        _status = PlayerLoadingStatus.error;
        _errorMessage = "Gagal memutar audio '${_currentSong!.title}'. Coba lagu lain.";
        notifyListeners();
        return;
      }

      // 7. Set AudioSource and start playing immediately
      final audioSource = AudioSource.uri(
        Uri.parse(streamUrl),
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      await _audioPlayer.setAudioSource(audioSource, initialPosition: Duration.zero);

      if (_playRequestId != currentRequestId) return;

      await _audioPlayer.play();
      _status = PlayerLoadingStatus.playing;
      notifyListeners();
    } catch (e) {
      if (_playRequestId != currentRequestId) return;
      print("Full Playback error for ${_currentSong?.title}: $e");

      // Retry with direct Audio CDN fallback if YouTube streamUrl failed
      if (song.streamUrl != null && song.streamUrl!.isNotEmpty) {
        try {
          print("⚡ Retrying playback with direct Audio CDN fallback...");
          final fallbackSource = AudioSource.uri(Uri.parse(song.streamUrl!));
          await _audioPlayer.setAudioSource(fallbackSource, initialPosition: Duration.zero);
          await _audioPlayer.play();
          _status = PlayerLoadingStatus.playing;
          notifyListeners();
          return;
        } catch (fallbackErr) {
          print("Fallback playback error: $fallbackErr");
        }
      }

      _status = PlayerLoadingStatus.error;
      _errorMessage = "Gagal memutar '${_currentSong?.title}': $e";
      notifyListeners();
    }
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
        _status = PlayerLoadingStatus.paused;
      } else if (_status == PlayerLoadingStatus.loading) {
        try {
          await _audioPlayer.stop();
        } catch (_) {}
        _status = PlayerLoadingStatus.paused;
      } else {
        if (_currentSong != null) {
          if (_audioPlayer.audioSource == null) {
            await playSong(_currentSong!, index: _currentIndex);
            return;
          }
          await _audioPlayer.play();
          _status = PlayerLoadingStatus.playing;
        }
      }
    } catch (e) {
      print("Error in togglePlayPause: $e");
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

    await playSong(_queue[nextIdx], newQueue: _queue, index: nextIdx);
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

    await playSong(_queue[prevIdx], newQueue: _queue, index: prevIdx);
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
