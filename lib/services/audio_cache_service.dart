import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import 'youtube_audio_extractor.dart';

class CacheRecord {
  final String songId;
  final String localPath;
  final int fileSizeBytes;
  final DateTime lastAccessed;
  final bool isPinned; // true = Manual Download, false = Auto-Cache
  final Map<String, dynamic> songMap;

  CacheRecord({
    required this.songId,
    required this.localPath,
    required this.fileSizeBytes,
    required this.lastAccessed,
    required this.isPinned,
    required this.songMap,
  });

  Map<String, dynamic> toMap() => {
        'songId': songId,
        'localPath': localPath,
        'fileSizeBytes': fileSizeBytes,
        'lastAccessed': lastAccessed.toIso8601String(),
        'isPinned': isPinned,
        'songMap': songMap,
      };

  factory CacheRecord.fromMap(Map<String, dynamic> map) => CacheRecord(
        songId: map['songId'] ?? '',
        localPath: map['localPath'] ?? '',
        fileSizeBytes: (map['fileSizeBytes'] ?? 0) is num ? (map['fileSizeBytes'] as num).toInt() : 0,
        lastAccessed: DateTime.tryParse(map['lastAccessed'] ?? '') ?? DateTime.now(),
        isPinned: map['isPinned'] == true,
        songMap: Map<String, dynamic>.from(map['songMap'] ?? {}),
      );
}

class AudioCacheService {
  static final AudioCacheService instance = AudioCacheService._();
  AudioCacheService._();

