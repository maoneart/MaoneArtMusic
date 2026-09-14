import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../theme/maoneart_theme.dart';
import 'glass_container.dart';

class ArtistBar extends StatelessWidget {
  final Artist artist;
  final VoidCallback? onTap;
  final VoidCallback? onPlayTap;

  const ArtistBar({
    Key? key,
    required this.artist,
    this.onTap,
    this.onPlayTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: GlassContainer(
        borderRadius: 16,
        opacity: 0.12,
        padding: const EdgeInsets.all(12),
        border: Border.all(
          color: MaoneArtTheme.spotifyGreen.withOpacity(0.3),
          width: 1.2,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Row(
            children: [
              // Circular Artist Avatar
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: MaoneArtTheme.spotifyGreen.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: artist.avatarUrl != null && artist.avatarUrl!.isNotEmpty
                      ? Image.network(
                          artist.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackAvatar(),
                        )
                      : _fallbackAvatar(),
                ),
              ),
              const SizedBox(width: 14),

              // Artist Info (Name & Subtitle)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            artist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        if (artist.isVerified) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified,
                            color: MaoneArtTheme.spotifyGreenBright,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      artist.subtitle ?? 'Artis Resmi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Quick Play / Action Button
              if (onPlayTap != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: onPlayTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            MaoneArtTheme.spotifyGreen,
                            MaoneArtTheme.spotifyGreenBright,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: MaoneArtTheme.spotifyGreenBright.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "Putar",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.6),
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: MaoneArtTheme.bgDark,
      child: const Icon(
        Icons.person_rounded,
        color: MaoneArtTheme.spotifyGreenBright,
        size: 30,
      ),
    );
  }
}
