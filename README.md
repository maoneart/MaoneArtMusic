# 🎵 MaoneArt Music (Glassmorphic Music Streaming App)

[![GitHub Release](https://img.shields.io/github/v/release/maoneart/MaoneArtMusic?color=00F0FF&label=Latest%20Release&logo=github)](https://github.com/maoneart/MaoneArtMusic/releases/latest)
[![Download APK](https://img.shields.io/badge/Download-APK%20(v1.0.1)-1ED760?logo=android&logoColor=white)](https://github.com/maoneart/MaoneArtMusic/releases/latest)
[![Build Status](https://img.shields.io/github/actions/workflow/status/maoneart/MaoneArtMusic/build_apk.yml?branch=main&label=Build%20APK&logo=github-actions)](https://github.com/maoneart/MaoneArtMusic/actions)

Aplikasi streaming musik open-source berbasis **Flutter** dengan tampilan **MaoneArt Glassmorphic UI**, integrasi katalog YouTube Music tanpa iklan, audio streaming turbo instan tanpa buffering, serta hardware equalizer HP bawaan.

---

> 🚀 **Pembaruan Terbaru: v1.0.1 Telah Tersedia di GitHub Releases!**  
> 📥 **[Download MaoneArtMusic.apk (v1.0.1)](https://github.com/maoneart/MaoneArtMusic/releases/latest)**  
> 
> **Fitur Baru di v1.0.1**:
> - 🎛️ **Hardware Equalizer HP**: Buka panel Dolby Atmos, Mi Sound, atau Dirac langsung dari pemutar musik via Android Intent.
> - ⚡ **Kecepatan Putar (Playback Speed)**: Ubah tempo lagu (0.75x, 1.0x, 1.25x, 1.5x) secara instan tanpa lag.
> - 🔊 **Volume Normalizer & Tuning Slider**: Penyesuaian volume presisi langsung di dialog efek.
> - 🔑 **Permanent Release Keystore**: Tanda tangan digital permanen sehingga update APK berikutnya bisa langsung ditimpa (update in-place) tanpa perlu uninstall lagi!
> - 🚀 **Zero-Buffering Playback**: Streaming YouTube super lancar dengan hardware audio offload penuh.

---

## 🌟 Fitur Utama
1. **Musify YouTube Audio Engine**: Audio extraction super cepat, direct YouTube Music streams tanpa preview 30 detik.
2. **Zero-Buffering Playback**: Pemutaran audio instan tanpa jeda buffering via hardware offload.
3. **Equalizer Sistem HP (Dolby / Mi Sound)**: Tombol langsung untuk meluncurkan hardware equalizer perangkat Anda.
4. **Kecepatan & Volume Tuning**: Sesuaikan tempo playback dan output gain pemutar sesuka hati.
5. **Pemutar Latar Belakang (Background Playback)**: Tetap memutar lagu saat layar mati / berpindah aplikasi lewat `audio_service` dengan lockscreen notification.
6. **Lirik Tersinkronisasi & Mode Karaoke**: Sinkronisasi lirik LRCLIB realtime serta mode minus-one instrumen.
7. **Desain MaoneArt Glassmorphism**: Tampilan dark frosted glass futuristik dengan aksen neon cyan & electric purple.
8. **MaoneArt Custom Modal**: Dialog konfirmasi & alert kustom simetris (grid 2 kolom) tanpa browser confirm/native dialog.
9. **Koleksi & Playlist Offline**: Simpan lagu favorit dan kelola playlist kustom secara lokal.

---

## 📂 Struktur Proyek
```text
/sdcard/www/MaoneArtMusic/
├── .github/workflows/
│   └── build_apk.yml        # Build otomatis APK & GitHub Release v1.0.1
├── android/                 # Konfigurasi Android App, Manifest & Keystore
│   ├── app/upload-keystore.jks # Kunci rilis permanen
│   └── key.properties       # Konfigurasi signing rilis
├── lib/
│   ├── main.dart            # Entrypoint utama & Navigasi Kaca
│   ├── models/              # Model data (Song, Album, LyricLine)
│   ├── services/            # Audio Handler, YouTube Extractor, Storage
│   ├── providers/           # Riverpod state management (Player, Music, Library)
│   ├── theme/               # Palet warna & tema MaoneArt Glassmorphism
│   ├── views/               # UI screens (Home, Search, Library, Player, Settings)
│   └── widgets/             # Equalizer Modal, Synced Lyrics, Glass Widgets
└── pubspec.yaml             # Versi v1.0.1+2 & dependensi
```

---

## 📄 Lisensi
Dibuat untuk **MaoneArt** • Bebas dikembangkan & dimodifikasi.
