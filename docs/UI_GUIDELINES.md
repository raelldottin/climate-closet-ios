# UI Guidelines

## Purpose

Climate Closet should feel calm, precise, and inevitable. The interface should never look assembled from one-off decisions. Every new surface must reuse the shared visual language in `SharedViews.swift` unless the design system is intentionally expanded first.

## Core principles

- Lead with climate, not decoration: data and actions come first, while atmospheric styling stays in the background.
- One accent, one hierarchy: the warm amber accent is reserved for the primary action or the current selection, never for unrelated emphasis.
- Surfaces should nest predictably: full sections use `GlassCard`; repeated sub-elements inside a section use `GlassTile`.
- Controls must explain themselves through consistency: identical actions should look identical everywhere in the app.
- Remove arbitrary numbers: spacing, radii, and text roles come from `ClimateUI` tokens instead of ad hoc literals.

## Layout rules

- Screen inset: `20pt`
- Section gap between cards: `18pt`
- Gap between rows inside a card: `12pt`
- Compact metadata gap: `8pt`
- Card padding: `20pt`
- Tile padding: `14pt`

Use the shared layout tokens in `ClimateUI.Layout`. If a new value is needed, add a named token first.

## Shape rules

- Primary cards: `28pt` continuous corners
- Nested tiles and mode cards: `22pt`
- Interactive controls and buttons: `18pt`
- Small icon badges: `12pt`
- Metadata chips remain capsule-shaped

Use the shared radii in `ClimateUI.Radius`.

## Typography rules

Use the named text roles from `ClimateTextRole`:

- `display`: the current place or dominant hero title
- `displayValue`: the single large temperature value on the weather hero
- `title`: large sectional anchors like the planner month header
- `sectionTitle`: card-level titles
- `sectionSubtitle`: supporting copy directly under a section title
- `bodyStrong`: important row labels and primary item names
- `body`: standard supporting information
- `detail` and `detailStrong`: metadata, explanatory text, and low-priority status copy
- `caption`, `captionStrong`, and `eyebrow`: chips, day counts, and compact metadata
- `button`: tappable primary and secondary button labels

Do not introduce a new font recipe inline unless the role genuinely does not fit the current scale.

## Color and emphasis

- `ClimateUI.Palette.accent` is the only action color for standard flows.
- Success, warning, and critical colors are reserved for importer readiness, validation, and destructive affordances.
- Text should use `textPrimary`, `textSecondary`, or `textMuted` instead of custom opacities.
- Weather-condition colors belong to condition icons and weather meaning, not generic app controls.

## Controls

- Toolbar actions use the shared circular chrome from `ToolbarIconButton` or `WardrobeAddToolbarButton`.
- Primary buttons use `ClimateActionButtonStyle(kind: .primary)`.
- Secondary buttons use `ClimateActionButtonStyle(kind: .secondary)`.
- Inline icon controls use `ClimateIconButtonStyle`.
- Atmospheric text entry uses `climateInputField()`.
- Chips are informational or filter-oriented only; they are not substitutes for primary buttons.

If two buttons perform the same job in different tabs, they must share the same icon, size, and interaction model.

## Screen composition

- Weather, Wardrobe, Planner, and Import all begin with the atmospheric background and a vertically stacked card layout.
- Empty states use `EmptyStateCard`; do not invent a screen-specific empty-state treatment.
- Repeated rows inside cards should become `GlassTile` blocks instead of free-floating text.
- Selection should be communicated through fill and border emphasis, not through layout shifts.
- Modal forms, such as the add-clothing sheet, may keep native grouped controls for input density and platform familiarity.

## Accessibility and keynote safety

- Never rely on navigation-bar tint alone for icon visibility; toolbar icons must include their own contrast treatment.
- Tappable controls should stay at or above Apple's comfortable hit-target size.
- Error and readiness messaging must be readable without color alone.
- Placeholder or preview content must never masquerade as imported data.

## Change management

- New UI work starts by checking whether an existing shared primitive already solves the problem.
- If a new visual pattern is necessary, add it to `SharedViews.swift` with named tokens before using it in a screen.
- Review new screens for token compliance before merging.
