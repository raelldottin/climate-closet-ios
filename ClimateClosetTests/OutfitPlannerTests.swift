import XCTest

@testable import ClimateCloset

final class OutfitPlannerTests: XCTestCase {
  func testRecommendationIncludesOuterwearForColdRainyWeather() {
    let planner = OutfitPlanningService()
    let database = ExampleData.seededDatabase()
    let weather = WeatherSnapshot(
      locationName: "Brooklyn, New York",
      temperatureF: 41,
      apparentTemperatureF: 37,
      condition: .rain,
      humidityPercent: 80,
      windSpeedMPH: 18,
      precipitationChance: 90,
      observedAt: .now
    )

    let recommendation = planner.recommend(
      for: weather,
      wardrobe: database.items,
      assignments: database.assignments
    )

    XCTAssertNotNil(recommendation)
    XCTAssertTrue(recommendation?.items.contains(where: { $0.category == .outerwear }) == true)
    XCTAssertTrue(recommendation?.items.contains(where: { $0.category == .shoes }) == true)
  }

  func testHistoryMatchesPreferClosestTemperature() {
    let planner = OutfitPlanningService()
    let database = ExampleData.seededDatabase()

    let matches = planner.historyMatches(
      for: 58,
      assignments: database.assignments,
      wardrobe: database.items
    )

    XCTAssertFalse(matches.isEmpty)
    XCTAssertEqual(matches.first?.temperatureDelta, 1)
    XCTAssertEqual(matches.first?.items.first?.name, "Merino Crewneck")
  }
}
