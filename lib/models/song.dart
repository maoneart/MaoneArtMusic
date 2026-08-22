import 'dart:convert';

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final int durationSeconds;
  final String? youtubeId;
  final String? streamUrl;
  final String? previewUrl;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.durationSeconds,
    this.youtubeId,
    this.streamUrl,
    this.previewUrl,
  });

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    int? durationSeconds,
    String? youtubeId,
    String? streamUrl,
    String? previewUrl,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      youtubeId: youtubeId ?? this.youtubeId,
      streamUrl: streamUrl ?? this.streamUrl,
      previewUrl: previewUrl ?? this.previewUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'artworkUrl': artworkUrl,
      'durationSeconds': durationSeconds,
      'youtubeId': youtubeId,
      'streamUrl': streamUrl,
      'previewUrl': previewUrl,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Unknown Title',
      artist: map['artist'] ?? 'Unknown Artist',
      album: map['album'] ?? 'Single',
      artworkUrl: map['artworkUrl'] ?? '',
      durationSeconds: map['durationSeconds']?.toInt() ?? 0,
      youtubeId: map['youtubeId'],
      streamUrl: map['streamUrl'],
      previewUrl: map['previewUrl'],
    );
  }

  String toJson() => json.encode(toMap());

  factory Song.fromJson(String source) => Song.fromMap(json.decode(source));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Song && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
