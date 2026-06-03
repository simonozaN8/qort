#!/bin/bash
set -e

echo "=== QORT Vercel Build ==="

FLUTTER_VERSION="3.41.6"

if [ -d "flutter" ] && [ -f "flutter/bin/flutter" ]; then
  echo "✓ Flutter SDK rastas cache'e"
  cd flutter
  git fetch --tags
  git checkout $FLUTTER_VERSION
  cd ..
else
  echo "→ Flutter $FLUTTER_VERSION klonuojam..."
  rm -rf flutter
  git clone https://github.com/flutter/flutter.git --depth 1 -b $FLUTTER_VERSION
fi

export PATH="$PATH:$(pwd)/flutter/bin"

echo "=== Flutter versija ==="
flutter --version

# Sukurti .env failą iš Vercel Environment Variables
echo "=== Generating .env from Vercel env vars ==="
cat > .env << EOF
GEMINI_API_KEY=${GEMINI_API_KEY:-}
EOF

# Patikrinti ar GEMINI_API_KEY pateiktas (nesvarbu jei tuščias -
# AI super-admin feature neveiks, bet build'as sėkmingas)
if [ -z "$GEMINI_API_KEY" ]; then
  echo "⚠️  WARNING: GEMINI_API_KEY nepateiktas - AI generavimas neveiks"
else
  echo "✓ GEMINI_API_KEY pateiktas (${#GEMINI_API_KEY} simbolių)"
fi

flutter config --enable-web

echo "=== Pub get ==="
flutter pub get

echo "=== Build web release ==="
flutter build web --release

echo "=== Build complete! ==="
