# Testing Strategy

## Guiding principles

The test approach is directly informed by *Unit Testing: Principles, Practices, and Patterns*:

- Favor fast, deterministic unit tests for decision logic
- Keep domain behavior pure so tests do not require UI, networking, or file I/O
- Use integration tests only where real adapters add confidence
- Verify behavior, not private implementation details

## Unit tests

`ClimateClosetTests/` covers:

- outfit recommendation selection and layer rules
- temperature-history matching
- HTML catalog parsing from JSON-LD, meta tags, and generic anchors
- weather client mapping from API payloads into app models

## Integration tests

`ClimateClosetIntegrationTests/` covers:

- round-trip persistence through the JSON repository using a temporary directory
- durable save semantics across multiple writes

## CI checks

- `pyright` on typed Python helper scripts
- `swift-format` linting on app and test targets
- `xcodebuild test` through the shared scheme, which runs both the unit and integration test bundles

## Manual UI smoke checks

- Confirm the `+` button on both the Weather and Wardrobe tabs opens the same add-clothing sheet
- Save a wardrobe item from each tab and verify it appears in the closet and persists after relaunch
