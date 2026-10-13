import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

MyAudioHandler? globalAudioHandler;

Future<MyAudioHandler?> initAudioService() async {
  try {
    final handler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.maoneart.music.channel.audio',
        androidNotificationChannelName: 'MaoneArt Music Playback',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: true,
        notificationColor: Color(0xFF00F0FF),
      ),
    );
    globalAudioHandler = handler;
    return globalAudioHandler;
  } catch (e) {
    print('AudioService initialization error: $e');
    return null;
  }
}

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  late final AudioPlayer _player;

  Future<void> Function()? onSkipToNextCallback;
  Future<void> Function()? onSkipToPreviousCallback;
  Future<void> Function()? onPlayCallback;
  Future<void> Function()? onPauseCallback;
  Future<void> Function(Duration)? onSeekCallback;

  AudioPlayer get player => _player;

  MyAudioHandler() {
    _player = AudioPlayer(
      audioLoadConfiguration: const AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          maxBufferDuration: Duration(seconds: 60),
          bufferForPlaybackDuration: Duration(milliseconds: 250),
          bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
        ),
      ),
    );

    _initAudioSession();
    _initListeners();
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      _player.setAndroidAudioAttributes(
        const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
      );
    } catch (e) {
      print("AudioSession setup notice: $e");
    }
  }

  void _initListeners() {
    _player.positionStream.listen((pos) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: pos,
      ));
    });

    _player.durationStream.listen((dur) {
      final item = mediaItem.value;
      if (item != null && dur != null) {
        mediaItem.add(item.copyWith(duration: dur));
      }
    });

    _player.playerStateStream.listen((state) {
      final isPlaying = state.playing;
      final processingState = state.processingState;

      AudioProcessingState audioProcessingState = AudioProcessingState.idle;
      switch (processingState) {
        case ProcessingState.idle:
          audioProcessingState = AudioProcessingState.idle;
          break;
        case ProcessingState.loading:
          audioProcessingState = AudioProcessingState.loading;
          break;
        case ProcessingState.buffering:
          audioProcessingState = AudioProcessingState.buffering;
          break;
        case ProcessingState.ready:
          audioProcessingState = AudioProcessingState.ready;
          break;
        case ProcessingState.completed:
          audioProcessingState = AudioProcessingState.completed;
          break;
      }

      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: audioProcessingState,
        playing: isPlaying,
      ));
    });
  }

  @override
  Future<void> play() async {
    if (onPlayCallback != null) {
      await onPlayCallback!();
    } else {
      await _player.play();
    }
  }

  @override
  Future<void> pause() async {
    if (onPauseCallback != null) {
      await onPauseCallback!();
    } else {
      await _player.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (onSeekCallback != null) {
      await onSeekCallback!(position);
    } else {
      await _player.seek(position);
    }
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> skipToNext() async {
    if (onSkipToNextCallback != null) {
      await onSkipToNextCallback!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipToPreviousCallback != null) {
      await onSkipToPreviousCallback!();
    }
  }

  Timer? _headsetClickTimer;
  int _headsetClickCount = 0;

  /// ⚡ Headset & Bluetooth Media Button Handler:
  /// - 1x klik: Play / Pause toggle
  /// - 2x klik cepat (dalam 380ms): Skip to Next track (Lagu berikutnya)
  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    if (button == MediaButton.next) {
      await skipToNext();
      return;
    }
    if (button == MediaButton.previous) {
      await skipToPrevious();
      return;
    }

    _headsetClickCount++;
    if (_headsetClickCount == 1) {
      _headsetClickTimer?.cancel();
      _headsetClickTimer = Timer(const Duration(milliseconds: 380), () async {
        if (_headsetClickCount == 1) {
          if (_player.playing) {
            await pause();
          } else {
            await play();
          }
        }
        _headsetClickCount = 0;
      });
    } else if (_headsetClickCount >= 2) {
      _headsetClickTimer?.cancel();
      _headsetClickCount = 0;
      await skipToNext();
    }
  }

  void setMediaItem({
    required String id,
    required String title,
    required String artist,
    required String album,
    required String artUri,
    Duration? duration,
  }) {
    mediaItem.add(MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      artUri: Uri.tryParse(artUri),
      duration: duration,
    ));
  }
}
