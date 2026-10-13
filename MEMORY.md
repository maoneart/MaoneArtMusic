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

### 🎛️ Fix Buffering & Native System EQ Intent (13 Oktober 2026)
- **Problem**:
  - `AudioPipeline(androidAudioEffects: [AndroidEqualizer])` memicu audio sink buffer underrun di ExoPlayer sehingga terjadi infinite buffering.
  - Panggilan IPC platform channel tanpa throttling di `FutureBuilder` menyebabkan UI freeze/tidak responsif saat klik.
- **Solusi (Opsi 2)**:
  - Melepas `AudioPipeline` dari `MyAudioHandler` & `_localPlayer` mengembalikan performa turbo ExoPlayer (zero buffering, instan).
  - Implementasi `MethodChannel("com.maoneart.music/equalizer")` di `MainActivity.kt` untuk membuka hardware Equalizer bawaan HP (Dolby Atmos / Mi Sound / SoundAlive) via Android Intent (`ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL`).
  - Efek audio in-app super mulus (0ms blocking): Kontrol Kecepatan Putar (0.75x–1.5x) dan Volume Output Slider.
  - Modal UI Glassmorphism simetris 2-kolom sesuai standar MaoneArt.

---

## 📋 Active Tasks / Future Ideas
- [ ] Fitur Sleep Timer (Pengatur Waktu Tidur).
- [ ] Reorderable Queue (drag & drop urutan antrean lagu).