  static const String _recordsKey = 'maoneart_audio_cache_records_v1';
  static const int defaultMaxCacheBytes = 500 * 1024 * 1024; // 500 MB

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    },
  ));

  Directory? _cacheDir;

  Future<Directory> _getCacheDirectory() async {
    if (_cacheDir != null) return _cacheDir!;
    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocDir.path}/maoneart_audio_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  Future<List<CacheRecord>> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_recordsKey);
    if (data == null || data.isEmpty) return [];
    try {
      final List list = json.decode(data);
      return list.map((item) => CacheRecord.fromMap(item)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveRecords(List<CacheRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = json.encode(records.map((r) => r.toMap()).toList());
    await prefs.setString(_recordsKey, data);
  }

  /// Cek apakah file audio lokal untuk lagu ini ada di memori HP
  Future<String?> getLocalAudioPath(Song song) async {
    final records = await _loadRecords();
    final idx = records.indexWhere((r) => r.songId == song.id || (song.youtubeId != null && r.songId == 'yt_${song.youtubeId}'));
    if (idx == -1) return null;

    final record = records[idx];
    final file = File(record.localPath);
    if (await file.exists() && await file.length() > 1024) {
      // Update last accessed time for LRU tracking
      records[idx] = CacheRecord(
        songId: record.songId,
        localPath: record.localPath,
        fileSizeBytes: record.fileSizeBytes,
        lastAccessed: DateTime.now(),
        isPinned: record.isPinned,
        songMap: record.songMap,
      );
      await _saveRecords(records);
      return record.localPath;
    } else {
      // File has been removed from disk, purge record
      records.removeAt(idx);
      await _saveRecords(records);
      return null;
    }
  }

  /// Cek status apakah lagu sudah tersimpan offline
  Future<bool> isSongOffline(Song song) async {
    final path = await getLocalAudioPath(song);
    return path != null;
  }

  /// Download dan simpan lagu ke memori lokal HP (Manual Download atau Auto-Cache)
  Future<String?> downloadAndSaveSong(
    Song song, {
    bool isPinned = false,
    Function(double progress)? onProgress,
  }) async {
    try {
      final existingPath = await getLocalAudioPath(song);
      if (existingPath != null) {
        if (isPinned) {
          // Upgrade to pinned
          final records = await _loadRecords();
          final idx = records.indexWhere((r) => r.songId == song.id);
          if (idx != -1) {
            records[idx] = CacheRecord(
              songId: records[idx].songId,
              localPath: records[idx].localPath,
              fileSizeBytes: records[idx].fileSizeBytes,
              lastAccessed: DateTime.now(),
              isPinned: true,
              songMap: song.toMap(),
            );
            await _saveRecords(records);
          }
        }
        return existingPath;
      }

      // Ambil candidate stream URLs
      final urls = await YoutubeAudioExtractor.getAudioStreamCandidateUrls(song);
      if (urls.isEmpty) return null;

      final dir = await _getCacheDirectory();
      final cleanId = song.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final targetFile = File('${dir.path}/$cleanId.m4a');
      final tempFile = File('${dir.path}/$cleanId.tmp');

      bool downloadSuccess = false;
      for (final streamUrl in urls) {
        try {
          if (await tempFile.exists()) await tempFile.delete();

          await _dio.download(
            streamUrl,
            tempFile.path,
            onReceiveProgress: (received, total) {
              if (total > 0 && onProgress != null) {
                onProgress(received / total);
              }
            },
          );

          if (await tempFile.exists() && await tempFile.length() > 50000) {
            if (await targetFile.exists()) await targetFile.delete();
            await tempFile.rename(targetFile.path);
            downloadSuccess = true;
            break;
          }
        } catch (e) {
          print("Download attempt notice: $e");
          continue;
        }
      }

      if (!downloadSuccess || !await targetFile.exists()) {
        if (await tempFile.exists()) await tempFile.delete();
        return null;
      }

      final fileSize = await targetFile.length();
      final records = await _loadRecords();
      records.removeWhere((r) => r.songId == song.id);
      records.add(CacheRecord(
        songId: song.id,
        localPath: targetFile.path,
        fileSizeBytes: fileSize,
        lastAccessed: DateTime.now(),
        isPinned: isPinned,
        songMap: song.toMap(),
      ));
      await _saveRecords(records);

      // Jalankan LRU Cache Rotation jika bukan pinned
      if (!isPinned) {
        enforceCacheLimit(maxBytes: defaultMaxCacheBytes);
      }

      return targetFile.path;
    } catch (e) {
      print("Download and save song error: $e");
      return null;
    }
  }

  /// Auto-cache audio stream yang sedang diputar di latar belakang
  void autoCacheStreamInBackground(Song song, String streamUrl) {
    Future.microtask(() async {
      try {
        final existing = await getLocalAudioPath(song);
        if (existing != null) return;

        final dir = await _getCacheDirectory();
        final cleanId = song.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final targetFile = File('${dir.path}/$cleanId.m4a');
        final tempFile = File('${dir.path}/$cleanId.tmp');

        if (await tempFile.exists()) await tempFile.delete();

        await _dio.download(streamUrl, tempFile.path);

        if (await tempFile.exists() && await tempFile.length() > 50000) {
          if (await targetFile.exists()) await targetFile.delete();
          await tempFile.rename(targetFile.path);

          final fileSize = await targetFile.length();
          final records = await _loadRecords();
          records.removeWhere((r) => r.songId == song.id);
          records.add(CacheRecord(
            songId: song.id,
            localPath: targetFile.path,
            fileSizeBytes: fileSize,
            lastAccessed: DateTime.now(),
            isPinned: false, // Auto-cache (bisa di-evict jika penuh)
            songMap: song.toMap(),
          ));
          await _saveRecords(records);

          await enforceCacheLimit(maxBytes: defaultMaxCacheBytes);
        }
      } catch (_) {}
    });
  }

  /// LRU Cache Eviction: Menghapus lagu auto-cache paling usang jika melebihi kuota 500 MB
  Future<void> enforceCacheLimit({int maxBytes = defaultMaxCacheBytes}) async {
    try {
      final records = await _loadRecords();
      final unpinnedRecords = records.where((r) => !r.isPinned).toList();

      int totalUnpinnedSize = unpinnedRecords.fold(0, (sum, r) => sum + r.fileSizeBytes);

      if (totalUnpinnedSize <= maxBytes) return;

      // Urutkan dari yang paling lama tidak diputar (lastAccessed paling awal)
      unpinnedRecords.sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));

      final targetSize = (maxBytes * 0.85).toInt(); // Bersihkan sampai sisa 85% untuk ruang kosong
      final List<String> toRemoveIds = [];

      for (final rec in unpinnedRecords) {
        if (totalUnpinnedSize <= targetSize) break;
        try {
          final file = File(rec.localPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
        totalUnpinnedSize -= rec.fileSizeBytes;
        toRemoveIds.add(rec.songId);
      }

      records.removeWhere((r) => toRemoveIds.contains(r.songId));
      await _saveRecords(records);
    } catch (e) {
      print("Enforce cache limit notice: $e");
    }
  }

  /// Mengambil semua daftar lagu offline yang tersimpan di HP
  Future<List<Song>> getOfflineSongs() async {
    final records = await _loadRecords();
    final List<Song> songs = [];
    final List<CacheRecord> validRecords = [];

    for (final rec in records) {
      final file = File(rec.localPath);
      if (await file.exists() && await file.length() > 1024) {
        songs.add(Song.fromMap(rec.songMap));
        validRecords.add(rec);
      }
    }

    if (validRecords.length != records.length) {
      await _saveRecords(validRecords);
    }

    return songs;
  }

  /// Hapus lagu offline tertentu dari memori
  Future<void> deleteOfflineSong(Song song) async {
    final records = await _loadRecords();
    final idx = records.indexWhere((r) => r.songId == song.id || (song.youtubeId != null && r.songId == 'yt_${song.youtubeId}'));
    if (idx != -1) {
      final rec = records[idx];
      try {
        final file = File(rec.localPath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      records.removeAt(idx);
      await _saveRecords(records);
    }
  }

  /// Menghitung total ukuran cache audio di memori HP dalam satuan byte
  Future<int> getTotalCacheSizeBytes() async {
    final records = await _loadRecords();
    int total = 0;
    for (final r in records) {
      total += r.fileSizeBytes;
    }
    return total;
  }

  /// Bersihkan hanya temporary auto-cache (lagu download manual tetap aman)
  Future<void> clearAutoCacheOnly() async {
    final records = await _loadRecords();
    final List<CacheRecord> retained = [];

    for (final r in records) {
      if (!r.isPinned) {
        try {
          final file = File(r.localPath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      } else {
        retained.add(r);
      }
    }

    await _saveRecords(retained);
  }

  /// Bersihkan seluruh offline songs & cache
  Future<void> clearAllCache() async {
    final records = await _loadRecords();
    for (final r in records) {
      try {
        final file = File(r.localPath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    await _saveRecords([]);
  }
}
