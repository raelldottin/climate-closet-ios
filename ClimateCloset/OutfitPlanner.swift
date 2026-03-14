import Foundation

struct OutfitPlanningService: Sendable {
  func recommend(
    for weather: WeatherSnapshot,
    wardrobe: [WardrobeItem],
    assignments: [OutfitAssignment]
  ) -> OutfitRecommendation? {
    let recentMatches = historyMatches(
      for: weather.temperatureF,
      assignments: assignments,
      wardrobe: wardrobe
    )
    return recommend(for: weather, wardrobe: wardrobe, recentMatches: recentMatches)
  }

  func recommend(
    for weather: WeatherSnapshot,
    wardrobe: [WardrobeItem],
    recentMatches: [OutfitHistoryMatch]
  ) -> OutfitRecommendation? {
    guard !wardrobe.isEmpty else {
      return nil
    }

    let wardrobeByCategory = Dictionary(grouping: wardrobe, by: \.category)
    let includesOuterwear = shouldIncludeOuterwear(for: weather)
    let includesAccessory = shouldIncludeAccessory(for: weather)

    let top = bestMatch(
      in: wardrobeByCategory[.top] ?? [],
      temperatureF: weather.temperatureF,
      condition: weather.condition
    )
    let dress = bestMatch(
      in: wardrobeByCategory[.dress] ?? [],
      temperatureF: weather.temperatureF,
      condition: weather.condition
    )
    let bottom = bestMatch(
      in: wardrobeByCategory[.bottom] ?? [],
      temperatureF: weather.temperatureF,
      condition: weather.condition
    )
    let shoes = bestMatch(
      in: wardrobeByCategory[.shoes] ?? [],
      temperatureF: weather.temperatureF,
      condition: weather.condition
    )
    let outerwear =
      includesOuterwear
      ? bestMatch(
        in: wardrobeByCategory[.outerwear] ?? [],
        temperatureF: weather.temperatureF,
        condition: weather.condition)
      : nil
    let accessory =
      includesAccessory
      ? bestMatch(
        in: wardrobeByCategory[.accessory] ?? [],
        temperatureF: weather.temperatureF,
        condition: weather.condition)
      : nil

    var items: [WardrobeItem] = []
    if let dress {
      items.append(dress)
    } else {
      if let top {
        items.append(top)
      }
      if let bottom {
        items.append(bottom)
      }
    }
    if let outerwear {
      items.append(outerwear)
    }
    if let shoes {
      items.append(shoes)
    }
    if let accessory {
      items.append(accessory)
    }

    guard !items.isEmpty else {
      return nil
    }

    let title: String
    if weather.temperatureF <= 45 {
      title = "Cold-weather layering"
    } else if weather.temperatureF >= 78 {
      title = "Warm-weather fit"
    } else {
      title = "Balanced outfit"
    }

    var reason = "\(weather.temperatureF)° and \(weather.condition.title.lowercased()) call for "
    reason += includesOuterwear ? "layers" : "a lighter mix"
    if let previous = recentMatches.first {
      reason +=
        ". Similar weather match: \(previous.assignment.date.formatted(date: .abbreviated, time: .omitted))."
    } else {
      reason += "."
    }
    return OutfitRecommendation(title: title, reason: reason, items: items)
  }

  func historyMatches(
    for temperatureF: Int,
    assignments: [OutfitAssignment],
    wardrobe: [WardrobeItem]
  ) -> [OutfitHistoryMatch] {
    historyMatches(
      for: temperatureF,
      assignments: assignments,
      wardrobeByID: Dictionary(uniqueKeysWithValues: wardrobe.map { ($0.id, $0) })
    )
  }

  func historyMatches(
    for temperatureF: Int,
    assignments: [OutfitAssignment],
    wardrobeByID: [UUID: WardrobeItem]
  ) -> [OutfitHistoryMatch] {
    assignments
      .compactMap { assignment -> OutfitHistoryMatch? in
        guard
          let recordedTemperature = assignment.recordedTemperatureF
            ?? assignment.weatherSnapshot?.temperatureF
        else {
          return nil
        }
        let items = assignment.itemIDs.compactMap { itemID in
          wardrobeByID[itemID]
        }
        guard !items.isEmpty else {
          return nil
        }
        return OutfitHistoryMatch(
          assignment: assignment,
          items: items,
          temperatureDelta: abs(recordedTemperature - temperatureF)
        )
      }
      .filter { $0.temperatureDelta <= 8 }
      .sorted {
        if $0.temperatureDelta == $1.temperatureDelta {
          return $0.assignment.date > $1.assignment.date
        }
        return $0.temperatureDelta < $1.temperatureDelta
      }
  }

  private func bestMatch(
    in candidates: [WardrobeItem],
    temperatureF: Int,
    condition: WeatherCondition
  ) -> WardrobeItem? {
    candidates.min {
      rank(item: $0, temperatureF: temperatureF, condition: condition)
        < rank(item: $1, temperatureF: temperatureF, condition: condition)
    }
  }

  private func rank(item: WardrobeItem, temperatureF: Int, condition: WeatherCondition) -> Int {
    var score = item.preferredTemperature.distance(to: temperatureF) * 10
    score += abs(item.warmthLevel.score - warmthTarget(for: temperatureF, condition: condition)) * 4
    if condition == .rain || condition == .drizzle {
      if item.category == .outerwear || item.category == .shoes {
        score -= 6
      }
    }
    return score
  }

  private func warmthTarget(for temperatureF: Int, condition: WeatherCondition) -> Int {
    let base: Int
    switch temperatureF {
    case ..<32:
      base = 4
    case ..<45:
      base = 3
    case ..<60:
      base = 2
    case ..<75:
      base = 1
    default:
      base = 0
    }
    if condition == .rain || condition == .drizzle || condition == .windy {
      return min(base + 1, 4)
    }
    return base
  }

  private func shouldIncludeOuterwear(for weather: WeatherSnapshot) -> Bool {
    weather.temperatureF <= 62
      || [.rain, .drizzle, .snow, .thunderstorm, .windy].contains(weather.condition)
  }

  private func shouldIncludeAccessory(for weather: WeatherSnapshot) -> Bool {
    weather.temperatureF <= 50 || [.rain, .drizzle, .snow].contains(weather.condition)
  }
}
