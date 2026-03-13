import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
  private let wardrobeRepository: any WardrobeRepository
  private let weatherClient: any WeatherClient
  private let catalogImporter: any CatalogImporting
  private let outfitPlanner: OutfitPlanningService
  private let calendar = Calendar.autoupdatingCurrent
  private var hasBootstrapped = false

  var selectedLocation: LocationSummary
  var locationQuery: String
  var searchResults: [LocationSummary] = []
  var weatherReport: WeatherReport?
  var weatherError: String?
  var isLoadingWeather = false

  var wardrobeItems: [WardrobeItem] = []
  var assignments: [OutfitAssignment] = []
  var persistenceMessage: String?

  var selectedImportPreset: ImportPreset = .hm
  var importURLText: String
  var importedItems: [ImportedCatalogItem] = []
  var importError: String?
  var isImportingCatalog = false

  init(
    wardrobeRepository: any WardrobeRepository,
    weatherClient: any WeatherClient,
    catalogImporter: any CatalogImporting,
    outfitPlanner: OutfitPlanningService = OutfitPlanningService(),
    initialLocation: LocationSummary = ExampleData.defaultLocation
  ) {
    self.wardrobeRepository = wardrobeRepository
    self.weatherClient = weatherClient
    self.catalogImporter = catalogImporter
    self.outfitPlanner = outfitPlanner
    self.selectedLocation = initialLocation
    self.locationQuery = initialLocation.displayName
    self.importURLText = ImportPreset.hm.defaultURL?.absoluteString ?? ""
  }

  func bootstrap() async {
    guard !hasBootstrapped else {
      return
    }
    hasBootstrapped = true
    await loadWardrobe()
    await refreshWeather()
  }

  func loadWardrobe() async {
    do {
      let database = try await wardrobeRepository.load()
      if database == .empty {
        let seeded = ExampleData.seededDatabase()
        wardrobeItems = sortWardrobeItems(seeded.items)
        assignments = sortAssignments(seeded.assignments)
        try await wardrobeRepository.save(seeded)
      } else {
        wardrobeItems = sortWardrobeItems(database.items)
        assignments = sortAssignments(database.assignments)
      }
      persistenceMessage = nil
    } catch {
      let seeded = ExampleData.seededDatabase()
      wardrobeItems = sortWardrobeItems(seeded.items)
      assignments = sortAssignments(seeded.assignments)
      persistenceMessage = "Using sample wardrobe because the local store could not be loaded."
    }
  }

  func refreshWeather() async {
    isLoadingWeather = true
    defer { isLoadingWeather = false }
    do {
      weatherReport = try await weatherClient.forecast(for: selectedLocation)
      weatherError = nil
    } catch {
      weatherError = error.localizedDescription
      if weatherReport == nil {
        weatherReport = ExampleData.sampleWeather(for: selectedLocation)
      }
    }
  }

  func searchLocations() async {
    do {
      searchResults = try await weatherClient.searchLocations(matching: locationQuery)
      if searchResults.isEmpty {
        weatherError = "No matching cities were found."
      } else {
        weatherError = nil
      }
    } catch {
      weatherError = error.localizedDescription
      searchResults = []
    }
  }

  func chooseLocation(_ location: LocationSummary) async {
    selectedLocation = location
    locationQuery = location.displayName
    searchResults = []
    await refreshWeather()
  }

  func addWardrobeItem(_ item: WardrobeItem) async {
    wardrobeItems = sortWardrobeItems(wardrobeItems + [item])
    await persist()
  }

  func addImportedItem(_ item: ImportedCatalogItem) async {
    await addWardrobeItem(.from(imported: item))
  }

  func removeWardrobeItem(_ item: WardrobeItem) async {
    wardrobeItems.removeAll { $0.id == item.id }
    assignments = assignments.compactMap { assignment in
      var updated = assignment
      updated.itemIDs.removeAll { $0 == item.id }
      let isMeaningful =
        !updated.itemIDs.isEmpty
        || !updated.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || updated.recordedTemperatureF != nil
        || updated.weatherSnapshot != nil
      return isMeaningful ? updated : nil
    }
    await persist()
  }

  func assignment(on date: Date) -> OutfitAssignment? {
    assignments.first { calendar.isDate($0.date, inSameDayAs: date) }
  }

  func items(for assignment: OutfitAssignment) -> [WardrobeItem] {
    assignment.itemIDs.compactMap { itemID in
      wardrobeItems.first(where: { $0.id == itemID })
    }
  }

  func saveAssignment(
    for date: Date,
    itemIDs: Set<UUID>,
    note: String,
    recordedTemperatureF: Int?,
    recordedCondition: WeatherCondition?
  ) async {
    let normalizedDate = calendar.startOfDay(for: date)
    let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
    let weatherSnapshot = forecastSnapshot(
      for: normalizedDate,
      explicitTemperature: recordedTemperatureF,
      explicitCondition: recordedCondition
    )
    let effectiveTemperature = recordedTemperatureF ?? weatherSnapshot?.temperatureF
    let effectiveCondition = recordedCondition ?? weatherSnapshot?.condition

    if itemIDs.isEmpty && trimmedNote.isEmpty && effectiveTemperature == nil
      && weatherSnapshot == nil
    {
      assignments.removeAll { calendar.isDate($0.date, inSameDayAs: normalizedDate) }
    } else {
      let updatedAssignment = OutfitAssignment(
        id: assignment(on: normalizedDate)?.id ?? UUID(),
        date: normalizedDate,
        itemIDs: Array(itemIDs),
        note: trimmedNote,
        recordedTemperatureF: effectiveTemperature,
        recordedCondition: effectiveCondition,
        weatherSnapshot: weatherSnapshot
      )
      assignments.removeAll { calendar.isDate($0.date, inSameDayAs: normalizedDate) }
      assignments.append(updatedAssignment)
      assignments = sortAssignments(assignments)
    }
    await persist()
  }

  func importCatalog() async {
    guard let url = URL(string: importURLText.trimmingCharacters(in: .whitespacesAndNewlines))
    else {
      importError = "Enter a valid URL before importing."
      importedItems = []
      return
    }
    isImportingCatalog = true
    defer { isImportingCatalog = false }
    do {
      importedItems = try await catalogImporter.importCatalog(from: url)
      importError = nil
    } catch {
      importedItems = []
      importError = error.localizedDescription
    }
  }

  func adoptPreset(_ preset: ImportPreset) {
    selectedImportPreset = preset
    if let url = preset.defaultURL {
      importURLText = url.absoluteString
    }
    importedItems = []
    importError = nil
  }

  func lastWornDate(for item: WardrobeItem) -> Date? {
    assignments
      .filter { $0.itemIDs.contains(item.id) }
      .map(\.date)
      .max()
  }

  var recommendation: OutfitRecommendation? {
    guard let currentWeather = weatherReport?.current else {
      return nil
    }
    return outfitPlanner.recommend(
      for: currentWeather,
      wardrobe: wardrobeItems,
      assignments: assignments
    )
  }

  var historyMatches: [OutfitHistoryMatch] {
    guard let currentWeather = weatherReport?.current else {
      return []
    }
    return outfitPlanner.historyMatches(
      for: currentWeather.temperatureF,
      assignments: assignments,
      wardrobe: wardrobeItems
    )
  }

  func forecastSnapshot(
    for date: Date,
    explicitTemperature: Int?,
    explicitCondition: WeatherCondition?
  ) -> WeatherSnapshot? {
    if let explicitTemperature {
      return WeatherSnapshot(
        locationName: selectedLocation.displayName,
        temperatureF: explicitTemperature,
        apparentTemperatureF: explicitTemperature,
        condition: explicitCondition ?? .clear,
        humidityPercent: weatherReport?.current.humidityPercent ?? 0,
        windSpeedMPH: weatherReport?.current.windSpeedMPH ?? 0,
        precipitationChance: weatherReport?.current.precipitationChance ?? 0,
        observedAt: date
      )
    }
    guard let weatherReport else {
      return nil
    }
    if calendar.isDate(date, inSameDayAs: weatherReport.current.observedAt) {
      return weatherReport.current
    }
    if let daily = weatherReport.daily.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
    {
      let averageTemperature = Int(
        round(Double(daily.highTemperatureF + daily.lowTemperatureF) / 2))
      return WeatherSnapshot(
        locationName: weatherReport.locationName,
        temperatureF: averageTemperature,
        apparentTemperatureF: averageTemperature,
        condition: explicitCondition ?? daily.condition,
        humidityPercent: weatherReport.current.humidityPercent,
        windSpeedMPH: weatherReport.current.windSpeedMPH,
        precipitationChance: daily.precipitationChance,
        observedAt: date
      )
    }
    return nil
  }

  private func persist() async {
    do {
      try await wardrobeRepository.save(
        WardrobeDatabase(items: wardrobeItems, assignments: assignments))
      persistenceMessage = nil
    } catch {
      persistenceMessage = "Changes could not be saved locally."
    }
  }

  private func sortWardrobeItems(_ items: [WardrobeItem]) -> [WardrobeItem] {
    items.sorted {
      if $0.category == $1.category {
        return $0.name < $1.name
      }
      return $0.category.rawValue < $1.category.rawValue
    }
  }

  private func sortAssignments(_ assignments: [OutfitAssignment]) -> [OutfitAssignment] {
    assignments.sorted { $0.date > $1.date }
  }
}

