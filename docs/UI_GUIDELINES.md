# UI Guidelines

## Purpose

Climate Closet should feel calm, precise, and inevitable. The interface should never look assembled from one-off decisions. Every new surface must reuse the shared visual language in `SharedViews.swift` unless the design system is intentionally expanded first.

## Core principles

- Lead with climate, not decoration: data and actions come first, while atmospheric styling stays in the background.
- One accent, one hierarchy: the warm amber accent is reserved for the primary action or the current selection, never for unrelated emphasis.
- Surfaces should nest predictably: full sections use `GlassCard`; repeated sub-elements inside a section use `GlassTile`.
- Controls must explain themselves through consistency: identical actions should look identical everywhere in the app.
- Exceptions must be named, not implied: any surface that departs from the atmospheric card system must be documented here as an intentional pattern.
- Remove arbitrary numbers: spacing, radii, and text roles come from `ClimateUI` tokens instead of ad hoc literals.

## Layout rules

- Screen inset: `20pt`
- Section gap between cards: `18pt`
- Medium selection and grid gap: `10pt`
- Gap between rows inside a card: `12pt`
- Media row gap: `14pt`
- Compact metadata gap: `8pt`
- Tight text-support gap: `6pt`
- Card padding: `20pt`
- Dense tile padding: `12pt`
- Tile padding: `14pt`
- Calendar day tile padding: `10pt`
- Calendar day minimum height: `58pt`
- Import preview thumbnail: `96pt x 116pt`

Use the shared layout tokens in `ClimateUI.Layout`. If a new value is needed, add a named token first.

## Shape rules

- Primary cards: `28pt` continuous corners
- Nested tiles and mode cards: `22pt`
- Dense forecast and metric tiles: `20pt`
- Interactive controls and buttons: `18pt`
- Selectable tiles and calendar cells: `18pt`
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

## Section headers

- Every card-level section begins with `SectionHeader`; do not hand-roll header `HStack` or `VStack` combinations inside a `GlassCard`.
- `SectionHeader` owns the canonical anatomy: leading title, optional subtitle directly underneath, optional trailing actions aligned to the top edge.
- Standard card headers use `titleRole: .sectionTitle`. Elevated anchors, such as the planner month navigator, may use `titleRole: .title` explicitly.
- Title and subtitle spacing is fixed by `ClimateUI.Layout.sectionHeaderSpacing`; do not replace it with local literals.
- Trailing header controls should be compact and durable: use `ClimateIconButtonStyle`, `ToolbarIconButton`, or a standard action button style depending on prominence.
- Hero cards are the only allowed exception. Large display compositions like the current-weather summary may use custom title treatment when they are not serving as a reusable section header.

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
- Icon and control sizing comes from `ClimateUI.Icon` and `ClimateUI.Metrics`; do not size SF Symbols or control frames inline on screen views.
- Chips are informational or filter-oriented only; they are not substitutes for primary buttons.

If two buttons perform the same job in different tabs, they must share the same icon, size, and interaction model.

## Screen composition

- Weather, Wardrobe, Planner, and Import all begin with the atmospheric background and a vertically stacked card layout.
- Every reusable section card opens with `SectionHeader` before body content, unless the card is a hero display called out as an intentional exception.
- Empty states use `EmptyStateCard`; do not invent a screen-specific empty-state treatment.
- Repeated rows inside cards should become `GlassTile` blocks instead of free-floating text.
- Selection should be communicated through fill and border emphasis, not through layout shifts.

## Modal editing flows

- `AddWardrobeItemSheet` is the canonical add-clothing editor for the entire app.
- Weather and Wardrobe must both invoke that exact sheet through `WardrobeAddToolbarButton`; there is no tab-specific add flow.
- The sheet intentionally uses a native grouped `Form` inside a `NavigationStack` for input density, keyboard behavior, and platform familiarity.
- Section order is fixed: `Identity`, `Fit`, `Notes`, then `Links`.
- Toolbar actions are fixed: `Cancel` on the leading edge, `Save` on the trailing edge, and `Save` stays disabled until the item has a non-empty name.
- New clothing-creation entry points must reuse this sheet unless the team first expands the design system and updates this document.

## Accessibility and keynote safety

- Never rely on navigation-bar tint alone for icon visibility; toolbar icons must include their own contrast treatment.
- Tappable controls should stay at or above Apple's comfortable hit-target size.
- Error and readiness messaging must be readable without color alone.
- Placeholder or preview content must never masquerade as imported data.

## Exception registry

The following are the only approved exceptions to the default atmospheric card system:

- The current-weather hero may use custom display typography and icon scale because it is a single-screen summary, not a reusable section header.
- The add-clothing sheet may use native grouped form controls because dense editing performs better with platform-standard form anatomy than with decorative card chrome.

If another exception is needed, document it here before it ships.

## Change management

- New UI work starts by checking whether an existing shared primitive already solves the problem.
- If a new visual pattern is necessary, add it to `SharedViews.swift` with named tokens before using it in a screen.
- Review new screens for token compliance before merging.
