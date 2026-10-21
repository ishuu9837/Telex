#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/clang-cache"
mkdir -p .build/clang-cache .build/spm-cache .build/spm-config .build/spm-security dist
SPM_ARGS=(--disable-sandbox --cache-path .build/spm-cache --config-path .build/spm-config --security-path .build/spm-security)
if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
    swift test "${SPM_ARGS[@]}"
fi
swift build "${SPM_ARGS[@]}" -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build "${SPM_ARGS[@]}" -c release --arch arm64 --arch x86_64 --show-bin-path)"
APP="$PWD/dist/Telex.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Telex" "$APP/Contents/MacOS/Telex"
cp Config/Info.plist "$APP/Contents/Info.plist"
cp LICENSE "$APP/Contents/Resources/LICENSE"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
for RESOURCE_BUNDLE in "$BIN_DIR"/*.bundle; do
    if [[ -d "$RESOURCE_BUNDLE" ]]; then
        cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
    fi
done
IDENTITY="${SIGNING_IDENTITY:--}"
if [[ "$IDENTITY" == "-" ]]; then
    codesign --force --sign - --entitlements Config/Telex.entitlements "$APP"
else
    codesign --force --options runtime --timestamp --sign "$IDENTITY" --entitlements Config/Telex.entitlements "$APP"
fi
codesign --verify --deep --strict "$APP"
lipo "$APP/Contents/MacOS/Telex" -verify_arch arm64
lipo "$APP/Contents/MacOS/Telex" -verify_arch x86_64
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    if [[ "$IDENTITY" == "-" ]]; then
        echo "NOTARY_PROFILE requires a Developer ID SIGNING_IDENTITY." >&2
        exit 1
    fi
    ditto -c -k --keepParent "$APP" dist/Telex-notarization.zip
    xcrun notarytool submit dist/Telex-notarization.zip --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
fi
STAGING="$(mktemp -d "$PWD/dist/dmg-stage.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/Telex.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname Telex -srcfolder "$STAGING" -ov -format UDZO dist/Telex.dmg
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    codesign --force --timestamp --sign "$IDENTITY" dist/Telex.dmg
    xcrun notarytool submit dist/Telex.dmg --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple dist/Telex.dmg
fi
echo "Built: $APP"
echo "Disk image: $PWD/dist/Telex.dmg"
