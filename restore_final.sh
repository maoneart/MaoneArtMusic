#!/bin/bash
echo "🔄 Mengembalikan proyek MaoneArt Music ke Versi Final (v1.0.0-final)..."
cd /sdcard/www/MaoneArtMusic || exit 1
git fetch --all --tags
git reset --hard v1.0.0-final
git clean -fd
echo "✅ Berhasil dikembalikan ke Versi Final yang stabil!"
