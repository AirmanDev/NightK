#!/usr/bin/env bash
#
# NightK build / install / package helper.
#
#   scripts/release.sh build     Build a Release .app into build/ (ad-hoc signed)
#   scripts/release.sh install   Build, then install to /Applications and launch
#   scripts/release.sh dmg       Build, then produce a drag-to-install dist/NightK.dmg
#
# Ad-hoc signing is used so the project builds for anyone who clones it (no
# Apple team required). The produced app is NOT notarized -- see README.
#
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="NightK"
SCHEME="NightK"
BUILD_DIR="build/dd"
APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
DEST="/Applications/$APP_NAME.app"
DIST="dist"

build() {
    echo "==> Building $APP_NAME (Release, ad-hoc signed)"
    xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$SCHEME" -configuration Release \
        -derivedDataPath "$BUILD_DIR" \
        CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
        CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES \
        clean build >/dev/null
    echo "==> Built: $APP"
}

install_app() {
    build
    echo "==> Stopping any running instance"
    pkill -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    sleep 1
    echo "==> Installing to $DEST"
    rm -rf "$DEST"
    ditto "$APP" "$DEST"
    echo "==> Launching"
    open "$DEST"
    echo "==> Done: installed and launched from /Applications"
}

make_dmg() {
    build
    mkdir -p "$DIST"
    local stage
    stage="$(mktemp -d)"
    ditto "$APP" "$stage/$APP_NAME.app"
    ln -s /Applications "$stage/Applications"
    rm -f "$DIST/$APP_NAME.dmg"
    hdiutil create -volname "$APP_NAME" -srcfolder "$stage" -ov -format UDZO "$DIST/$APP_NAME.dmg" >/dev/null
    rm -rf "$stage"
    echo "==> Done: $DIST/$APP_NAME.dmg"
}

case "${1:-install}" in
    build)   build ;;
    install) install_app ;;
    dmg)     make_dmg ;;
    *) echo "usage: $0 [build|install|dmg]"; exit 1 ;;
esac
