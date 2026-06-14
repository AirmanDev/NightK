<div align="center">

<img src="NightK/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="NightK icon">

# NightK

**A tiny macOS menu-bar app that warms your display on a fixed schedule.**

</div>

NightK lives in the menu bar and gently shifts your screen toward warmer
(more orange) colors during the hours you choose, easy on the eyes at night.
It adjusts the display color temperature using the CoreGraphics gamma API and
restores the normal profile outside the scheduled window.

## Features

- Warm the display between a configurable **start** and **end** time
  (overnight windows such as 20:00 - 07:00 are supported).
- Optional **gradual transition** that eases the warming in during the hour
  before the start time and back out over the last, instead of snapping on/off.
- Adjustable color **temperature** from 1000 K to 6500 K.
- Works across **multiple displays** and re-applies on wake / display changes.
- **English / Hungarian** UI.
- Sandboxed menu-bar agent: no Dock icon, minimal CPU/RAM.

## Requirements

- macOS **26.5** or later (current deployment target).
- Xcode 26.5+ to build from source.

> The minimum macOS version is set by `MACOSX_DEPLOYMENT_TARGET` in the Xcode
> project. It can be lowered for wider compatibility; note that the full-bleed
> app icon relies on the automatic squircle masking introduced in macOS 26.

## Install

### From a release DMG

1. Download `NightK.dmg` from the [Releases](../../releases) page.
2. Open it and drag **NightK** into **Applications**.
3. First launch: the app is **not notarized** (open-source, ad-hoc signed), so
   macOS Gatekeeper will warn you. Right-click the app and choose **Open**, or run:

   ```sh
   xattr -dr com.apple.quarantine /Applications/NightK.app
   ```

### From source

```sh
git clone <repo-url>
cd NightK
scripts/release.sh install   # builds Release, installs to /Applications, launches
```

## Building & packaging

The helper script does everything (ad-hoc signing, so no Apple team is needed):

```sh
scripts/release.sh build     # build a Release .app into build/
scripts/release.sh install   # build + install to /Applications + launch
scripts/release.sh dmg       # build + produce dist/NightK.dmg
```

You can also open `NightK.xcodeproj` in Xcode and build normally. The project
uses automatic signing with the author's team; to build in Xcode under your own
account, set your Team in **Signing & Capabilities**, or use the script above.

## License

[MIT](LICENSE) (c) 2026 AirmanDev
