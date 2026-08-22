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

## ⚡ CATATAN UPDATE & BUILD APK OTOMATIS (Cukup 1 Perintah)

**Anda TIDAK Perlu Lagi Membuat Perintah Build Manual di GitHub Web!**

Cukup buka terminal di Termux, masuk ke folder proyek, dan jalankan perintah:

```bash
cd /sdcard/www/MaoneArtMusic
./update_app.sh "pesan update bug anda"
```

### **Apa yang Dilakukan Perintah Tersebut secara Otomatis?**
1. **Push ke GitHub**: Otomatis menyimpan commit & push ke repository `https://github.com/maoneart/MaoneArtMusic`.
2. **GitHub Actions Auto-Build**: GitHub akan **otomatis mem-build APK secara cloud** setiap kali ada `push` di branch `main` tanpa perlu mengeklik apa-apa. Hasil APK otomatis tersedia di menu **Releases** & **Actions** di GitHub.
3. **Save ke Folder Download**: Script ini juga langsung mem-build & menyimpan file APK ke folder HP Anda di `/sdcard/Download/MaoneArtMusic.apk`.

---

## 📄 Lisensi
Dibuat untuk **MaoneArt** • Bebas dikembangkan & dimodifikasi.
