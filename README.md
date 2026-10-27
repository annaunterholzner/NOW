# NOW

An analog clock for the present moment. Every hour on the dial reads **now**, in a fine, light serif, over a blurred, slow-motion film image of a body moving through nature.

The picture follows the real sky where you are: the sun and moon move across it, the moon shows its real phase, and the colours and seasons change with the time of day and the time of year. The lettering is a soft cream that sits lightly on the blur; choose Cormorant, Italiana, a handwritten style or the Unbounded sans in Settings.

- **Scenes:** Meadow, or Shore (running through shallow water).
- **Runs on Mac, iPhone and iPad.** On the Mac it can live on your desktop, behind your icons, like a moving wallpaper.
- Everything is calculated on the device. No accounts, no tracking; your location never leaves your device.

## Install on your Mac

### The quick way: download the ready-made app

1. Go to **[Releases › NOW for Mac (latest build)](https://github.com/annaunterholzner/NOW/releases/latest)** and download **NOW-mac.zip**.
2. Double-click the zip, then drag **NOW** into your **Applications** folder.
3. Open NOW. The first time, macOS says it can't check the app. That's because it isn't signed by a registered Apple developer yet.
   Open **System Settings › Privacy & Security**, scroll down to the message about NOW, and click **Open Anyway**. You only need to do this once.
4. Allow location when asked, choose your scene, and decide if NOW should sit on your desktop.

This download is rebuilt automatically every time the project changes.

### Or build it yourself with Xcode

You need **Xcode 16 or newer** (free in the Mac App Store).

1. Install XcodeGen once: `brew install xcodegen` (needs [Homebrew](https://brew.sh)).
2. In this folder run `xcodegen`. It creates `NOW.xcodeproj`.
3. Open `NOW.xcodeproj`, choose the **NOW-macOS** target and **My Mac**.
4. In *Signing & Capabilities*, pick your Apple ID as the Team. Press ▶︎ Run.

For **iPhone**: choose the **NOW-iOS** target and your iPhone (plugged in), then Run. Your iPhone may ask you to trust your developer profile under *Settings › General › VPN & Device Management*.

## Using it

NOW is meant to run as a background, so nothing sits on top of the picture.

- **First launch:** a welcome card asks for your scene, your location and (on the Mac) whether NOW should live on your desktop.
- **Settings later:**
  - **Mac:** the clock icon in the menu bar › *Settings…* (or ⌘,). You can also move the mouse over the window and use the small button in the corner.
  - **iPhone:** press and hold anywhere on the screen.
- **Settings:** scene, clock size, second hand, *Keep screen on* (iPhone), *Show on desktop* and *Open at login* (Mac).
- **Mac menu bar:** open the window, Settings, desktop mode on/off, open at login, quit. With desktop mode on, NOW starts quietly in the menu bar without opening a window.

## Preview in a browser

Open `preview/index.html` in any browser. It's the same scene the apps show, with extra preview-only controls to pick a city and to travel through the day and the year.

## How it's built

The whole scene is one web page, `preview/index.html`: the moving body, the sky, the ink clock and the Settings card. The apps show that page full screen and add what a web page can't do on its own.

| File | What it does |
| --- | --- |
| `preview/index.html` | The scene: sun and moon maths, film-look layers, the body, the ink clock, welcome and Settings |
| `Shared/NowBridge.swift` | Shows the scene in the app and passes location and settings back and forth |
| `Shared/NowSettings.swift` | Keeps your choices, shared by the window and every desktop screen |
| `Shared/LocationProvider.swift` | Rough location, remembered between launches, time-zone fallback |
| `Shared/NowApp.swift` | The app: full-screen scene on iPhone, window + menu bar on Mac |
| `macOS/DesktopMode.swift` | Desktop-wallpaper mode, open at login, the menu bar menu |
| `Shared/Fonts/` | The dial typefaces (Cormorant Garamond, Italiana, Nothing You Could Do, Unbounded; subsets), with their licences |
| `project.yml` | XcodeGen project (iOS 17+, macOS 14+) |
| `.github/workflows/build.yml` | Builds both apps on every change and publishes the Mac download |

## Ideas for next steps

- More scenes and movements
- Home Screen, Lock Screen and Mac desktop widgets
- An app icon, signing and notarisation for a smoother install, then the App Store
