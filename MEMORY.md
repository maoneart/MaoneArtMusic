# Project Memory — MaoneArt Music (`/sdcard/www/MaoneArtMusic`)

> **Flutter Glassmorphic Music Streaming Client**  
> **Terakhir diperbarui**: 13 Oktober 2026

---

## 🎵 Architecture & Key Engines
1. **Audio Engine**:
   - `just_audio` + `audio_service` untuk background audio playback & Android lockscreen media notifications.
   - `AudioPipeline(androidAudioEffects: [AndroidEqualizer])` terpasang di `MyAudioHandler` & `PlayerStateNotifier`.
2. **Streaming & Extractor**:
   - Musify Turbo Engine (`YoutubeApiClient.ios` & `androidSdkless` bypass JS deciphering).
   - Multi-tier stream fallback: Direct AAC/M4A 140 -> Best Audio -> Muxed video stream.
   - Dual-layer cache: RAM Cache (0ms) + Disk Cache SharedPreferences (<5ms).
3. **Lirik & Karaoke**:
   - LRCLIB API cascade fallback untuk synchronized lyrics (.lrc).
   - Mode Karaoke: Otomatis mendeteksi instrumen minus-one di YouTube.
4. **CI/CD & APK Release**:
   - Auto Build APK via GitHub Actions `.github/workflows/build_apk.yml` ke GitHub Releases.

---

## 🚀 Recent Milestones
### 🎛️ Equalizer 5-Band, Audio Presets & Playback Speed (13 Oktober 2026)
- **Implementasi**:
  - `AndroidEqualizer` terhubung langsung ke audio pipeline native.
  - 7 preset suara: `Normal`, `Bass Boost`, `Vokal & Akustik`, `Rock`, `Pop`, `Treble Boost`, `Electronic`, plus `Custom`.
  - Kontrol kecepatan putar audio (`0.75x`, `1.0x`, `1.25x`, `1.5x`).
  - Modal UI Glassmorphism: `lib/widgets/equalizer_modal.dart` (simetris, slider frekuensi visual, real-time dB feedback).
  - Shortcut akses:
    - Tombol `tune_rounded` di AppBar `PlayerScreen`.
    - Tile `Equalizer & Efek Suara` di `SettingsScreen`.
  - Persistensi setting tersimpan otomatis di `SharedPreferences`.

---

## 📋 Active Tasks / Future Ideas
- [ ] Fitur Sleep Timer (Pengatur Waktu Tidur).
- [ ] Reorderable Queue (drag & drop urutan antrean lagu).
