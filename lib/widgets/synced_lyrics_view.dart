import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  List<GlobalKey> _lineKeys = [];
  int _lastActiveIndex = -1;
  bool _userIsScrolling = false;
  DateTime _lastUserScrollTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _rebuildKeys();
  }

  void _rebuildKeys() {
    _lineKeys = List.generate(widget.lyrics.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lyrics.length != _lineKeys.length) {
      _rebuildKeys();
    }
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
      if (!_userIsScrolling && !isRecentlyScrolled && activeIndex >= 0 && activeIndex < _lineKeys.length) {
        _animateScroll(activeIndex);
      }
    }
  }

  int _calculateActiveIndex() {
    if (widget.lyrics.isEmpty) return -1;
    int idx = -1;
    for (int i = 0; i < widget.lyrics.length; i++) {
      if (widget.currentPosition >= widget.lyrics[i].timestamp - const Duration(milliseconds: 50)) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  void _animateScroll(int index) {
    if (index < 0 || index >= _lineKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final keyContext = _lineKeys[index].currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
          alignment: 0.5, // ⚡ EXACT VERTICAL CENTER (Selalu Pas di Tengah Layar!)
        );
      }
    });
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
    final double viewportHeight = MediaQuery.of(context).size.height;

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        _userIsScrolling = notification.direction != ScrollDirection.idle;
        _lastUserScrollTime = DateTime.now();
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        // Vertical padding set to ~45% of viewport height so both line 1 and last line can align perfectly to center
        padding: EdgeInsets.symmetric(
          vertical: viewportHeight * 0.42,
          horizontal: 16,
        ),
        itemCount: widget.lyrics.length,
        itemBuilder: (context, index) {
          final line = widget.lyrics[index];
          final isActive = index == activeIndex;
          final isPast = index < activeIndex;
          final key = index < _lineKeys.length ? _lineKeys[index] : null;

          return GestureDetector(
            key: key,
            onTap: () {
              widget.onSeek(line.timestamp);
              _animateScroll(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isActive
                    ? MaoneArtTheme.primaryCyan.withOpacity(0.16)
                    : Colors.transparent,
                border: isActive
                    ? Border.all(color: MaoneArtTheme.primaryCyan.withOpacity(0.45), width: 1.2)
                    : null,
              ),
              child: Text(
                line.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isActive ? 22 : 16,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
                  height: 1.45,
                  color: isActive
                      ? Colors.white
                      : isPast
                          ? Colors.white.withOpacity(0.35)
                          : Colors.white.withOpacity(0.65),
                  shadows: isActive
                      ? [
                          Shadow(
                            color: MaoneArtTheme.primaryCyan.withOpacity(0.9),
                            blurRadius: 20,
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
