import Foundation

enum ClothingCategory: String, CaseIterable, Codable, Identifiable, Sendable {
  case outerwear
  case top
  case bottom
  case dress
  case shoes
  case accessory
  case activewear
  case sleepwear

  var id: Self { self }

  var title: String {
    switch self {
    case .outerwear:
      "Outerwear"
    case .top:
      "Top"
    case .bottom:
      "Bottom"
    case .dress:
      "Dress"
    case .shoes:
      "Shoes"
    case .accessory:
      "Accessory"
    case .activewear:
      "Activewear"
    case .sleepwear:
      "Sleepwear"
    }
  }

  var systemImageName: String {
    switch self {
    case .outerwear:
      "jacket"
    case .top:
      "tshirt"
    case .bottom:
      "figure.walk"
    case .dress:
      "sparkles"
    case .shoes:
      "shoe"
    case .accessory:
      "sunglasses"
    case .activewear:
      "figure.run"
    case .sleepwear:
      "moon.stars"
    }
  }
}

enum WarmthLevel: String, CaseIterable, Codable, Identifiable, Sendable {
  case airy
  case light
  case medium
  case warm
  case insulated

  var id: Self { self }

  var title: String { rawValue.capitalized }

  var score: Int {
    switch self {
    case .airy:
      0
    case .light:
      1
    case .medium:
      2
    case .warm:
      3
    case .insulated:
      4
    }
  }
}

enum WeatherCondition: String, CaseIterable, Codable, Identifiable, Sendable {
  case clear
  case partlyCloudy
  case cloudy
  case fog
  case drizzle
  case rain
  case thunderstorm
  case snow
  case windy

  var id: Self { self }

  var title: String {
    switch self {
    case .clear:
      "Clear"
    case .partlyCloudy:
      "Partly Cloudy"
    case .cloudy:
      "Cloudy"
    case .fog:
      "Fog"
    case .drizzle:
      "Drizzle"
    case .rain:
      "Rain"
    case .thunderstorm:
      "Thunderstorm"
    case .snow:
      "Snow"
    case .windy:
      "Windy"
    }
  }

  var systemImageName: String {
    switch self {
    case .clear:
      "sun.max.fill"
    case .partlyCloudy:
      "cloud.sun.fill"
    case .cloudy:
      "cloud.fill"
    case .fog:
      "cloud.fog.fill"
    case .drizzle:
      "cloud.drizzle.fill"
    case .rain:
      "cloud.rain.fill"
    case .thunderstorm:
      "cloud.bolt.rain.fill"
    case .snow:
      "snowflake"
    case .windy:
      "wind"
    }
  }
}

struct TemperatureRange: Codable, Equatable, Sendable {
  var minimumF: Int
  var maximumF: Int

  func contains(_ temperatureF: Int) -> Bool {
    minimumF...maximumF ~= temperatureF
  }

  func distance(to temperatureF: Int) -> Int {
    if contains(temperatureF) {
      return 0
    }
    if temperatureF < minimumF {
      return minimumF - temperatureF
    }
    return temperatureF - maximumF
  }

  var label: String {
    "\(minimumF)°-\(maximumF)°"
  }
}

struct WardrobeItem: Identifiable, Codable, Equatable, Sendable {
  var id: UUID
  var name: String
  var brand: String
  var category: ClothingCategory
  var warmthLevel: WarmthLevel
  var preferredTemperature: TemperatureRange
  var color: String
  var notes: String
  var tags: [String]
  var sourceURL: URL?
  var imageURL: URL?
  var createdAt: Date

  init(
    id: UUID = UUID(),
    name: String,
    brand: String,
    category: ClothingCategory,
    warmthLevel: WarmthLevel,
    preferredTemperature: TemperatureRange,
    color: String,
    notes: String,
    tags: [String],
    sourceURL: URL?,
    imageURL: URL?,
    createdAt: Date = .now
  ) {
    self.id = id
    self.name = name
    self.brand = brand
    self.category = category
    self.warmthLevel = warmthLevel
    self.preferredTemperature = preferredTemperature
    self.color = color
    self.notes = notes
    self.tags = tags
    self.sourceURL = sourceURL
    self.imageURL = imageURL
    self.createdAt = createdAt
  }
}

