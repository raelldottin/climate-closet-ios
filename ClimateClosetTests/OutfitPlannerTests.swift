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

@MainActor
final class AppModelTests: XCTestCase {
  func testDerivedStateCachesArePopulatedFromLoadedWardrobeAndWeather() async {
    let database = ExampleData.seededDatabase()
    let weather = ExampleData.sampleWeather(for: ExampleData.defaultLocation)
    let model = AppModel(
      wardrobeRepository: InMemoryWardrobeRepository(database: database),
      weatherClient: WeatherClientStub(forecastHandler: { _ in weather }),
      catalogImporter: CatalogImporterStub()
    )

    await model.loadWardrobe()

    XCTAssertEqual(
      model.assignment(on: database.assignments[0].date)?.id,
      database.assignments[0].id
    )
    XCTAssertEqual(
      model.items(for: database.assignments[0]).count,
      database.assignments[0].itemIDs.count
    )
    XCTAssertEqual(model.lastWornDate(for: database.items[0]), database.assignments[0].date)

    await model.refreshWeather()

    XCTAssertNotNil(model.recommendation)
    XCTAssertFalse(model.historyMatches.isEmpty)
  }

  func testRemovingWardrobeItemRefreshesLookupCaches() async {
    let database = ExampleData.seededDatabase()
    let weather = ExampleData.sampleWeather(for: ExampleData.defaultLocation)
    let model = AppModel(
      wardrobeRepository: InMemoryWardrobeRepository(database: database),
      weatherClient: WeatherClientStub(forecastHandler: { _ in weather }),
      catalogImporter: CatalogImporterStub()
    )
    let removedItem = database.items[0]

    await model.loadWardrobe()
    await model.refreshWeather()
    await model.removeWardrobeItem(removedItem)

    XCTAssertFalse(model.wardrobeItems.contains(where: { $0.id == removedItem.id }))
    XCTAssertNil(model.lastWornDate(for: removedItem))
    XCTAssertFalse(model.assignments.contains(where: { $0.itemIDs.contains(removedItem.id) }))
    XCTAssertFalse(
      model.historyMatches.contains(where: { match in
        match.items.contains(where: { $0.id == removedItem.id })
      })
    )
  }

  func testLoadingEmptyWardrobeDoesNotBlockOnInitialSeedSave() async {
    let repository = RecordingWardrobeRepository(database: .empty)
    let model = AppModel(
      wardrobeRepository: repository,
      weatherClient: WeatherClientStub(
        forecastHandler: { _ in ExampleData.sampleWeather(for: ExampleData.defaultLocation) }
      ),
      catalogImporter: CatalogImporterStub()
    )

    await model.loadWardrobe()

    XCTAssertFalse(model.wardrobeItems.isEmpty)
    let saveCallCount = await repository.saveCallCount
    XCTAssertEqual(saveCallCount, 0)
  }
}
