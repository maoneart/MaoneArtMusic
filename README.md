# 🎵 MaoneArt Music (Spotube Clone Flutter App)

Aplikasi streaming musik open-source berbasis **Flutter** dengan tampilan **MaoneArt Glassmorphic UI**, integrasi pencarian lagu Spotify/iTunes, serta pemutar audio streaming berkualitas tinggi dari YouTube Music tanpa iklan.

---

## 🌟 Fitur Utama
1. **Pencarian Musik Real-time**: Cari judul lagu, artis, atau album dari jutaan katalog musik.
2. **Audio Streaming dari YouTube**: Mengambil stream audio berkualitas tinggi tanpa perlu Spotify Premium / Kunci API berbayar.
3. **Pemutar Audio Latar Belakang (Background Playback)**: Tetap memutar lagu saat layar mati / berpindah aplikasi lewat `just_audio` & `audio_service`.
4. **Desain MaoneArt Glassmorphism**: Tampilan dark frosted glass futuristik dengan efek neon cyan & electric purple.
5. **MaoneArt Custom Modal**: Dialog konfirmasi & alert kustom simetris (2 kolom) tanpa dialog bawaan browser/native.
6. **Koleksi & Playlist**: Simpan lagu favorit dan kelola playlist kustom secara offline (disimpan di `shared_preferences`).

---

## 📂 Struktur Proyek
```text
/sdcard/www/MaoneArtMusic/
├── .github/workflows/
│   └── build_apk.yml        # Build otomatis APK via GitHub Actions
├── android/                 # Konfigurasi Android App & Manifest
├── lib/
│   ├── main.dart            # Entrypoint utama & Navigasi Kaca
│   ├── models/              # Model data (Song & Playlist)
│   ├── services/            # Service iTunes API, YouTube Stream Extractor, Storage
│   ├── providers/           # State management Riverpod (Player, Music, Library)
│   ├── theme/               # Palet warna & tema MaoneArt Glassmorphism
│   ├── views/               # Halaman UI (Home, Search, Library, Player, Settings)
│   └── widgets/             # Widget Kaca, Mini Player, Seek Bar, Custom Modal
└── pubspec.yaml             # Dependensi Flutter (just_audio, youtube_explode_dart, dll)
```

---

## 🚀 Cara Build ke APK Android

### **Cara 1: Otomatis via GitHub Actions (Rekomendasi Utama & Paling Mudah)**
Proyek ini sudah dilengkapi dengan `.github/workflows/build_apk.yml`.
1. Upload/Push folder `/sdcard/www/MaoneArtMusic` ke repositori GitHub Anda.
2. GitHub secara otomatis akan memproses build APK saat push selesai.
3. Buka tab **Actions** di GitHub -> Pilih workflow -> Download file **MaoneArtMusic-APKs.zip** yang berisi file `.apk` siap install di Android!

---

### **Cara 2: Build Manual di Laptop / PC (Flutter CLI)**
Jika Anda memiliki laptop/PC dengan Flutter SDK & Android Studio terinstall:
1. Salin folder `MaoneArtMusic` ke PC.
2. Buka terminal di folder proyek, lalu jalankan:
   ```bash
   flutter pub get
   flutter build apk --release
   ```
3. File APK akan terbentuk di:
   `build/app/outputs/flutter-apk/app-release.apk`

---

### **Cara 3: Build Langsung di Android (Termux PRoot Ubuntu)**
Jika ingin build APK di dalam Termux Android:
1. Install PRoot Ubuntu di Termux: `pkg install proot-distro && proot-distro install ubuntu`
2. Masuk ke Ubuntu: `proot-distro login ubuntu`
3. Install OpenJDK 17 & Flutter SDK di Ubuntu.
4. Jalankan `flutter build apk --release`.

---

## 📄 Lisensi
Dibuat untuk **MaoneArt** • Bebas dikembangkan & dimodifikasi.
