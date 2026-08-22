#!/bin/bash
# =======================================================
# 🚀 MaoneArt Music - Update Bug & Auto Push Script
# =======================================================

MSG="${1:-Update & Fix Bug MaoneArt Music}"

echo "================================================="
echo "  🎵 MaoneArt Music - Auto Push Script"
echo "================================================="
echo "--> Message Update: $MSG"
echo ""

# 1. Commit & Push ke GitHub
echo "--> 1/2 Menambahkan file & membuat commit..."
git add .
git commit -m "$MSG"

echo "--> 2/2 Pushing ke GitHub (main)..."
git push origin main

echo ""
echo "================================================="
echo "  ✅ PUSH KE GITHUB SELESAI!"
echo "  GitHub Actions akan otomatis mem-build APK di cloud."
echo "================================================="
