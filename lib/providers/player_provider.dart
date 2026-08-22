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
      _queue = newQueue;
      _currentIndex = index;
    } else if (!_queue.contains(song)) {
      _queue.add(song);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexOf(song);
    }

    _currentSong = song;
    _status = PlayerLoadingStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Stop current audio
      await _audioPlayer.stop();

      // 2. Resolve FULL-LENGTH Audio Stream from YouTube
      String? streamUrl = song.streamUrl;
      if (streamUrl == null || streamUrl.isEmpty) {
        streamUrl = await YoutubeAudioExtractor.getAudioStreamUrl(song);
      }

      // Fallback to previewUrl only if YouTube stream resolution fails
      if ((streamUrl == null || streamUrl.isEmpty) && song.previewUrl != null) {
        streamUrl = song.previewUrl;
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        _status = PlayerLoadingStatus.error;
        _errorMessage = "Gagal mengekstrak audio lagu dari YouTube.";
        notifyListeners();
        return;
      }

      // 3. Play full audio stream via just_audio
      final audioSource = AudioSource.uri(
        Uri.parse(streamUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Referer': 'https://www.youtube.com/',
        },
      );

      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();
      _status = PlayerLoadingStatus.playing;
    } catch (e) {
      print("Playback error: $e");
      // If primary YouTube stream fails, attempt previewUrl
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
      _errorMessage = "Gagal memutar lagu: $e";
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
