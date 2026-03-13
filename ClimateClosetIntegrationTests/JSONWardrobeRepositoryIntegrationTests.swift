import Foundation
import XCTest

@testable import ClimateCloset

final class JSONWardrobeRepositoryIntegrationTests: XCTestCase {
  func testRepositoryRoundTripsWardrobeDatabase() async throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let storeURL = tempDirectory.appendingPathComponent("wardrobe.json")
    let repository = JSONWardrobeRepository(storeURL: storeURL)
    let database = ExampleData.seededDatabase()

    try await repository.save(database)
    let loaded = try await repository.load()

    XCTAssertEqual(loaded, database)
  }

  func testRepositoryOverwritesExistingData() async throws {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let storeURL = tempDirectory.appendingPathComponent("wardrobe.json")
    let repository = JSONWardrobeRepository(storeURL: storeURL)
    let first = ExampleData.seededDatabase(referenceDate: .now)
    let second = WardrobeDatabase(items: Array(first.items.prefix(2)), assignments: [])

    try await repository.save(first)
    try await repository.save(second)
    let loaded = try await repository.load()

    XCTAssertEqual(loaded.items.count, 2)
    XCTAssertTrue(loaded.assignments.isEmpty)
  }
}
