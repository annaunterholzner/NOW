# NOW

An analog clock where every hand just says **NOW**, set in a hand-drawn-style 2D landscape that follows the real sky where you are: the sun rises and sets in the right place, the moon shows its real phase, stars come out at night, and the scenery changes with the seasons (blossoms and petals in spring, fireflies on summer nights, falling leaves in autumn, snow in winter). South of the equator the seasons are flipped; near the equator it stays green.

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

- **Double-tap** (or double-click) to show a small caption with the season, sun height and moon phase.
- **iPhone:** the screen stays on while NOW is open, so it works as a nightstand clock (great in landscape / StandBy-style on a charger).
- **Mac:** a clock icon appears in the menu bar. Choose **Show NOW on Desktop** to put it behind your desktop icons on every screen and Space. Close the window and it keeps running in the menu bar.

## Preview in a browser

`preview/index.html` is a web version of the same drawing, with sliders to move through the day and the year and a few places to compare (Reykjavík, Singapore, Sydney…). Open it in any browser.

## How it's built

| File | What it does |
| --- | --- |
| `Shared/Astronomy.swift` | Sun and moon position and moon phase (Astronomy Answers formulas, as in suncalc) |
| `Shared/SkyState.swift` | Turns date + place into daylight, golden hour, star visibility and season blend |
| `Shared/LocationProvider.swift` | Coarse location, remembered between launches, time-zone fallback |
| `Shared/NatureScene.swift` | The illustrated landscape, drawn with SwiftUI `Canvas` |
| `Shared/ClockFace.swift` | The dial and the three NOW hands |
| `Shared/NowView.swift` | Puts scene + clock together, ~30 fps |
| `macOS/DesktopMode.swift` | Desktop-wallpaper mode and the menu bar menu |
| `project.yml` | XcodeGen project (iOS 17+, macOS 14+) |

## Ideas for next steps

- Home Screen / Lock Screen / Mac desktop **widgets** (WidgetKit)
- Real **weather** (rain, fog, clouds) via WeatherKit
- More landscapes to choose from: sea coast, forest, desert, city park
- An app icon and App Store listing
