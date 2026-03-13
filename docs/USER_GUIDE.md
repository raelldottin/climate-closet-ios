# User Guide

## Overview

Climate Closet combines daily weather planning with wardrobe tracking. The app is designed for one core question: what did I wear at this temperature, and what should I wear next time?

## Main tabs

### Weather

- View the current temperature, apparent temperature, humidity, wind, and precipitation chance
- Browse the next twelve hourly forecast entries and the next seven daily forecasts
- Search for a city and switch the active forecast
- See a suggested outfit assembled from your wardrobe
- Review historical outfits logged near the current temperature

### Wardrobe

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

- Start with presets for H&M, Levi's, Banana Republic, and J.Crew
- Paste a product or category URL and run a best-effort import
- Review parsed catalog items and add them directly to your wardrobe
- Use the custom option to try any other clothing site that exposes usable metadata

## Best results for importing

- Product pages generally work better than storefront homepages
- Category pages that render product cards in HTML work better than fully client-side experiences
- Sites with JSON-LD product metadata usually import the cleanest names, images, and prices

## Data storage

- Wardrobe items and outfit assignments are stored locally on the device
- Weather data is fetched live when you refresh or switch locations
- Imported items are not stored until you add them to the wardrobe

## Running on a device

Open the project in Xcode and select a personal development team for the app target if you want to deploy to a physical iPhone.

