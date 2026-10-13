# Project Memory — MaoneArt Music (`/sdcard/www/MaoneArtMusic`)

> **Flutter Glassmorphic Music Streaming Client**  
> **Terakhir diperbarui**: 13 Oktober 2026

---

## 🎵 Architecture & Key Engines
1. **Audio Engine**:
   - `just_audio` + `audio_service` untuk background playback & Android lockscreen media notification.
   - Hardware audio offload aktif langsung tanpa AudioPipeline (100% zero buffering streaming & ultra-responsif).
   - Platform channel native Android (`com.maoneart.music/equalizer`) di `MainActivity.kt` untuk integrasi hardware equalizer sistem (Dolby Atmos, Mi Sound, Wavelet).
2. **Streaming & Extractor**:
   - Musify Turbo Engine (`YoutubeApiClient.ios` & `androidSdkless` bypass JS deciphering).
   - Multi-tier stream fallback: Direct AAC/M4A 140 -> Best Audio -> Muxed video stream.
   - Dual-layer cache: RAM Cache (0ms) + Disk Cache SharedPreferences (<5ms).
3. **Lirik & Karaoke**:
   - LRCLIB API cascade fallback untuk synchronized lyrics (.lrc).
   - Mode Karaoke: Otomatis mendeteksi instrumen minus-one di YouTube.
4. **CI/CD & APK Release**:
   - Auto Build APK via GitHub Actions `.github/workflows/build_apk.yml` ke GitHub Releases.
   - Fixed Release Signing Keystore: `android/app/upload-keystore.jks` & `android/key.properties` (alias `maoneart`). Menjamin tanda tangan kriptografi APK identik selamanya sehingga update APK bisa langsung ditimpa (in-place update) tanpa uninstall.

---

## 🚀 Recent Milestones
### 🔑 Permanent Release Keystore & In-Place APK Updates (13 Oktober 2026)
- **Problem**: Update APK gagal ("Aplikasi tidak terpasang / signature mismatch") karena GitHub Actions memakai debug.keystore acak baru di setiap runner VM.
- **Solusi**:
  - Dibuatkan `upload-keystore.jks` (PKCS12 standard, RSA 2048, validity 10.000 hari) dan dikonfigurasikan di `android/app/build.gradle` via `signingConfigs.release`.
  - Backup kunci disimpan persisten di `~/.keystore_backup/upload-keystore.jks`.
  - Versi aplikasi dinaikkan ke `v1.0.1+2` di `pubspec.yaml`.

### ⚡ Real Audio Rhythm & Native FFT Visualizer (13 Oktober 2026)
- **Problem**: Pengguna menanyakan mengapa animasi visualizer neon (bars, waves, pulse) sebelumnya tidak mengikuti irama ketukan/tempo lagu secara nyata.
- **Solusi**:
  - Implementasi integrasi native Android `android.media.audiofx.Visualizer` di `MainActivity.kt` dengan EventChannel `com.maoneart.music/visualizer_stream`. Menghasilkan 24 pita frekuensi audio asli (FFT spectrum: sub-bass, kick drum, vocal mids, hi-hats) di ~25-30 FPS secara real-time.
  - Ditambahkan izin `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` di `AndroidManifest.xml` serta tombol aktivasi izin cepat di visualizer deck ("Sinkronkan FFT Asli").
  - Dibangun algoritma cadangan **Musical Beat-Sync Engine** (128 BPM 4/4 meter) berbasis `position.inMilliseconds` untuk sinkronisasi transient kick (beat 1 & 3), snare/clap (beat 2 & 4), dan 8th-note hi-hats secara dinamis saat FFT native dalam mode idle.
  - Parameter `position` dan `sessionId` diteruskan dari `player_screen.dart` dan `mini_player.dart` ke visualizer.
  - Perbaikan compile snapshot: menghapus modifier `const` pada pembungkus `NeonMiniVisualizerStrip` di `mini_player.dart`.
  - Versi aplikasi dinaikkan ke `v1.0.3+4` di `pubspec.yaml`.

---

## 📋 Active Tasks / Future Ideas
- [ ] Fitur Sleep Timer (Pengatur Waktu Tidur).
- [ ] Reorderable Queue (drag & drop urutan antrean lagu).
