<div align="center">

<img src="NightK/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="NightK icon">

# NightK

**A tiny macOS menu-bar app that warms your display on a fixed schedule.**

</div>

NightK lives in the menu bar and gently shifts your screen toward warmer
(more orange) colors during the hours you choose, easy on the eyes at night.
Normally it adjusts display colour using the CoreGraphics gamma API. On macOS
27.2 with the M5 Pro Mac17,8, the OS can accept gamma changes without applying
them to the panel; NightK automatically switches to a click-through, warm tint
window on that hardware. This is an **approximation**, not a calibrated colour
transformation: it can lift black levels and alter HDR appearance. Select Gamma
manually to use the original method, or Compatible to use the overlay on other
hardware. NightK removes its overlay and restores the normal display settings
outside the active window and when quitting.

## Features

- Warm the display between a configurable **start** and **end** time
  (overnight windows such as 20:00 - 07:00 are supported).
- Optional **gradual transition** that eases the warming in during the hour
  before the start time and back out over the last, instead of snapping on/off.
- Adjustable color **temperature** from 1000 K to 6500 K.
- **Automatic / Gamma / Compatible** display rendering selector. Automatic uses
  the compatible overlay on macOS 27.2 + Mac17,8 only; other systems keep gamma.
- Compatible mode uses AppKit panels across Spaces and displays, ignores mouse
  events, requires no private APIs or screen-recording permission, and is removed
  on disable, reset, or exit. Its opacity approximates warmth; the Kelvin number
  is not a physically accurate white-point calibration in this mode.
- Works across **multiple displays** and re-applies on wake / display changes.
- **English / Hungarian** UI.
- Sandboxed menu-bar agent: no Dock icon, minimal CPU/RAM.

Run the isolated colour-policy regression suite with
`scripts/test-display-compatibility.sh` (does not change the display), then
compile with `scripts/release.sh build` before installing.

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
