# Climate Closet

Climate Closet is an iOS SwiftUI weather app inspired by Apple's Weather experience, with a built-in wardrobe journal and planner. It helps track what you wore for specific temperatures, assign clothing to calendar days, and import wardrobe-ready catalog items from apparel product and category pages.

## What it does

- Live weather forecasts powered by Open-Meteo with current, hourly, and daily views
- Wardrobe management for every clothing item in your closet
- Shared quick-add wardrobe flow from both the Weather and Wardrobe tabs
- Day-by-day outfit assignment with temperature and condition logging
- Weather-aware outfit recommendations based on your closet and what you have worn before
- An import studio that preflights pasted URLs, blocks vague landing pages, filters out non-wardrobe products, and stages multi-item imports before they touch your closet
- Local-first persistence with a ports-and-adapters architecture that keeps the core testable

## Screenshots

<p align="center">
  <img src="docs/screenshots/weather.jpg" alt="Weather screen with current conditions, search, and toolbar actions." width="23%" />
  <img src="docs/screenshots/wardrobe.jpg" alt="Wardrobe screen with search, category filters, and saved clothing items." width="23%" />
  <img src="docs/screenshots/planner.jpg" alt="Planner screen with monthly calendar and day-level outfit planning." width="23%" />
  <img src="docs/screenshots/import.jpg" alt="Import screen showing a staged catalog queue ready for batch add." width="23%" />
</p>

## Project layout

- `ClimateCloset/`: SwiftUI app target
- `ClimateCloset/Assets.xcassets`: app icon and launch screen artwork
- `ClimateCloset/LaunchScreen.storyboard`: static launch experience shown while SwiftUI boots
- `ClimateClosetTests/`: unit tests for pure domain and parsing logic
- `ClimateClosetIntegrationTests/`: adapter-level integration tests
- `docs/`: user and engineering documentation
- `scripts/`: small typed developer tooling covered by `pyright`

## Requirements

- Xcode 26.3 or newer
- iOS Simulator runtime
- Python 3.9+ for `pyright`

## Local setup

```bash
git clone https://github.com/raelldottin/climate-closet-ios.git
cd climate-closet-ios
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
```

## Local signing

Device-signing overrides live in the gitignored `Config/Local.xcconfig` file so personal team identifiers never need to enter source control. A placeholder is included in `Config/Local.xcconfig.example`, and the committed `Config/App.xcconfig` loads local overrides when present.

## Build channels and versioning

- `Debug` and `Release` are now intentionally distinct app builds.
- `Debug` installs as `com.raelldottin.ClimateCloset.debug` with the display name `Climate Closet Debug`, so it can live beside a release build on the same device.
- `Release` keeps the public bundle ID `com.raelldottin.ClimateCloset` and the display name `Climate Closet`.
- Public version metadata lives in `Config/AppVersion.xcconfig`, which drives both `CFBundleShortVersionString` and `CFBundleVersion`.
- Private machine-specific overrides still belong only in `Config/Local.xcconfig`.

## Verification

```bash
make verify-layout
make lint-python
make lint-swift
make test
```

`make test` runs both the unit and integration test bundles through the shared `ClimateCloset` scheme.

## UI benchmarks

The repo also includes a repeatable UI benchmark suite in `ClimateClosetUITests/ClimateClosetBenchmarks.swift`. It launches the app in a deterministic benchmark mode with a larger local wardrobe fixture, stubbed weather/import services, and a persisted JSON store so launch and save paths still exercise real rendering and repository work.

```bash
xcodebuild test \
  -project ClimateCloset.xcodeproj \
  -scheme ClimateCloset \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ClimateClosetUITests/ClimateClosetBenchmarks \
  CODE_SIGNING_ALLOWED=NO
```

That suite reports timing summaries for:

- launch to first weather frame
- first load when switching from Weather to Wardrobe, Planner, and Import
- saving a new wardrobe item
- importing a Tom Ford fixture URL
- saving a day assignment and note

The same UI target also includes `testDocumentationScreenshots`, which captures the README screenshots from the deterministic benchmark profile so docs imagery stays aligned with the real app.

## Design notes

- The app follows the unit-testing guidance from *Unit Testing: Principles, Practices, and Patterns* by keeping the domain logic pure, pushing I/O to adapters, and reserving slower tests for repository integration.
- The app icon and launch screen share the in-app atmospheric palette, combining weather and wardrobe motifs in a single brand mark.
- Shared atmospheric screens now follow an explicit design system in `SharedViews.swift`, with named spacing, radius, typography, input, and button primitives instead of one-off visual values.
- The Weather and Wardrobe tabs intentionally reuse the same add-clothing sheet so the creation gesture stays calm, direct, and consistent anywhere the app invites you to grow your closet.
- The importer now favors clarity over false optimism: product pages and category pages are called out before import begins, while homepages and beauty catalogs are explicitly rejected instead of producing noisy fallback results.
- The default experience works in the simulator with signing disabled, while physical-device signing can stay local through `Config/Local.xcconfig`.

## Documentation

- [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md)
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- [`docs/TESTING_STRATEGY.md`](docs/TESTING_STRATEGY.md)
- [`docs/DEMO_READINESS.md`](docs/DEMO_READINESS.md)
- [`docs/UI_GUIDELINES.md`](docs/UI_GUIDELINES.md)
