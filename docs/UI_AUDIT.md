# UI Audit

## Purpose

This audit records which UI patterns are canonical, which ones are intentional exceptions, and what was normalized so the app does not drift into undocumented design decisions.

## Audit result

On March 13, 2026, the app screens were audited for screen-level one-off spacing, radius, sizing, and presentation patterns.

- Shared geometry used by Weather, Wardrobe, Planner, and Import now flows through `ClimateUI` tokens instead of inline screen literals.
- Card-level sections consistently use `GlassCard` and `SectionHeader`.
- Repeated interior content uses `GlassTile`, `CapsuleTag`, `EmptyStateCard`, and shared button styles.
- The add-clothing experience is now explicitly treated as a first-class pattern rather than an undocumented modal exception.

## Canonical patterns

- Screen shell: `AtmosphericBackground` plus vertically stacked `GlassCard` sections.
- Card header: `SectionHeader` with title, optional subtitle, and optional trailing action.
- Repeated row or tile: `GlassTile`.
- Empty state: `EmptyStateCard`.
- Toolbar controls: `ToolbarIconButton` and `WardrobeAddToolbarButton`.
- Creation flow: `AddWardrobeItemSheet`.

## Approved exceptions

- Current-weather hero display in Weather.
- Native grouped add-clothing sheet.

No other screen-level exceptions are currently approved.

## Change rule

If a new screen or flow cannot be expressed with the patterns above, update `SharedViews.swift` and `UI_GUIDELINES.md` before merging the UI.
