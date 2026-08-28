import 'package:flutter/material.dart';
import '../models/lyric_line.dart';
import '../theme/maoneart_theme.dart';

class SyncedLyricsView extends StatefulWidget {
  final List<LyricLine> lyrics;
  final String? plainLyrics;
  final Duration currentPosition;
  final ValueChanged<Duration> onSeek;
  final bool isLoading;

  const SyncedLyricsView({
    Key? key,
    required this.lyrics,
    this.plainLyrics,
    required this.currentPosition,
    required this.onSeek,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;
  bool _userIsScrolling = false;
  DateTime _lastUserScrollTime = DateTime.now();

  @override
  void didUpdateWidget(covariant SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lyrics.isNotEmpty) {
      _checkAndScrollToActiveLine();
    }
  }

  void _checkAndScrollToActiveLine() {
    final int activeIndex = _calculateActiveIndex();
    if (activeIndex != _lastActiveIndex) {
      _lastActiveIndex = activeIndex;

      // Jika user sedang manual scroll dalam 2.5 detik terakhir, tunda auto-scroll
      final isRecentlyScrolled = DateTime.now().difference(_lastUserScrollTime).inMilliseconds < 2500;
      if (!_userIsScrolling && !isRecentlyScrolled && _scrollController.hasClients && activeIndex >= 0) {
        _animateScroll(activeIndex);
      }
    }
  }

  int _calculateActiveIndex() {
    if (widget.lyrics.isEmpty) return -1;
    int idx = -1;
    for (int i = 0; i < widget.lyrics.length; i++) {
      if (widget.currentPosition >= widget.lyrics[i].timestamp - const Duration(milliseconds: 250)) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  void _animateScroll(int index) {
    if (!_scrollController.hasClients) return;

    // Estimasi tinggi rata-rata baris lirik ~64px
    const double estimatedLineHeight = 64.0;
    final double viewportHeight = _scrollController.position.viewportDimension;
    // Posisikan baris aktif di 35% tinggi layar
    final double targetOffset = (index * estimatedLineHeight) - (viewportHeight * 0.35);
    final double clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: MaoneArtTheme.primaryCyan),
            SizedBox(height: 14),
            Text(
              "Mencari lirik lagu...",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (widget.lyrics.isEmpty) {
      if (widget.plainLyrics != null && widget.plainLyrics!.trim().isNotEmpty) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Text(
            widget.plainLyrics!,
            style: const TextStyle(
              fontSize: 16,
              height: 2.0,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }

      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lyrics_outlined, size: 48, color: Colors.white30),
            SizedBox(height: 12),
            Text(
              "Lirik sinkron belum tersedia untuk lagu ini",
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final int activeIndex = _calculateActiveIndex();

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        _userIsScrolling = notification.direction != ScrollDirection.idle;
        _lastUserScrollTime = DateTime.now();
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 12),
        itemCount: widget.lyrics.length,
        itemBuilder: (context, index) {
          final line = widget.lyrics[index];
          final isActive = index == activeIndex;
          final isPast = index < activeIndex;

          return GestureDetector(
            onTap: () {
              widget.onSeek(line.timestamp);
              _animateScroll(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
              margin: const EdgeInsets.symmetric(vertical: 3.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isActive
                    ? MaoneArtTheme.primaryCyan.withOpacity(0.12)
                    : Colors.transparent,
                border: isActive
                    ? Border.all(color: MaoneArtTheme.primaryCyan.withOpacity(0.35), width: 1)
                    : null,
              ),
              child: Text(
                line.text,
                style: TextStyle(
                  fontSize: isActive ? 20 : 16,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
                  height: 1.4,
                  color: isActive
                      ? Colors.white
                      : isPast
                          ? Colors.white.withOpacity(0.35)
                          : Colors.white.withOpacity(0.65),
                  shadows: isActive
                      ? [
                          Shadow(
                            color: MaoneArtTheme.primaryCyan.withOpacity(0.8),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
