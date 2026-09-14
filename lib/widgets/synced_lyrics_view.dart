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

const double _kLyricLineHeight = 68.0;

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  late final ScrollController _scrollController;
  int _lastActiveIndex = -1;
  bool _userIsScrolling = false;
  DateTime _lastUserScrollTime = DateTime.now();
  bool _hasInitiallyScrolled = false;

  @override
  void initState() {
    super.initState();
    final activeIndex = _calculateActiveIndex();
    final initialOffset = (activeIndex > 0 && widget.lyrics.isNotEmpty)
        ? (activeIndex * _kLyricLineHeight)
        : 0.0;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialJumpToCurrentLine();
    });
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lyrics.isNotEmpty) {
      if (!_hasInitiallyScrolled || oldWidget.lyrics.isEmpty) {
        _initialJumpToCurrentLine();
      } else {
        _checkAndScrollToActiveLine();
      }
    }
  }

  void _initialJumpToCurrentLine() {
    if (!mounted || widget.lyrics.isEmpty) return;
    final int activeIndex = _calculateActiveIndex();
    if (activeIndex >= 0 && activeIndex < widget.lyrics.length) {
      _lastActiveIndex = activeIndex;
      final double targetOffset = activeIndex * _kLyricLineHeight;
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          final double clampedOffset = targetOffset.clamp(0.0, maxScroll);
          _scrollController.jumpTo(clampedOffset);
          _hasInitiallyScrolled = true;
        } else {
          _scrollController.jumpTo(targetOffset);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasInitiallyScrolled) {
              _initialJumpToCurrentLine();
            }
          });
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasInitiallyScrolled) {
            _initialJumpToCurrentLine();
          }
        });
      }
    }
  }

  void _checkAndScrollToActiveLine() {
    final int activeIndex = _calculateActiveIndex();
    if (activeIndex != _lastActiveIndex) {
      _lastActiveIndex = activeIndex;

      // Jika user sedang manual scroll dalam 2.5 detik terakhir, tunda auto-scroll
      final isRecentlyScrolled = DateTime.now().difference(_lastUserScrollTime).inMilliseconds < 2500;
      if (!_userIsScrolling && !isRecentlyScrolled && activeIndex >= 0 && activeIndex < widget.lyrics.length) {
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
    if (index < 0 || index >= widget.lyrics.length) return;
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _animateScroll(index);
        }
      });
      return;
    }
    final double targetOffset = index * _kLyricLineHeight;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final double clampedOffset = maxScroll > 0 ? targetOffset.clamp(0.0, maxScroll) : targetOffset;

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Menggunakan constraints.maxHeight aktual dari wadah lirik, BUKAN tinggi layar penuh HP
        final double containerHeight = constraints.maxHeight;
        final double topBottomPadding = ((containerHeight / 2) - (_kLyricLineHeight / 2)).clamp(16.0, 500.0);

        return NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            _userIsScrolling = notification.direction != ScrollDirection.idle;
            _lastUserScrollTime = DateTime.now();
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            itemExtent: _kLyricLineHeight,
            padding: EdgeInsets.symmetric(
              vertical: topBottomPadding,
              horizontal: 16,
            ),
            itemCount: widget.lyrics.length,
            itemBuilder: (context, index) {
              final line = widget.lyrics[index];
              final isActive = index == activeIndex;
              final isPast = index < activeIndex;

              return GestureDetector(
                onTap: () {
                  widget.onSeek(line.timestamp);
                  _lastActiveIndex = index;
                  _animateScroll(index);
                },
                child: Container(
                  height: _kLyricLineHeight,
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isActive ? 21 : 16,
                        fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
                        height: 1.35,
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
                ),
              );
            },
          ),
        );
      },
    );
  }
}
