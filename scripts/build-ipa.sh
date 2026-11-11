#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

xcodebuild \
  -project Berean.xcodeproj \
  -scheme Berean \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build

rm -rf build/Payload build/Berean.ipa
mkdir -p build/Payload
cp -R build/Build/Products/Release-iphoneos/Berean.app build/Payload/
(cd build && zip -qr Berean.ipa Payload)

find build/Payload -name 'bible-*.json' | wc -l
echo "build/Berean.ipa"
