# macOS 27.2 / M5 Pro NightK display compatibility

The CoreGraphics display-transfer API can report `kCGErrorSuccess` and return
altered RGB LUT data while the M5 Pro display hardware still shows its normal
colours. This is an upstream OS behaviour, not a scheduling or persistence bug.
See Apple Developer Forums topic **819331** (reports FB22273730 / FB22273782).

## Supported response

- **Automatic**: on macOS 27.2 and model `Mac17,8`, use the compatible AppKit
  overlay, without mutating ColorSync profile state or calling private APIs.
  Other OS versions and Mac models keep the original gamma path by default.
- **Gamma**: directly writes the display LUT, checks the CoreGraphics return
  code on each display, and allows old hardware to keep the native technique.
- **Compatible**: one click-through, non-activating `NSPanel` per `NSScreen`, at
  screen-saver window level, for every Space and full-screen application.
  Panels are closed on disable, schedule end, reset, app exit, and removed on
  display disconnect. They are recreated on next activation after wake.

This overlay is **not a physically calibrated Kelvin conversion**. It tints
pixels with a translucent warm veil and may raise black levels, affect HDR
colour accuracy, and appear differently from Apple's integrated Night Shift.
Do not run Night Shift simultaneously unless you intentionally want both effects.
Do not use compatible mode for colour-critical calibration.

## Validation on the affected Mac

Platform: Mac17,8, Apple M5 Pro, macOS 27.2 (26B123), integrated Liquid Retina
XDR. 1400 K target, active between 20:00 and 07:00.

1. `bash scripts/test-display-compatibility.sh`: PASS, 12 pure-model assertions.
2. `scripts/release.sh build`: Release compilation and signature validation PASS.
3. Live installed 1.3 app: WindowServer listed one full-screen NightK layer
   at level 1000 with alpha ~0.278; the gamma LUT had returned to neutral.
4. Screen capture sampled a black desktop pixel as warm-coloured with the app
   running (62,36,7); after quitting NightK, the same pixel returned to (0,0,0).
5. Reopening the app restored its running process and overlay; idle process
   CPU reading 0.0% when sampled.

Screen capture observations verify *visible tint*, not calibrated white-point,
full-screen app coverage under every app, or accessibility of every input mode.
No personal screen captures are included in the repository.
