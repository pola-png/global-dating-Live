#!/bin/bash
set -e

# Install Flutter
wget -O flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.3-stable.tar.xz
tar -xf flutter.tar.xz
export PATH="$PATH:$PWD/flutter/bin"

# Configure Flutter
flutter config --no-analytics
flutter doctor

# Build web
flutter pub get
flutter build web --release