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
- importer preflight classification so homepages and category pages are not confused with one another
- wardrobe-only filtering so beauty or non-clothing products do not leak into import previews
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
- Confirm toolbar icons remain visible on a physical device and simulator because they carry their own contrast chrome
- Confirm atmospheric text fields and primary/secondary buttons render consistently across Weather, Planner, and Import
- Paste a homepage URL into Import and verify the readiness card blocks it before import begins
- Paste a product or category URL into Import and verify the staged queue appears with batch-add controls

## UI benchmarks

`ClimateClosetUITests/ClimateClosetBenchmarks.swift` covers the app paths most likely to feel slow to a user:

- cold-ish launch to the Weather screen
- first switch from Weather into Wardrobe, Planner, and Import
- save latency for a new wardrobe item
- import latency for a category-shaped Tom Ford fixture URL under a deterministic fixture importer
- save latency for a planner day with wardrobe selections and notes
- deterministic documentation screenshot capture for the Weather, Wardrobe, Planner, and Import tabs

The benchmark target launches the app with a dedicated benchmark profile so measurements are stable:

- wardrobe data is seeded to a larger persisted JSON store before measurement
- weather results are served from a local fixture client
- the Tom Ford import path uses deterministic imported items instead of live network variance, while still exercising the same preflight and staging UI that ships in the app
- the planner benchmark waits for the model persistence revision to change, so it measures the actual save boundary rather than a fragile UI redraw
- the documentation screenshot flow exports full-screen attachments so README imagery can be refreshed from the same controlled benchmark environment