struct WeatherSnapshot: Codable, Equatable, Sendable {
  var locationName: String
  var temperatureF: Int
  var apparentTemperatureF: Int
  var condition: WeatherCondition
  var humidityPercent: Int
  var windSpeedMPH: Int
  var precipitationChance: Int
  var observedAt: Date
}

struct OutfitAssignment: Identifiable, Codable, Equatable, Sendable {
  var id: UUID
  var date: Date
  var itemIDs: [UUID]
  var note: String
  var recordedTemperatureF: Int?
  var recordedCondition: WeatherCondition?
  var weatherSnapshot: WeatherSnapshot?

  init(
    id: UUID = UUID(),
    date: Date,
    itemIDs: [UUID],
    note: String,
    recordedTemperatureF: Int?,
    recordedCondition: WeatherCondition?,
    weatherSnapshot: WeatherSnapshot?
  ) {
    self.id = id
    self.date = date
    self.itemIDs = itemIDs
    self.note = note
    self.recordedTemperatureF = recordedTemperatureF
    self.recordedCondition = recordedCondition
    self.weatherSnapshot = weatherSnapshot
  }
}

struct HourlyForecast: Equatable, Sendable, Identifiable {
  var time: Date
  var temperatureF: Int
  var precipitationChance: Int
  var condition: WeatherCondition

  var id: Date { time }
}

struct DailyForecast: Equatable, Sendable, Identifiable {
  var date: Date
  var highTemperatureF: Int
  var lowTemperatureF: Int
  var precipitationChance: Int
  var uvIndex: Int
  var condition: WeatherCondition

  var id: Date { date }
}

struct WeatherReport: Equatable, Sendable {
  var locationName: String
  var current: WeatherSnapshot
  var hourly: [HourlyForecast]
  var daily: [DailyForecast]
}

struct LocationSummary: Equatable, Codable, Sendable, Identifiable {
  var name: String
  var admin1: String?
  var country: String
  var countryCode: String
  var latitude: Double
  var longitude: Double

  var id: String {
    "\(name)-\(latitude)-\(longitude)"
  }

  var displayName: String {
    if let admin1, !admin1.isEmpty {
      return "\(name), \(admin1)"
    }
    return "\(name), \(countryCode)"
  }
}

struct ImportedCatalogItem: Identifiable, Equatable, Sendable {
  var id: UUID
  var title: String
  var brand: String
  var priceText: String?
  var categoryHint: String?
  var imageURL: URL?
  var sourceURL: URL
  var notes: String?

  init(
    id: UUID = UUID(),
    title: String,
    brand: String,
    priceText: String?,
    categoryHint: String?,
    imageURL: URL?,
    sourceURL: URL,
    notes: String?
  ) {
    self.id = id
    self.title = title
    self.brand = brand
    self.priceText = priceText
    self.categoryHint = categoryHint
    self.imageURL = imageURL
    self.sourceURL = sourceURL
    self.notes = notes
  }
}

enum ImportPreset: String, CaseIterable, Identifiable, Sendable {
  case hm
  case levis
  case bananaRepublic
  case jcrew
  case custom

  var id: Self { self }

  var title: String {
    switch self {
    case .hm:
      "H&M"
    case .levis:
      "Levi's"
    case .bananaRepublic:
      "Banana Republic"
    case .jcrew:
      "J.Crew"
    case .custom:
      "Custom"
    }
  }

  var defaultURL: URL? {
    switch self {
    case .hm:
      URL(string: "https://www2.hm.com/en_us/index.html")
    case .levis:
      URL(string: "https://www.levi.com")
    case .bananaRepublic:
      URL(string: "https://bananarepublic.gap.com")
    case .jcrew:
      URL(string: "https://www.jcrew.com")
    case .custom:
      nil
    }
  }

  var helperText: String {
    switch self {
    case .custom:
      "Paste any clothing-site product or category URL. The importer uses best-effort parsing."
    default:
      "Preset loaded. A product or category page usually imports better than a homepage."
    }
  }
}

struct WardrobeDatabase: Codable, Equatable, Sendable {
  var items: [WardrobeItem]
  var assignments: [OutfitAssignment]

  static let empty = WardrobeDatabase(items: [], assignments: [])
}

struct OutfitRecommendation: Equatable, Sendable {
  var title: String
  var reason: String
  var items: [WardrobeItem]
}

struct OutfitHistoryMatch: Equatable, Sendable, Identifiable {
  var assignment: OutfitAssignment
  var items: [WardrobeItem]
  var temperatureDelta: Int