enum ExampleData {
  static let defaultLocation = LocationSummary(
    name: "Brooklyn",
    admin1: "New York",
    country: "United States",
    countryCode: "US",
    latitude: 40.6782,
    longitude: -73.9442
  )

  static func seededDatabase(referenceDate: Date = .now) -> WardrobeDatabase {
    let createdAt = Date(timeIntervalSince1970: floor(referenceDate.timeIntervalSince1970))
    let items = [
      WardrobeItem(
        name: "Merino Crewneck",
        brand: "J.Crew",
        category: .top,
        warmthLevel: .medium,
        preferredTemperature: TemperatureRange(minimumF: 48, maximumF: 67),
        color: "Heather Gray",
        notes: "Reliable office sweater",
        tags: ["office", "layering"],
        sourceURL: URL(string: "https://www.jcrew.com"),
        imageURL: nil, createdAt: createdAt
      ),
      WardrobeItem(
        name: "Denim Jacket",
        brand: "Levi's",
        category: .outerwear,
        warmthLevel: .light,
        preferredTemperature: TemperatureRange(minimumF: 55, maximumF: 72),
        color: "Indigo",
        notes: "Works best on breezy days",
        tags: ["casual"],
        sourceURL: URL(string: "https://www.levi.com"),
        imageURL: nil, createdAt: createdAt
      ),
      WardrobeItem(
        name: "Oxford Shirt",
        brand: "Banana Republic",
        category: .top,
        warmthLevel: .light,
        preferredTemperature: TemperatureRange(minimumF: 58, maximumF: 80),
        color: "White",
        notes: "Good for warmer commute days",
        tags: ["office", "smart"],
        sourceURL: URL(string: "https://bananarepublic.gap.com"),
        imageURL: nil, createdAt: createdAt
      ),
      WardrobeItem(
        name: "Black Trousers",
        brand: "Banana Republic",
        category: .bottom,
        warmthLevel: .medium,
        preferredTemperature: TemperatureRange(minimumF: 42, maximumF: 78),
        color: "Black",
        notes: "Dressier base layer",
        tags: ["office"],
        sourceURL: URL(string: "https://bananarepublic.gap.com"),
        imageURL: nil, createdAt: createdAt
      ),
      WardrobeItem(
        name: "White Sneakers",
        brand: "H&M",
        category: .shoes,
        warmthLevel: .light,
        preferredTemperature: TemperatureRange(minimumF: 50, maximumF: 90),
        color: "White",
        notes: "Easy everyday pair",
        tags: ["casual"],
        sourceURL: URL(string: "https://www2.hm.com/en_us/index.html"),
        imageURL: nil, createdAt: createdAt
      ),
      WardrobeItem(
        name: "Wool Overcoat",
        brand: "J.Crew",
        category: .outerwear,
        warmthLevel: .insulated,
        preferredTemperature: TemperatureRange(minimumF: 10, maximumF: 42),
        color: "Camel",
        notes: "Winter favorite",
        tags: ["cold weather"],
        sourceURL: URL(string: "https://www.jcrew.com"),
        imageURL: nil, createdAt: createdAt
      ),
      WardrobeItem(
        name: "Silk Scarf",
        brand: "Levi's",
        category: .accessory,
        warmthLevel: .light,
        preferredTemperature: TemperatureRange(minimumF: 40, maximumF: 68),
        color: "Navy",
        notes: "Adds some wind protection",
        tags: ["accessory"],
        sourceURL: URL(string: "https://www.levi.com"),
        imageURL: nil, createdAt: createdAt
      ),
    ]

    let dayOne =
      Calendar.autoupdatingCurrent.date(byAdding: .day, value: -6, to: referenceDate)?.startOfDay()
      ?? referenceDate.startOfDay()
    let dayTwo =
      Calendar.autoupdatingCurrent.date(byAdding: .day, value: -15, to: referenceDate)?.startOfDay()
      ?? referenceDate.startOfDay()
    let dayThree =
      Calendar.autoupdatingCurrent.date(byAdding: .day, value: -24, to: referenceDate)?.startOfDay()
      ?? referenceDate.startOfDay()

    let assignments = [
      OutfitAssignment(
        date: dayOne,
        itemIDs: [items[0].id, items[1].id, items[3].id, items[4].id],
        note: "Cool office commute",
        recordedTemperatureF: 57,
        recordedCondition: .partlyCloudy,
        weatherSnapshot: nil
      ),
      OutfitAssignment(
        date: dayTwo,
        itemIDs: [items[2].id, items[3].id, items[4].id],
        note: "Warmer afternoon meetings",
        recordedTemperatureF: 72,
        recordedCondition: .clear,
        weatherSnapshot: nil
      ),
      OutfitAssignment(
        date: dayThree,
        itemIDs: [items[0].id, items[5].id, items[3].id, items[6].id],
        note: "Cold evening dinner",
        recordedTemperatureF: 38,
        recordedCondition: .windy,
        weatherSnapshot: nil
      ),
    ]
    return WardrobeDatabase(items: items, assignments: assignments)
  }

