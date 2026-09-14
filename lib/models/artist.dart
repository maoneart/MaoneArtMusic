class Artist {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? subtitle;
  final bool isVerified;

  const Artist({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.subtitle,
    this.isVerified = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'avatarUrl': avatarUrl,
    'subtitle': subtitle,
    'isVerified': isVerified,
  };

  factory Artist.fromMap(Map<String, dynamic> map) => Artist(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    avatarUrl: map['avatarUrl'],
    subtitle: map['subtitle'],
    isVerified: map['isVerified'] ?? true,
  );
}
