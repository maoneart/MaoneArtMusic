class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({
    required this.timestamp,
    required this.text,
  });

  /// Parse string lirik format .LRC menjadi daftar LyricLine
  /// Mendukung tag [offset:+/-ms] dan multi-timestamp agar lirik sinkron sempurna
  static List<LyricLine> parseLrc(String? rawLrc) {
    if (rawLrc == null || rawLrc.trim().isEmpty) return [];

    final List<LyricLine> lines = [];
    int offsetMs = 0;

    // 1. Ekstrak tag [offset: +/-ms] jika ada
    final offsetRegExp = RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false);
    for (final raw in rawLrc.split('\n')) {
      final line = raw.trim();
      final offsetMatch = offsetRegExp.firstMatch(line);
      if (offsetMatch != null) {
        offsetMs = int.tryParse(offsetMatch.group(1) ?? '0') ?? 0;
        break;
      }
    }

    final timeTagRegExp = RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\]');

    for (final raw in rawLrc.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('[offset:') || line.startsWith('[ti:') || line.startsWith('[ar:') || line.startsWith('[al:')) {
        continue;
      }

      final matches = timeTagRegExp.allMatches(line);
      if (matches.isNotEmpty) {
        // Bersihkan seluruh tag waktu dari teks
        final text = line.replaceAll(timeTagRegExp, '').trim();
        if (text.isNotEmpty) {
          for (final match in matches) {
            final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
            final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
            final msStr = match.group(3) ?? '0';
            int milliseconds = 0;
            if (msStr.length == 2) {
              milliseconds = (int.tryParse(msStr) ?? 0) * 10;
            } else if (msStr.length == 3) {
              milliseconds = int.tryParse(msStr) ?? 0;
            } else {
              milliseconds = int.tryParse(msStr) ?? 0;
            }

            final totalMs = (minutes * 60 * 1000) + (seconds * 1000) + milliseconds + offsetMs;
            final safeMs = totalMs < 0 ? 0 : totalMs;

            lines.add(LyricLine(
              timestamp: Duration(milliseconds: safeMs),
              text: text,
            ));
          }
        }
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }
}
