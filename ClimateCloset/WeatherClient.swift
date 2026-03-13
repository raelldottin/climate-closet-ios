import Foundation

protocol HTTPClient: Sendable {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

protocol WeatherClient: Sendable {
  func searchLocations(matching query: String) async throws -> [LocationSummary]
  func forecast(for location: LocationSummary) async throws -> WeatherReport
}

struct URLSessionHTTPClient: HTTPClient {
  var session: URLSession = .shared

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await session.data(for: request)
  }
}

enum WeatherClientError: LocalizedError {
  case invalidResponse
  case emptySearch

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      "Weather data could not be decoded from the remote service."
    case .emptySearch:
      "Enter a city before searching."
    }
  }
}

struct OpenMeteoWeatherClient: WeatherClient {
  private let httpClient: any HTTPClient

  init(httpClient: any HTTPClient) {
    self.httpClient = httpClient
  }

  func searchLocations(matching query: String) async throws -> [LocationSummary] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else {
      throw WeatherClientError.emptySearch
    }
    var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
    components?.queryItems = [
      URLQueryItem(name: "name", value: trimmedQuery),
      URLQueryItem(name: "count", value: "6"),
      URLQueryItem(name: "language", value: "en"),
      URLQueryItem(name: "format", value: "json"),
    ]
    guard let url = components?.url else {
      throw WeatherClientError.invalidResponse
    }
    let request = weatherRequest(for: url)
    let (data, response) = try await httpClient.data(for: request)
    try validate(response: response)
    let jsonDecoder = JSONDecoder()
    let decoded = try jsonDecoder.decode(GeocodingResponse.self, from: data)
    return decoded.results?.map {
      LocationSummary(
        name: $0.name,
        admin1: $0.admin1,
        country: $0.country,
        countryCode: $0.countryCode,
        latitude: $0.latitude,
        longitude: $0.longitude
      )
    } ?? []
  }

  func forecast(for location: LocationSummary) async throws -> WeatherReport {
    var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
    components?.queryItems = [
      URLQueryItem(name: "latitude", value: String(location.latitude)),
      URLQueryItem(name: "longitude", value: String(location.longitude)),
      URLQueryItem(
        name: "current",
        value:
          "temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m"
      ),
      URLQueryItem(
        name: "hourly",
        value: "temperature_2m,precipitation_probability,weather_code"
      ),
      URLQueryItem(
        name: "daily",
        value:
          "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max"
      ),
      URLQueryItem(name: "timezone", value: "auto"),
      URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
      URLQueryItem(name: "wind_speed_unit", value: "mph"),
      URLQueryItem(name: "precipitation_unit", value: "inch"),
    ]
    guard let url = components?.url else {
      throw WeatherClientError.invalidResponse
    }
    let request = weatherRequest(for: url)
    let (data, response) = try await httpClient.data(for: request)
    try validate(response: response)
    let jsonDecoder = JSONDecoder()
    let dateTimeParser = Self.makeDateTimeParser()
    let dayParser = Self.makeDayParser()
    let decoded = try jsonDecoder.decode(ForecastResponse.self, from: data)

    let hourlyForecasts = zip(
      zip(decoded.hourly.time, decoded.hourly.temperature),
      zip(decoded.hourly.precipitationProbability, decoded.hourly.weatherCode)
    )
    .compactMap { left, right -> HourlyForecast? in
      guard let date = dateTimeParser.date(from: left.0) else {
        return nil
      }
      return HourlyForecast(
        time: date,
        temperatureF: Int(left.1.rounded()),
        precipitationChance: right.0,
        condition: mapCondition(code: right.1)
      )
    }

    let dailyForecasts = zip(
      zip(decoded.daily.time, decoded.daily.temperatureMax),
      zip(
        zip(decoded.daily.temperatureMin, decoded.daily.precipitationProbabilityMax),
        zip(decoded.daily.uvIndexMax, decoded.daily.weatherCode)
      )
    )
    .compactMap { left, right -> DailyForecast? in
      guard let date = dayParser.date(from: left.0) else {
        return nil
      }
      return DailyForecast(
        date: date,
        highTemperatureF: Int(left.1.rounded()),
        lowTemperatureF: Int(right.0.0.rounded()),
        precipitationChance: right.0.1,
        uvIndex: Int(right.1.0.rounded()),
        condition: mapCondition(code: right.1.1)
      )
    }

    let currentDate = dateTimeParser.date(from: decoded.current.time) ?? .now
    let currentHourlyMatch =
      hourlyForecasts.first {
        Calendar.autoupdatingCurrent.isDate($0.time, equalTo: currentDate, toGranularity: .hour)
      }
      ?? hourlyForecasts.first
    let locationName = location.displayName
    let current = WeatherSnapshot(
      locationName: locationName,
      temperatureF: Int(decoded.current.temperature.rounded()),
      apparentTemperatureF: Int(decoded.current.apparentTemperature.rounded()),
      condition: mapCondition(code: decoded.current.weatherCode),
      humidityPercent: decoded.current.relativeHumidity,
      windSpeedMPH: Int(decoded.current.windSpeed.rounded()),
      precipitationChance: currentHourlyMatch?.precipitationChance ?? 0,
      observedAt: currentDate
    )
    return WeatherReport(
      locationName: locationName,
      current: current,
      hourly: Array(hourlyForecasts.prefix(12)),
      daily: Array(dailyForecasts.prefix(7))
    )
  }

  private func weatherRequest(for url: URL) -> URLRequest {
    var request = URLRequest(url: url)
    request.timeoutInterval = 20
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("ClimateCloset/1.0", forHTTPHeaderField: "User-Agent")
    return request
  }

  private func validate(response: URLResponse) throws {
    guard let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
      throw WeatherClientError.invalidResponse
    }
  }

  private func mapCondition(code: Int) -> WeatherCondition {
    switch code {
    case 0:
      .clear
    case 1, 2:
      .partlyCloudy
    case 3:
      .cloudy
    case 45, 48:
      .fog
    case 51, 53, 55, 56, 57:
      .drizzle
    case 61, 63, 65, 66, 67, 80, 81, 82:
      .rain
    case 71, 73, 75, 77, 85, 86:
      .snow
    case 95, 96, 99:
      .thunderstorm
    default:
      .windy
    }
  }

  private static func makeDateTimeParser() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }

  private static func makeDayParser() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }
}

