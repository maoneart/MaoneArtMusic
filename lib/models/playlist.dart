import 'dart:convert';
import 'song.dart';

class Playlist {
  final String id;
  final String name;
  final String description;
  final String? artworkUrl;
  final List<Song> songs;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    this.description = '',
    this.artworkUrl,
    required this.songs,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    String? artworkUrl,
    List<Song>? songs,
    DateTime? createdAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      songs: songs ?? this.songs,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'artworkUrl': artworkUrl,
      'songs': songs.map((x) => x.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Untitled Playlist',
      description: map['description']?.toString() ?? '',
      artworkUrl: map['artworkUrl']?.toString(),
      songs: List<Song>.from(
        (map['songs'] as List?)?.map((x) => Song.fromMap(Map<String, dynamic>.from(x))) ?? [],
      ),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Playlist.fromJson(String source) => Playlist.fromMap(json.decode(source));
}
