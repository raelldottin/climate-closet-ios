# Demo Readiness

## Snapshot

This readiness snapshot was taken on March 13, 2026 for Johnny's keynote dry run.

## What was checked

- The shared atmospheric design system is applied across Weather, Wardrobe, Planner, and Import.
- Toolbar icons render with self-contained contrast chrome instead of relying on navigation-bar tint.
- The importer rejects non-ingress sources, stages real wardrobe-ready results, and supports batch add.
- Debug and Release builds remain distinct, so demo devices can keep a safe rehearsal build beside the public build.
- README screenshots were regenerated from the app's deterministic benchmark profile rather than hand-curated simulator state.

## Benchmark snapshot

Latest simulator benchmark run on `iPhone 16`:

- `launch_to_weather_root`: mean `3977.1 ms`
- `weather_to_wardrobe_first_load`: mean `3047.3 ms`
- `weather_to_planner_first_load`: mean `3169.4 ms`
- `weather_to_import_first_load`: mean `2924.8 ms`
- `save_new_wardrobe_item`: mean `2356.3 ms`
- `import_tom_ford_fixture`: mean `1555.9 ms`
- `save_day_assignment_and_note`: mean `1673.1 ms`

## Verification commands

```bash
swift format lint --recursive ClimateCloset ClimateClosetTests ClimateClosetIntegrationTests ClimateClosetUITests --strict

xcodebuild test \
  -project ClimateCloset.xcodeproj \
  -scheme ClimateCloset \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ClimateClosetTests \
  -only-testing:ClimateClosetIntegrationTests \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project ClimateCloset.xcodeproj \
  -scheme ClimateCloset \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ClimateClosetUITests/ClimateClosetBenchmarks/testLaunchBenchmark \
  -only-testing:ClimateClosetUITests/ClimateClosetBenchmarks/testTabSwitchBenchmarks \
  -only-testing:ClimateClosetUITests/ClimateClosetBenchmarks/testAddWardrobeItemBenchmark \
  -only-testing:ClimateClosetUITests/ClimateClosetBenchmarks/testImportBenchmark \
  -only-testing:ClimateClosetUITests/ClimateClosetBenchmarks/testSaveDayBenchmark \
  -only-testing:ClimateClosetUITests/ClimateClosetBenchmarks/testToolbarIconsRenderSmoke \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project ClimateCloset.xcodeproj \
  -scheme ClimateCloset \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ClimateClosetUITests/ClimateClosetBenchmarks/testDocumentationScreenshots \
  CODE_SIGNING_ALLOWED=NO
```

## Dry-run checklist

- Launch into Weather and confirm current forecast loads with visible refresh and add controls.
- Switch through Weather, Wardrobe, Planner, and Import without layout jumps or missing chrome.
- Add a wardrobe item from Weather or Wardrobe and confirm it persists into the closet.
- Import a category or product URL and verify only wardrobe-ready items appear in the staged queue.
- Save a planner day with a note and confirm it survives relaunch.
- Keep the keynote device on the `Release` channel and rehearse with `Debug` when testing instrumentation or fixture-backed runs.
