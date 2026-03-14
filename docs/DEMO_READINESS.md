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

Reference physical-device `Debug` benchmark run on `iPhone 15 Pro Max` running `iOS 26.0.1` on March 13, 2026:

- `launch_to_weather_root`: `OUTPERFORMING`, mean `2535.0 ms`, target `3500 ms`, ceiling `4250 ms`
- `weather_to_wardrobe_first_load`: `OUTPERFORMING`, mean `2619.3 ms`, target `2750 ms`, ceiling `3300 ms`
- `weather_to_planner_first_load`: `OUTPERFORMING`, mean `2436.5 ms`, target `2900 ms`, ceiling `3400 ms`
- `weather_to_import_first_load`: `OUTPERFORMING`, mean `2364.8 ms`, target `2600 ms`, ceiling `3150 ms`
- `save_new_wardrobe_item`: `MEETING`, mean `2118.5 ms`, target `2000 ms`, ceiling `2500 ms`
- `import_tom_ford_fixture`: `MEETING`, mean `1587.4 ms`, target `1400 ms`, ceiling `1800 ms`
- `save_day_assignment_and_note`: `MEETING`, mean `1805.9 ms`, target `1500 ms`, ceiling `1900 ms`

Current benchmark verdict:

- `OUTPERFORMING`: `4`
- `MEETING`: `3`
- `UNDERPERFORMING`: `0`

Latest simulator screening run on `iPhone 16` on March 13, 2026:

- `launch_to_weather_root`: `MEETING`, mean `4024.9 ms`
- `weather_to_wardrobe_first_load`: `MEETING`, mean `3034.4 ms`
- `weather_to_planner_first_load`: `MEETING`, mean `3173.3 ms`
- `weather_to_import_first_load`: `MEETING`, mean `2890.1 ms`
- `save_new_wardrobe_item`: `MEETING`, mean `2342.0 ms`
- `import_tom_ford_fixture`: `MEETING`, mean `1538.0 ms`
- `save_day_assignment_and_note`: `MEETING`, mean `1686.7 ms`

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

xcrun xctrace list devices

xcodebuild test \
  -project ClimateCloset.xcodeproj \
  -scheme ClimateCloset \
  -destination 'id=<physical-device-id>' \
  -only-testing:ClimateClosetUITests/ClimateClosetBenchmarks/testLaunchBenchmark \
  -only-testing:ClimateClosetUITests/ClimateClosetBenchmarks/testTabSwitchBenchmarks \
  -only-testing:ClimateClosetUITests/ClimateClosetBenchmarks/testAddWardrobeItemBenchmark \
  -only-testing:ClimateClosetUITests/ClimateClosetBenchmarks/testImportBenchmark \
  -only-testing:ClimateClosetUITests/ClimateClosetBenchmarks/testSaveDayBenchmark
```

## Dry-run checklist

- Launch into Weather and confirm current forecast loads with visible refresh and add controls.
- Switch through Weather, Wardrobe, Planner, and Import without layout jumps or missing chrome.
- Add a wardrobe item from Weather or Wardrobe and confirm it persists into the closet.
- Import a category or product URL and verify only wardrobe-ready items appear in the staged queue.
- Save a planner day with a note and confirm it survives relaunch.
- Keep the keynote device on the `Release` channel and rehearse with `Debug` when testing instrumentation or fixture-backed runs.
