#!/bin/bash
set -e

echo "=== QORT Vercel Build ==="

# Patikrinti ar Flutter SDK jau yra (iš ankstesnio build cache)
if [ -d "flutter" ] && [ -f "flutter/bin/flutter" ]; then
  echo "✓ Flutter SDK rastas cache'e, atnaujinam..."
  cd flutter
  git pull origin stable || echo "Pull klaida - tęsiam su esama versija"
  cd ..
else
  echo "→ Flutter SDK klonuojam (pirmas build'as)..."
  rm -rf flutter
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Pridėti flutter prie PATH
export PATH="$PATH:$(pwd)/flutter/bin"

# Diagnostika
echo "=== Flutter versija ==="
flutter --version

# Konfigūracija
flutter config --enable-web

# Dependencies
echo "=== Pub get ==="
flutter pub get

# Build
echo "=== Build web release ==="
flutter build web --release

echo "=== Build complete! ==="
