#!/bin/bash
# Script pembantu untuk mem-build APK MaoneArt Music di dalam Termux Ubuntu PRoot

echo "================================================="
echo "  🎵 MaoneArt Music APK Builder (Termux Ubuntu)"
echo "================================================="

proot-distro login ubuntu -- bash -c "
export PATH=/opt/flutter/bin:/usr/lib/android-sdk/cmdline-tools/latest/bin:/usr/lib/android-sdk/platform-tools:\$PATH
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
export ANDROID_HOME=/usr/lib/android-sdk
export ANDROID_SDK_ROOT=/usr/lib/android-sdk

echo '--> Memperbarui workspace native ext4...'
rm -rf /root/MaoneArtMusic
cp -r /sdcard/www/MaoneArtMusic /root/MaoneArtMusic
cd /root/MaoneArtMusic

# Remove any duplicate .kts files
rm -f android/*.kts android/app/*.kts 2>/dev/null || true

if [ -f android/gradlew ]; then
    chmod +x android/gradlew
fi

echo '--> Mengonfigurasi Android SDK untuk Flutter...'
flutter config --android-sdk /usr/lib/android-sdk

echo '--> Mem-build APK Release ARM64...'
flutter build apk --release --target-platform android-arm64 --android-skip-build-dependency-validation

echo '--> Menyalin APK hasil ke SDCard dan folder Download...'
mkdir -p /sdcard/www/MaoneArtMusic/build/app/outputs/flutter-apk/
cp -r build/app/outputs/flutter-apk/* /sdcard/www/MaoneArtMusic/build/app/outputs/flutter-apk/ 2>/dev/null || true
cp build/app/outputs/flutter-apk/app-release.apk /sdcard/Download/MaoneArtMusic-release.apk 2>/dev/null || true
cp build/app/outputs/flutter-apk/app-release.apk /sdcard/Download/MaoneArtMusic.apk 2>/dev/null || true

echo '================================================='
echo '  ✅ BUILD SELESAI!'
echo '  File APK tersimpan di:'
echo '  - /sdcard/Download/MaoneArtMusic-release.apk'
echo '  - /sdcard/www/MaoneArtMusic/build/app/outputs/flutter-apk/app-release.apk'
echo '================================================='
"
