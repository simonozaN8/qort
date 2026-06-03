#!/bin/bash
set -e

# Įdiegti Flutter SDK jei dar nėra
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Pridėti flutter prie PATH
export PATH="$PATH:$(pwd)/flutter/bin"

# Patikrinimai
flutter doctor -v
flutter config --enable-web

# Clean ir build
flutter clean
flutter pub get
flutter build web --release

echo "Build complete!"
