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
  final bool isLive;
  final String? lyrics;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.durationSeconds,
    this.youtubeId,
    this.streamUrl,
    this.isLive = false,
    this.lyrics,
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
    bool? isLive,
    String? lyrics,
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
      isLive: isLive ?? this.isLive,
      lyrics: lyrics ?? this.lyrics,
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
      'isLive': isLive,
      'lyrics': lyrics,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Unknown Title',
      artist: map['artist']?.toString() ?? 'Unknown Artist',
      album: map['album']?.toString() ?? 'Single',
      artworkUrl: map['artworkUrl']?.toString() ?? '',
      durationSeconds: (map['durationSeconds'] ?? map['duration'] ?? 0) is num
          ? (map['durationSeconds'] ?? map['duration'] ?? 0).toInt()
          : int.tryParse(map['durationSeconds']?.toString() ?? '0') ?? 0,
      youtubeId: map['youtubeId']?.toString() ?? map['ytid']?.toString(),
      streamUrl: map['streamUrl']?.toString(),
      isLive: map['isLive'] == true,
      lyrics: map['lyrics']?.toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Song.fromJson(String source) => Song.fromMap(json.decode(source));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Song &&
        (other.id == id ||
            (youtubeId != null &&
                youtubeId!.isNotEmpty &&
                other.youtubeId == youtubeId));
  }

  @override
  int get hashCode => (youtubeId != null && youtubeId!.isNotEmpty)
      ? youtubeId.hashCode
      : id.hashCode;
}
