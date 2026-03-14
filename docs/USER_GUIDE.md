# User Guide

## Overview

Climate Closet combines daily weather planning with wardrobe tracking. The app is designed for one core question: what did I wear at this temperature, and what should I wear next time?

The app icon and launch screen use the same weather-meets-wardrobe branding as the in-app experience, so opening the app on device or in the simulator matches the rest of the visual design.

The main tabs also follow a shared UI language: the same toolbar chrome, the same primary and secondary button treatments, and the same card and tile hierarchy repeat throughout the app so actions feel deliberate instead of arbitrary.

## Main tabs

### Weather

- View the current temperature, apparent temperature, humidity, wind, and precipitation chance
- Browse the next twelve hourly forecast entries and the next seven daily forecasts
- Search for a city and switch the active forecast
- Use the `+` button to add a clothing item without leaving the forecast context
- See a suggested outfit assembled from your wardrobe
- Review historical outfits logged near the current temperature

### Wardrobe

- Use the same `+` button and add sheet as the Weather tab to capture new clothing items
- Add clothing items with brand, category, color, notes, warmth level, preferred temperature range, and optional source URLs
- Browse your whole closet, filter by category, and remove items you no longer own
- Review when an item was last assigned to an outfit

### Planner

- Tap a day in the month grid to plan an outfit
- Select one or more clothing items from your wardrobe
- Record the temperature and the weather condition for that day
- Save notes such as “office day” or “outdoor dinner”
- Revisit past dates to understand what worked for specific temperatures

### Import

- Choose whether you are importing a product page, a category page, or an open-web apparel link
- Paste a clothing URL and let the preflight card tell you whether it looks keynote-safe before you import
- Review imported pieces in a staged queue, then add selected items in one batch or send a single piece straight into your wardrobe
- Pages that resolve to homepages, editorial content, or beauty catalogs are blocked on purpose instead of generating noisy fallback items

## Best results for importing

- Product pages are still the cleanest path when you want one precise item
- Category pages work well when they expose real product cards in server-rendered HTML
- The importer only keeps wardrobe-ready products; beauty, fragrance, and other non-clothing items are filtered out
- If a page is too broad, the app tells you before the network import starts

## Data storage

- Wardrobe items and outfit assignments are stored locally on the device
- Weather data is fetched live when you refresh or switch locations
- Imported items are not stored until you explicitly add them to the wardrobe

## Running on a device

Open the project in Xcode and select a personal development team for the app target if you want to deploy to a physical iPhone.
