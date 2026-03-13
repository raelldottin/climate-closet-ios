# Architecture

## Summary

Climate Closet uses a ports-and-adapters structure so that the weather logic, import parsing, and outfit recommendation rules stay easy to test without UI or filesystem coupling.

## Layers

### UI layer

- SwiftUI views under `ClimateCloset/`
- Static resources under `ClimateCloset/Assets.xcassets` and `ClimateCloset/LaunchScreen.storyboard`
- `AppModel` is the presentation orchestrator and state holder
- Views stay focused on rendering and user interaction

### Domain layer

- Plain Swift value types such as `WardrobeItem`, `OutfitAssignment`, `WeatherReport`, and `ImportedCatalogItem`
- `OutfitPlanningService` contains pure recommendation and history-matching logic
- Temperature ranges live in domain-friendly models that stay independent from networking concerns

### Adapter layer

- `JSONWardrobeRepository` persists wardrobe data to the app support directory
- `OpenMeteoWeatherClient` fetches real weather and geocoding data, then maps remote weather codes into app conditions
- `HTMLCatalogImporter` fetches storefront HTML and delegates parsing to `HTMLCatalogParser`

## Why this shape

This layout intentionally follows the spirit of *Unit Testing: Principles, Practices, and Patterns*:

- Domain logic is isolated from side effects
- External dependencies are hidden behind protocols
- Most behavior is verified with deterministic unit tests
- Integration tests focus on slower, real adapters like filesystem persistence

## Tradeoffs

- The storefront importer uses best-effort parsing instead of deep per-site browser automation
- Weather is sourced from Open-Meteo rather than WeatherKit so the app works without Apple weather service credentials
- The app uses local JSON persistence instead of a heavier database to keep the storage adapter transparent and easy to exercise in tests
