# Gamma-only operation on Mac17,8 / macOS 27.2

## Root cause / limits

The Apple M5 Pro display driver can acknowledge `CGSetDisplayTransferByTable`
while leaving the physical panel unchanged, even when its values are readable
with `CGGetDisplayTransferByTable`. Apple engineering independently reproduced
this behavior with both the table and formula APIs, and Apple Feedback
`FB22273730` / `FB22273782` remain under investigation as of October 2026:
https://developer.apple.com/forums/thread/819331

On this Mac (Mac17,8, macOS 27.2, 26B123):

- The gamma capacity is **1024**, whereas original NightK used 256.
- All three public CoreGraphics setter variations succeeded and round-tripped:
  floating-point table, formula, byte table.
- A full **1024-entry** gamma LUT also succeeded and was readable.
- ColorSync display custom profiles were initially absent. An isolated test
  temporarily assigned the system sRGB profile, restored the factory profile,
  and verified no custom profile remained. It did not demonstrate a persistent
  physical-pipeline fix.

Because native screenshot pixel values are not proof of post-compositor display
hardware LUT application, successful API returns **do not prove a visible
physical change**. Verification requires human observation or a colorimeter.
Do not disable system colour daemons, use private Apple APIs, or misrepresent
an overlay or ColorSync colour profile as a true gamma correction.

## Project change

- Deleted the earlier NightK 1.3 colour overlay, its selector and its
  compatibility test. New NightK 1.4 is strictly gamma-based.
- Detect each active display's `CGDisplayGammaTableCapacity`, and validate
  allocation size (2...4096). Check CoreGraphics's return code per display.
- Keep the existing warm colour calculation and schedule, without a second
  rendering path or background colour-management service.
- Unit tests for capacity, lookup endpoints and colour monotonicity.

An Apple OS update is needed if the driver continues to ignore the display LUT.
The integrated Apple Night Shift still works because it uses another system
colour-management path, not NightK's public gamma-table API.
