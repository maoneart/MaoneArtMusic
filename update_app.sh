#!/bin/bash
# =======================================================
# 🚀 MaoneArt Music - Update Bug & Auto-Build APK Script
# =======================================================

MSG="${1:-Update & Fix Bug MaoneArt Music}"

echo "================================================="
echo "  🎵 MaoneArt Music - Auto Update & Build Script"
echo "================================================="
echo "--> Message Update: $MSG"
echo ""

# 1. Commit & Push ke GitHub
echo "--> 1/3 Menambahkan file & membuat commit..."
git add .
git commit -m "$MSG"

echo "--> 2/3 Pushing ke GitHub (main)..."
git push origin main

echo "--> Push ke GitHub selesai! GitHub Actions akan otomatis mem-build APK di cloud."
echo ""

# 2. Build APK Lokal di Termux & simpan ke Download
echo "--> 3/3 Mem-build APK lokal & menyimpan ke /sdcard/Download..."
if [ -f "./build_apk_termux.sh" ]; then
    bash ./build_apk_termux.sh
else
    echo "⚠️ File build_apk_termux.sh tidak ditemukan!"
fi

echo "================================================="
echo "  ✅ SELESAI!"
echo "  APK Terbaru sudah tersimpan di /sdcard/Download/MaoneArtMusic.apk"
echo "================================================="
