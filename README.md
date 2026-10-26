# NOW

An analog clock where every hour on the dial reads **NOW**, with clean hands, set in a hand-drawn-style 2D landscape that follows the real sky where you are: the sun rises and sets in the right place, the moon shows its real phase, stars come out at night, and the scenery changes with the seasons (blossoms and petals in spring, fireflies on summer nights, falling leaves in autumn, snow in winter). South of the equator the seasons are flipped; near the equator it stays green.

Two sceneries to choose from:
- **Mountains**: snowy peaks, hills with trees, a meadow with flowers.
- **Coast**: the sea with a shimmering path of sun- or moonlight, waves washing up the beach, dunes with grass, and a lighthouse whose beam sweeps at night. Near the equator a palm grows on the dune.

Runs on **iPhone / iPad** and **Mac**. On the Mac it can also live on your desktop, behind your icons, like a moving wallpaper.

Everything is calculated on the device. No internet, no accounts, no images: the landscape is drawn in code.

## Try it on your iPhone or Mac

You need a Mac with **Xcode** (free in the Mac App Store).

1. Install XcodeGen once: `brew install xcodegen` (needs [Homebrew](https://brew.sh)).
2. In this folder run `xcodegen`. It creates `NOW.xcodeproj`.
3. Open `NOW.xcodeproj` in Xcode.
4. Pick the target at the top:
   - **NOW-iOS** and your iPhone (plugged in, or a simulator), or
   - **NOW-macOS** and "My Mac".
5. In *Signing & Capabilities*, choose your Apple ID as the Team. Press ▶︎ Run.

Allow location when asked. Without it, NOW guesses your position from your time zone.

### Using it

NOW is meant to run as a background, so nothing sits on top of the picture.

- **First launch:** a welcome card asks for your scenery, your location, and (on the Mac) whether NOW should live on your desktop. That's it.
- **Settings later:**
  - **iPhone:** press and hold anywhere on the screen.
  - **Mac:** the clock icon in the menu bar → *Settings…* (or ⌘,).
- **Settings:** scenery, clock size, second hand on/off, location, *Keep screen on* (iPhone), and *Show on Desktop* / *Open at login* (Mac).
- **Mac desktop mode** puts NOW behind your desktop icons on every screen and Space. With it on, NOW starts quietly in the menu bar without opening a window.

## Preview in a browser

`preview/index.html` is a web version of the same drawing, with sliders to move through the day and the year and a few places to compare (Reykjavík, Singapore, Sydney…). Open it in any browser.

## How it's built

| File | What it does |
| --- | --- |
| `Shared/Astronomy.swift` | Sun and moon position and moon phase (Astronomy Answers formulas, as in suncalc) |
| `Shared/SkyState.swift` | Turns date + place into daylight, golden hour, star visibility and season blend |
| `Shared/LocationProvider.swift` | Coarse location, remembered between launches, time-zone fallback |
| `Shared/NatureScene.swift` | The illustrated landscape (sky, Mountains), drawn with SwiftUI `Canvas` |
| `Shared/CoastScene.swift` | The Coast scenery: sea, light path, beach, dunes, lighthouse, palm |
| `Shared/Settings.swift` | Welcome card, Settings, scenery picker, location row |
| `Shared/ClockFace.swift` | The dial with NOW at every hour, and the clean hands |
| `Shared/NowView.swift` | Puts scene + clock together, ~30 fps |
| `macOS/DesktopMode.swift` | Desktop-wallpaper mode, menu bar menu, quiet start |
| `project.yml` | XcodeGen project (iOS 17+, macOS 14+) |

## Ideas for next steps

- Home Screen / Lock Screen / Mac desktop **widgets** (WidgetKit)
- Real **weather** (rain, fog, clouds) via WeatherKit
- More sceneries: forest, desert, lakeside, city park
- An app icon and App Store listing