private struct GeocodingResponse: Decodable {
  var results: [LocationPayload]?

  struct LocationPayload: Decodable {
    var name: String
    var admin1: String?
    var country: String
    var countryCode: String
    var latitude: Double
    var longitude: Double

    private enum CodingKeys: String, CodingKey {
      case name
      case admin1
      case country
      case countryCode = "country_code"
      case latitude
      case longitude
    }
  }
}

private struct ForecastResponse: Decodable {
  var current: CurrentPayload
  var hourly: HourlyPayload
  var daily: DailyPayload

  struct CurrentPayload: Decodable {
    var time: String
    var temperature: Double
    var apparentTemperature: Double
    var relativeHumidity: Int
    var weatherCode: Int
    var windSpeed: Double

    private enum CodingKeys: String, CodingKey {
      case time
      case temperature = "temperature_2m"
      case apparentTemperature = "apparent_temperature"
      case relativeHumidity = "relative_humidity_2m"
      case weatherCode = "weather_code"
      case windSpeed = "wind_speed_10m"
    }
  }

  struct HourlyPayload: Decodable {
    var time: [String]
    var temperature: [Double]
    var precipitationProbability: [Int]
    var weatherCode: [Int]

    private enum CodingKeys: String, CodingKey {
      case time
      case temperature = "temperature_2m"
      case precipitationProbability = "precipitation_probability"
      case weatherCode = "weather_code"
    }
  }

  struct DailyPayload: Decodable {
    var time: [String]
    var temperatureMax: [Double]
    var temperatureMin: [Double]
    var precipitationProbabilityMax: [Int]
    var uvIndexMax: [Double]
    var weatherCode: [Int]

    private enum CodingKeys: String, CodingKey {
      case time
      case temperatureMax = "temperature_2m_max"
      case temperatureMin = "temperature_2m_min"
      case precipitationProbabilityMax = "precipitation_probability_max"
      case uvIndexMax = "uv_index_max"
      case weatherCode = "weather_code"
    }
  }
}
