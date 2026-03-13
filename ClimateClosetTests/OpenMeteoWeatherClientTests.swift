import Foundation
import XCTest

@testable import ClimateCloset

final class OpenMeteoWeatherClientTests: XCTestCase {
  func testSearchLocationsMapsPayloadIntoLocationSummary() async throws {
    let stub = HTTPClientStub { request in
      let json = """
        {
          "results": [
            {
              "name": "Brooklyn",
              "admin1": "New York",
              "country": "United States",
              "country_code": "US",
              "latitude": 40.6782,
              "longitude": -73.9442
            }
          ]
        }
        """
      let data = Data(json.utf8)
      return (data, makeHTTPResponse(url: request.url!))
    }
    let client = OpenMeteoWeatherClient(httpClient: stub)

    let results = try await client.searchLocations(matching: "Brooklyn")

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first?.displayName, "Brooklyn, New York")
  }

  func testForecastMapsCurrentAndDailyWeather() async throws {
    let stub = HTTPClientStub { request in
      let json = """
        {
          "current": {
            "time": "2026-03-13T12:00",
            "temperature_2m": 58.4,
            "apparent_temperature": 55.2,
            "relative_humidity_2m": 67,
            "weather_code": 2,
            "wind_speed_10m": 13.8
          },
          "hourly": {
            "time": ["2026-03-13T12:00", "2026-03-13T13:00"],
            "temperature_2m": [58.4, 60.1],
            "precipitation_probability": [22, 18],
            "weather_code": [2, 1]
          },
          "daily": {
            "time": ["2026-03-13", "2026-03-14"],
            "temperature_2m_max": [63.2, 61.0],
            "temperature_2m_min": [47.1, 45.0],
            "precipitation_probability_max": [25, 40],
            "uv_index_max": [3.1, 4.0],
            "weather_code": [2, 61]
          }
        }
        """
      let data = Data(json.utf8)
      return (data, makeHTTPResponse(url: request.url!))
    }
    let client = OpenMeteoWeatherClient(httpClient: stub)
    let location = LocationSummary(
      name: "Brooklyn",
      admin1: "New York",
      country: "United States",
      countryCode: "US",
      latitude: 40.6782,
      longitude: -73.9442
    )

    let forecast = try await client.forecast(for: location)

    XCTAssertEqual(forecast.locationName, "Brooklyn, New York")
    XCTAssertEqual(forecast.current.temperatureF, 58)
    XCTAssertEqual(forecast.current.condition, .partlyCloudy)
    XCTAssertEqual(forecast.daily.count, 2)
    XCTAssertEqual(forecast.daily[1].condition, .rain)
  }
}
