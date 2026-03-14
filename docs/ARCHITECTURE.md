# Architecture

## Summary

Climate Closet uses a ports-and-adapters structure so that the weather logic, import parsing, and outfit recommendation rules stay easy to test without UI or filesystem coupling.

## Layers

### UI layer

- SwiftUI views under `ClimateCloset/`
- Static resources under `ClimateCloset/Assets.xcassets` and `ClimateCloset/LaunchScreen.storyboard`
- `AppModel` is the presentation orchestrator and state holder
- Shared UI building blocks, including the design tokens, atmospheric cards, toolbar actions, and add-clothing sheet, live in `SharedViews.swift`
- App build identity and version metadata are driven from committed xcconfig files under `Config/`
- Views stay focused on rendering and user interaction

### Domain layer

- Plain Swift value types such as `WardrobeItem`, `OutfitAssignment`, `WeatherReport`, and `ImportedCatalogItem`
- `OutfitPlanningService` contains pure recommendation and history-matching logic
- Temperature ranges live in domain-friendly models that stay independent from networking concerns

### Adapter layer

- `JSONWardrobeRepository` persists wardrobe data to the app support directory
- `OpenMeteoWeatherClient` fetches real weather and geocoding data, then maps remote weather codes into app conditions
- `HTMLCatalogImporter` fetches storefront HTML, classifies whether the URL looks importable, and delegates parsing to `HTMLCatalogParser`

## Why this shape

This layout intentionally follows the spirit of *Unit Testing: Principles, Practices, and Patterns*:

- Domain logic is isolated from side effects
- External dependencies are hidden behind protocols
- Most behavior is verified with deterministic unit tests
- Integration tests focus on slower, real adapters like filesystem persistence

## Tradeoffs

- The storefront importer stays lightweight instead of using deep per-site browser automation, but it now gates imports through URL preflight and wardrobe-only filtering so ambiguous pages fail clearly instead of creating noisy preview data
- Weather is sourced from Open-Meteo rather than WeatherKit so the app works without Apple weather service credentials
- The app uses local JSON persistence instead of a heavier database to keep the storage adapter transparent and easy to exercise in tests
- The design system is intentionally centralized so future UI work extends named primitives instead of accumulating arbitrary visual values
