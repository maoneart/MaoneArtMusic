import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/maoneart_theme.dart';

class AppArtwork extends StatelessWidget {
  final String artworkUrl;
  final double width;
  final double height;
  final double borderRadius;
  final IconData placeholderIcon;
  final double iconSize;

  const AppArtwork({
    Key? key,
    required this.artworkUrl,
    required this.width,
    required this.height,
    this.borderRadius = 12,
    this.placeholderIcon = Icons.music_note,
    this.iconSize = 28,
  }) : super(key: key);

  Widget _buildFallback(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(
          colors: [MaoneArtTheme.spotifyGreen, MaoneArtTheme.primaryPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(placeholderIcon, color: Colors.white, size: iconSize),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (artworkUrl.isEmpty) {
      return _buildFallback(context);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: artworkUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: Colors.white.withOpacity(0.08),
          child: Center(
            child: Icon(placeholderIcon, color: Colors.white54, size: iconSize * 0.8),
          ),
        ),
        errorWidget: (context, url, error) => _buildFallback(context),
      ),
    );
  }
}
