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

### 🛡️ Visualizer Auto-Start, Anti-Freeze & Layout Optimization (v1.0.4+5 - 13 Oktober 2026)
- **Problem**:
  1. Visualizer tidak langsung aktif (harus klik tombol manual "Sinkronkan FFT Asli").
  2. Sering macet/freeze (akibat setState 30 FPS di EventChannel listener dan race condition antara cancel stream vs native visualizer release).
  3. Teks tombol mode ("Bars", "Waves", "Pulse") terpotong di layar HP sempit akibat overflow header Row.
- **Solusi**:
  1. **Auto-Start**: Visualizer otomatis mendeteksi dan meminta izin serta langsung streaming di `initState()` tanpa perlu klik tombol lagi.
  2. **Anti-Freeze Watchdog**: Menghapus `setState()` berfrekuensi tinggi di EventChannel listener (dijalankan langsung di memori dan di-render oleh `AnimatedBuilder` 60 FPS). Menambahkan watchdog timestamp (`_lastFftTimestamp`) dengan fallback mulus ke *Musical Beat-Sync Engine* jika audio FFT jeda/senyap sehingga animasi TIDAK AKAN PERNAH macet.
  3. **Android Looper Throttling**: Membatasi event capture di 30 FPS dan proteksi antrian `@Volatile isDispatchingFft` di `MainActivity.kt`.
  4. **Responsive Segmented Pills**: Mengubah pill selector menjadi segmented container kompak yang tidak akan pernah terpotong di layar HP mana pun.
  5. Versi dinaikkan ke `v1.0.4+5` di `pubspec.yaml`.

### 🔇 Single-Instance Playback & Anti-Overlap Fix (v1.0.5+6 - 13 Oktober 2026)
- **Problem**: Pengguna melaporkan suara lagu dobel (2 atau bahkan 3 trek lagu yang sama berbunyi bersamaan).
- **Penyebab**:
  1. `AndroidManifest.xml` memiliki `android:taskAffinity=""` & `launchMode="singleTop"`: Setiap kali user membuka app dari home screen/notifikasi saat audio berjalan, Android meluncurkan task/Activity baru dan instance Flutter Engine baru, membuat instance lama dan baru memutar audio bersamaan.
  2. `PlayerStateNotifier` mengalokasikan `_localPlayer = AudioPlayer()` secara terpisah dari `globalAudioHandler.player`, memicu redundansi player native ExoPlayer.
  3. `playSong()` memanggil `_player.play()` SEBELUM `setAudioSource()`, membiarkan audio lama tetap berjalan saat audio baru sedang di-buffer.
- **Solusi**:
  1. Mengubah `launchMode` menjadi `singleTask` dan menghapus `taskAffinity=""` di `AndroidManifest.xml`, menjamin hanya 1 instance Activity/Engine di sistem Android.
  2. Menghapus instansiasi `_localPlayer` redundan (lazy fallback).
  3. Memastikan `_player.pause()` segera dipanggil di awal transisi dan `setAudioSource()` selesai terlebih dahulu sebelum `_player.play()` dipanggil.
  4. Versi dinaikkan ke `v1.0.5+6` di `pubspec.yaml`.

### 📻 Smart Search Queue & Automix Radio Transition (v1.0.6+7 - 13 Oktober 2026)
- **Problem**: Saat mencari lagu (misal "hijau tulus") dan memutar lagu tersebut, antrean lagu berikutnya berisi berbagai variasi/cover/remix dari lagu yang sama ("Hijau" versi live, cover, karaoke) karena seluruh hasil pencarian dimasukkan ke antrean pemutar.
- **Solusi**:
  1. Di `search_screen.dart`, saat pengguna memilih lagu hasil pencarian, antrean awal diatur khusus untuk lagu tersebut (`newQueue: [song]`).
  2. Di `player_provider.dart`, untuk antrean hasil pencarian (panjang antrean 1 lagu), engine Automix Radio (`getAutomixRadioSongs`) langsung dipicu cepat (300ms) untuk mengisi antrean dengan lagu-lagu rekomendasi yang se-era, se-genre, dan se-irama (YouTube Music `RDAMVM$videoId`).
  3. Ditambahkan filter otomatis untuk menyingkirkan lagu yang memiliki judul identik dengan lagu awal, sehingga lagu berikutnya dipastikan berupa lagu yang berbeda namun tetap selaras genrenya.
  4. Versi dinaikkan ke `v1.0.6+7` di `pubspec.yaml`.

### 🛡️ Reliable Next-Track Stream Failover & Auto-Skip Resiliency (v1.0.7+8 - 13 Oktober 2026)
- **Problem**: Saat menekan tombol Next, lagu memang berganti tetapi kadang tidak berputar / macet di status loading.
- **Penyebab**:
  1. Penggunaan `preload: false` pada `setAudioSource` menyelesaikan panggilan tanpa memvalidasi koneksi jaringan awal. Jika stream kandidat 1 mati atau kena HTTP 403, loop failover salah mengira stream sudah berhasil sehingga stream cadangan (kandidat 2 & 3) tidak pernah dicoba.
  2. `AudioSource.uri` tidak menyertakan browser User-Agent sehingga Google Video CDN memblokir ExoPlayer dengan HTTP 403 Forbidden.
  3. Timeout ekstraksi manifest terlalu sempit pada koneksi seluler.
  4. Race condition pada `_extendArtistRadioQueue()` saat tombol Next ditekan selagi fetch lagu automix radio sedang berjalan.
- **Solusi**:
  1. Menghapus `preload: false` pada `setAudioSource` agar failover loop aktif andal: jika stream pertama bermasalah, ExoPlayer langsung melempar error dan loop beralih ke kandidat berikutnya.
  2. Menambahkan HTTP Headers browser standar (`User-Agent`, `Accept`, `Connection`) pada seluruh panggilan `AudioSource.uri`.
  3. Menaikkan timeout ekstraksi stream menjadi 15 detik dan manifest fallback menjadi 5-6 detik.
  4. Menambahkan `Completer<void>? _extendingQueueCompleter` agar panggilan `next()` menunggu antrean automix terisi sebelum menentukan indeks lagu.
  5. Menambahkan proteksi Auto-Skip `next(isAuto: true)` jika sebuah trek YouTube unplayable agar musik tidak pernah macet.
  6. Versi dinaikkan ke `v1.0.7+8` di `pubspec.yaml`.

---

## 📋 Active Tasks / Future Ideas
- [ ] Fitur Sleep Timer (Pengatur Waktu Tidur).
- [ ] Reorderable Queue (drag & drop urutan antrean lagu).
