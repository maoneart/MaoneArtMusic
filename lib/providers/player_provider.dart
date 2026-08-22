import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../services/youtube_audio_extractor.dart';
import '../services/audio_handler.dart';

enum PlayerLoadingStatus { idle, loading, playing, paused, error }

class PlayerStateNotifier extends ChangeNotifier {
  AudioPlayer get _audioPlayer => (globalAudioHandler as MyAudioHandler).player;

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
    _setupAudioHandlerCallbacks();
  }

  void _setupAudioHandlerCallbacks() {
    final handler = globalAudioHandler as MyAudioHandler;
    handler.onSkipToNextCallback = () => next();
    handler.onSkipToPreviousCallback = () => previous();
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
    _position = Duration.zero;
    _duration = Duration.zero;
    _errorMessage = null;
    notifyListeners();

    // Update Android MediaSession / Samsung One UI notification metadata immediately
    (globalAudioHandler as MyAudioHandler).setMediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      artUri: song.artworkUrl,
      duration: Duration(seconds: song.durationSeconds),
    );

    try {
      // 1. Fully stop audio player and clear previous audio buffer pipeline
      await _audioPlayer.stop();

      // 2. Resolve FULL-LENGTH Audio Stream (unthrottled 200 OK) for the selected new song
      String? streamUrl = await YoutubeAudioExtractor.getAudioStreamUrl(song);

      if (streamUrl == null || streamUrl.isEmpty) {
        _status = PlayerLoadingStatus.error;
        _errorMessage = "Gagal mengambil audio YouTube untuk '${song.title}'.";
        notifyListeners();
        return;
      }

      // 3. Set new AudioSource and force initialPosition to Duration.zero so ExoPlayer plays the NEW stream instantly
      final audioSource = AudioSource.uri(Uri.parse(streamUrl));

      await _audioPlayer.setAudioSource(audioSource, initialPosition: Duration.zero);
      await _audioPlayer.play();
      _status = PlayerLoadingStatus.playing;
    } catch (e) {
      print("Full YouTube Playback error for ${song.title}: $e");
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