  static func sampleWeather(for location: LocationSummary) -> WeatherReport {
    let now = Date()
    let hourly = (0..<12).compactMap { offset -> HourlyForecast? in
      guard let date = Calendar.autoupdatingCurrent.date(byAdding: .hour, value: offset, to: now)
      else {
        return nil
      }
      return HourlyForecast(
        time: date,
        temperatureF: 58 + offset / 3,
        precipitationChance: offset % 3 == 0 ? 20 : 10,
        condition: offset < 4 ? .partlyCloudy : .clear
      )
    }
    let daily = (0..<7).compactMap { offset -> DailyForecast? in
      guard let date = Calendar.autoupdatingCurrent.date(byAdding: .day, value: offset, to: now)
      else {
        return nil
      }
      return DailyForecast(
        date: date.startOfDay(),
        highTemperatureF: 60 + offset,
        lowTemperatureF: 47 + offset,
        precipitationChance: offset == 2 ? 50 : 20,
        uvIndex: 3 + offset,
        condition: offset == 2 ? .rain : .partlyCloudy
      )
    }
    let current = WeatherSnapshot(
      locationName: location.displayName,
      temperatureF: 58,
      apparentTemperatureF: 55,
      condition: .partlyCloudy,
      humidityPercent: 62,
      windSpeedMPH: 12,
      precipitationChance: 18,
      observedAt: now
    )
    return WeatherReport(
      locationName: location.displayName,
      current: current,
      hourly: hourly,
      daily: daily
    )
  }
}
