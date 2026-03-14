import Foundation
import XCTest

@testable import ClimateCloset

struct HTTPClientStub: HTTPClient {
  let handler: @Sendable (URLRequest) throws -> (Data, URLResponse)

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    try handler(request)
  }
}

struct WeatherClientStub: WeatherClient {
  let searchHandler: @Sendable (String) async throws -> [LocationSummary]
  let forecastHandler: @Sendable (LocationSummary) async throws -> WeatherReport

  init(
    searchHandler: @escaping @Sendable (String) async throws -> [LocationSummary] = { _ in [] },
    forecastHandler: @escaping @Sendable (LocationSummary) async throws -> WeatherReport
  ) {
    self.searchHandler = searchHandler
    self.forecastHandler = forecastHandler
  }

  func searchLocations(matching query: String) async throws -> [LocationSummary] {
    try await searchHandler(query)
  }

  func forecast(for location: LocationSummary) async throws -> WeatherReport {
    try await forecastHandler(location)
  }
}

struct CatalogImporterStub: CatalogImporting {
  let handler: @Sendable (URL) async throws -> [ImportedCatalogItem]

  init(handler: @escaping @Sendable (URL) async throws -> [ImportedCatalogItem] = { _ in [] }) {
    self.handler = handler
  }

  func importCatalog(from url: URL) async throws -> [ImportedCatalogItem] {
    try await handler(url)
  }
}

actor RecordingWardrobeRepository: WardrobeRepository {
  private(set) var database: WardrobeDatabase
  private(set) var saveCallCount = 0

  init(database: WardrobeDatabase) {
    self.database = database
  }

  func load() async throws -> WardrobeDatabase {
    database
  }

  func save(_ database: WardrobeDatabase) async throws {
    self.database = database
    saveCallCount += 1
  }
}

func makeHTTPResponse(url: URL, statusCode: Int = 200) -> HTTPURLResponse {
  guard
    let response = HTTPURLResponse(
      url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
  else {
    XCTFail("Unable to create HTTPURLResponse")
    fatalError("Unable to create HTTPURLResponse")
  }
  return response
}
