class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({
    required this.timestamp,
    required this.text,
  });

  /// Parse string lirik format .LRC menjadi daftar LyricLine
  /// Menghilangkan tag waktu [mm:ss.xx] agar pengguna melihat teks bersih tanpa melihat angka waktu
  static List<LyricLine> parseLrc(String? rawLrc) {
    if (rawLrc == null || rawLrc.trim().isEmpty) return [];

    final List<LyricLine> lines = [];
    final regExp = RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\](.*)');

    for (final raw in rawLrc.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final match = regExp.firstMatch(line);
      if (match != null) {
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

        final totalMs = (minutes * 60 * 1000) + (seconds * 1000) + milliseconds;
        final rawText = (match.group(4) ?? '').trim();
        final text = rawText.replaceAll(RegExp(r'\[\d+:\d+(?:[.:]\d+)?\]'), '').trim();

        if (text.isNotEmpty) {
          lines.add(LyricLine(
            timestamp: Duration(milliseconds: totalMs),
            text: text,
          ));
        }
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }
}
