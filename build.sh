#!/bin/bash
set -e

# Install Flutter 3.27.1 (latest stable with Dart 3.6+)
wget -O flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.1-stable.tar.xz
tar -xf flutter.tar.xz
export PATH="$PATH:$PWD/flutter/bin"

# Configure Flutter
flutter config --no-analytics
flutter config --enable-web

# Backup original pubspec and use web version
cp pubspec.yaml pubspec_original.yaml
cp pubspec_web.yaml pubspec.yaml
flutter pub get
flutter build web --release --web-renderer html
# Restore original pubspec
cp pubspec_original.yaml pubspec.yaml