# Climate Closet

Climate Closet is an iOS SwiftUI weather app inspired by Apple's Weather experience, with a built-in wardrobe journal and planner. It helps track what you wore for specific temperatures, assign clothing to calendar days, and import catalog items from supported storefront URLs on a best-effort basis.

## What it does

- Live weather forecasts powered by Open-Meteo with current, hourly, and daily views
- Wardrobe management for every clothing item in your closet
- Shared quick-add wardrobe flow from both the Weather and Wardrobe tabs
- Day-by-day outfit assignment with temperature and condition logging
- Weather-aware outfit recommendations based on your closet and what you have worn before
- Clothing import presets for H&M, Levi's, Banana Republic, and J.Crew, plus best-effort imports from arbitrary URLs
- Local-first persistence with a ports-and-adapters architecture that keeps the core testable

## Screenshots

<p align="center">
  <img src="docs/screenshots/weather.jpg" alt="Weather screen with current conditions, hourly forecast, and 7-day outlook." width="30%" />
  <img src="docs/screenshots/wardrobe.jpg" alt="Wardrobe screen with closet search, category filters, and saved clothing items." width="30%" />
  <img src="docs/screenshots/planner.jpg" alt="Planner screen with a monthly calendar and weather-aware outfit planning." width="30%" />
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

## Verification

```bash
make verify-layout
make lint-python
make lint-swift
make test
```

`make test` runs both the unit and integration test bundles through the shared `ClimateCloset` scheme.

## Design notes

- The app follows the unit-testing guidance from *Unit Testing: Principles, Practices, and Patterns* by keeping the domain logic pure, pushing I/O to adapters, and reserving slower tests for repository integration.
- The app icon and launch screen share the in-app atmospheric palette, combining weather and wardrobe motifs in a single brand mark.
- The Weather and Wardrobe tabs intentionally reuse the same add-clothing sheet so the creation gesture stays calm, direct, and consistent anywhere the app invites you to grow your closet.
- The default experience works in the simulator with signing disabled, while physical-device signing can stay local through `Config/Local.xcconfig`.

## Documentation

- [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md)
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- [`docs/TESTING_STRATEGY.md`](docs/TESTING_STRATEGY.md)
