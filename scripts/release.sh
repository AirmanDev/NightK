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
    echo "==> Verifying signed release before changing the installed copy"
    codesign --verify --deep --strict "$APP"
    local stage old
    stage="$(mktemp -d /Applications/.NightK-install.XXXXXXXX)"
    old="$stage/original.app"
    ditto "$APP" "$stage/$APP_NAME.app"
    codesign --verify --deep --strict "$stage/$APP_NAME.app"

    echo "==> Switching installed app (automatic rollback on failed launch)"
    pkill -f "^$DEST/Contents/MacOS/$APP_NAME$" 2>/dev/null || true
    sleep 1
    if [[ -d "$DEST" ]]; then
        mv "$DEST" "$old"
    fi
    if ! mv "$stage/$APP_NAME.app" "$DEST"; then
        [[ ! -d "$old" ]] || mv "$old" "$DEST"
        rm -rf "$stage"
        return 1
    fi
    if ! open "$DEST"; then
        rm -rf "$DEST"
        [[ ! -d "$old" ]] || { mv "$old" "$DEST"; open "$DEST" || true; }
        rm -rf "$stage"
        return 1
    fi
    sleep 3
    if ! pgrep -f "^$DEST/Contents/MacOS/$APP_NAME$" >/dev/null; then
        echo "NightK failed to launch; restoring previous app" >&2
        rm -rf "$DEST"
        [[ ! -d "$old" ]] || { mv "$old" "$DEST"; open "$DEST" || true; }
        rm -rf "$stage"
        return 1
    fi
    rm -rf "$stage"
    echo "==> Done: installed and running from /Applications"
}

make_dmg() {
    build
    mkdir -p "$DIST"
    local stage candidate
    stage="$(mktemp -d)"
    candidate="$DIST/.NightK-release-$$.dmg"
    ditto "$APP" "$stage/$APP_NAME.app"
    ln -s /Applications "$stage/Applications"
    if ! hdiutil create -volname "$APP_NAME" -srcfolder "$stage" -ov -format UDZO "$candidate" >/dev/null; then
        rm -rf "$stage" "$candidate"
        return 1
    fi
    if ! hdiutil imageinfo "$candidate" >/dev/null; then
        rm -rf "$stage" "$candidate"
        return 1
    fi
    mv -f "$candidate" "$DIST/$APP_NAME.dmg"
    rm -rf "$stage"
    echo "==> Verified and atomically replaced: $DIST/$APP_NAME.dmg"
}

case "${1:-install}" in
    build)   build ;;
    install) install_app ;;
    dmg)     make_dmg ;;
    *) echo "usage: $0 [build|install|dmg]"; exit 1 ;;
esac
