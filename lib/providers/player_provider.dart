import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../services/youtube_audio_extractor.dart';

enum PlayerLoadingStatus { idle, loading, playing, paused, error }

class PlayerStateNotifier extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;
  PlayerLoadingStatus _status = PlayerLoadingStatus.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _errorMessage;

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

  PlayerStateNotifier() {
    _initListeners();
  }

  void _initListeners() {
    _audioPlayer.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        next();
      } else if (state.playing) {
        _status = PlayerLoadingStatus.playing;
      } else if (state.processingState == ProcessingState.ready) {
        if (state.playing) {
          _status = PlayerLoadingStatus.playing;
        } else {
          _status = PlayerLoadingStatus.paused;
        }
      }
      notifyListeners();
    });
  }

  /// Play a song or queue of songs
  Future<void> playSong(Song song, {List<Song>? newQueue, int index = 0}) async {
    if (newQueue != null && newQueue.isNotEmpty) {
      _queue = List.from(newQueue);
      _currentIndex = index;
    } else if (!_queue.any((s) => s.id == song.id)) {
      _queue.add(song);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    }

    _currentSong = song;
    _status = PlayerLoadingStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Stop current audio player
      await _audioPlayer.stop();

      // 2. Resolve FULL-LENGTH Audio Stream (unthrottled 200 OK) for the selected song
      String? streamUrl = await YoutubeAudioExtractor.getAudioStreamUrl(song);

      // Fail-safe fallback if YouTube search is delayed on slow network
      if ((streamUrl == null || streamUrl.isEmpty) && song.previewUrl != null && song.previewUrl!.isNotEmpty) {
        print("YouTube search timeout, using previewUrl fallback: ${song.previewUrl}");
        streamUrl = song.previewUrl;
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        _status = PlayerLoadingStatus.error;
        _errorMessage = "Gagal mengambil audio untuk '${song.title}'.";
        notifyListeners();
        return;
      }

      // 3. Set LockCachingAudioSource for instant 0.0s local cache re-play & data saving
      final audioSource = LockCachingAudioSource(Uri.parse(streamUrl));

      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();
      _status = PlayerLoadingStatus.playing;
    } catch (e) {
      print("Full YouTube Playback error for ${song.title}: $e");
      // Secondary fail-safe fallback using standard AudioSource.uri
      if (song.previewUrl != null && song.previewUrl!.isNotEmpty) {
        try {
          final fallbackSource = AudioSource.uri(Uri.parse(song.previewUrl!));
          await _audioPlayer.setAudioSource(fallbackSource);
          await _audioPlayer.play();
          _status = PlayerLoadingStatus.playing;
          notifyListeners();
          return;
        } catch (_) {}
      }
      _status = PlayerLoadingStatus.error;
      _errorMessage = "Gagal memutar '${song.title}': $e";
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
    if (_queue.isEmpty || _currentIndex >= _queue.length - 1) return;
    _currentIndex++;
    await playSong(_queue[_currentIndex]);
  }

  Future<void> previous() async {
    if (_queue.isEmpty || _currentIndex <= 0) return;
    _currentIndex--;
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
