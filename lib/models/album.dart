import 'song.dart';

class Album {
  final String id;
  final String browseId;
  final String title;
  final String artist;
  final String artworkUrl;
  final String type; // 'Album' or 'Playlist'
  final String? year;
  final List<Song> songs;

  Album({
    required this.id,
    required this.browseId,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    this.type = 'Album',
    this.year,
    this.songs = const [],
  });

  Album copyWith({
    String? id,
    String? browseId,
    String? title,
    String? artist,
    String? artworkUrl,
    String? type,
    String? year,
    List<Song>? songs,
  }) {
    return Album(
      id: id ?? this.id,
      browseId: browseId ?? this.browseId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      type: type ?? this.type,
      year: year ?? this.year,
      songs: songs ?? this.songs,
    );
  }
}