  var id: UUID { assignment.id }
}

extension WardrobeItem {
  static func from(imported item: ImportedCatalogItem) -> WardrobeItem {
    let inferredCategory = ClothingCategory.infer(from: item.categoryHint ?? item.title)
    let warmth = WarmthLevel.defaultFor(category: inferredCategory)
    let preferredRange = TemperatureRange.defaultFor(category: inferredCategory, warmth: warmth)
    return WardrobeItem(
      name: item.title,
      brand: item.brand,
      category: inferredCategory,
      warmthLevel: warmth,
      preferredTemperature: preferredRange,
      color: "Unspecified",
      notes: item.notes ?? "",
      tags: [item.brand, inferredCategory.title],
      sourceURL: item.sourceURL,
      imageURL: item.imageURL
    )
  }
}

extension ClothingCategory {
  static func infer(from text: String) -> ClothingCategory {
    let lowered = text.lowercased()
    if lowered.contains("dress") {
      return .dress
    }
    if lowered.contains("shoe") || lowered.contains("sneaker") || lowered.contains("boot") {
      return .shoes
    }
    if lowered.contains("coat") || lowered.contains("jacket") || lowered.contains("blazer") {
      return .outerwear
    }
    if lowered.contains("jean") || lowered.contains("pant") || lowered.contains("skirt")
      || lowered.contains("short")
    {
      return .bottom
    }
    if lowered.contains("sock") || lowered.contains("hat") || lowered.contains("scarf")
      || lowered.contains("bag")
    {
      return .accessory
    }
    if lowered.contains("active") || lowered.contains("legging") {
      return .activewear
    }
    if lowered.contains("pajama") || lowered.contains("robe") {
      return .sleepwear
    }
    return .top
  }
}

extension WarmthLevel {
  static func defaultFor(category: ClothingCategory) -> WarmthLevel {
    switch category {
    case .outerwear:
      .warm
    case .shoes, .bottom, .dress:
      .medium
    case .accessory:
      .light
    case .activewear:
      .light
    case .sleepwear:
      .airy
    case .top:
      .light
    }
  }
}

extension TemperatureRange {
  static func defaultFor(category: ClothingCategory, warmth: WarmthLevel) -> TemperatureRange {
    switch (category, warmth) {
    case (.outerwear, .insulated):
      TemperatureRange(minimumF: 5, maximumF: 45)
    case (.outerwear, .warm):
      TemperatureRange(minimumF: 30, maximumF: 60)
    case (.outerwear, _):
      TemperatureRange(minimumF: 45, maximumF: 70)
    case (.dress, .airy):
      TemperatureRange(minimumF: 65, maximumF: 95)
    case (.dress, _):
      TemperatureRange(minimumF: 55, maximumF: 85)
    case (.bottom, _):
      TemperatureRange(minimumF: 40, maximumF: 85)
    case (.shoes, _):
      TemperatureRange(minimumF: 35, maximumF: 95)
    case (.accessory, _):
      TemperatureRange(minimumF: 25, maximumF: 75)
    case (.activewear, _):
      TemperatureRange(minimumF: 45, maximumF: 85)
    case (.sleepwear, _):
      TemperatureRange(minimumF: 60, maximumF: 80)
    case (.top, .airy):
      TemperatureRange(minimumF: 68, maximumF: 95)
    case (.top, .light):
      TemperatureRange(minimumF: 58, maximumF: 85)
    case (.top, .medium):
      TemperatureRange(minimumF: 48, maximumF: 72)
    case (.top, .warm):
      TemperatureRange(minimumF: 35, maximumF: 58)
    case (.top, .insulated):
      TemperatureRange(minimumF: 15, maximumF: 42)
    }
  }
}

extension URL {
  var hostDisplayName: String {
    let host = host?.lowercased() ?? absoluteString
    if host.contains("hm.com") {
      return "H&M"
    }
    if host.contains("levi.com") {
      return "Levi's"
    }
    if host.contains("gap.com") {
      return "Banana Republic"
    }
    if host.contains("jcrew.com") {
      return "J.Crew"
    }
    return host.replacingOccurrences(of: "www.", with: "")
  }
}

extension Date {
  func startOfDay(using calendar: Calendar = .autoupdatingCurrent) -> Date {
    calendar.startOfDay(for: self)
  }
}
