import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
  private let wardrobeRepository: any WardrobeRepository
  private let weatherClient: any WeatherClient
  private let catalogImporter: any CatalogImporting
  private let outfitPlanner: OutfitPlanningService
  private let catalogURLClassifier = CatalogImportURLClassifier()
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
  var persistenceRevision = 0
  var recommendation: OutfitRecommendation?
  var historyMatches: [OutfitHistoryMatch] = []

  var selectedImportPreset: ImportPreset = .productPage
  var importURLText: String
  var importedItems: [ImportedCatalogItem] = []
  var selectedImportedItemIDs: Set<UUID> = []
  var importError: String?
  var importNotice: String?
  var isImportingCatalog = false

  private var wardrobeByID: [UUID: WardrobeItem] = [:]
  private var assignmentsByDate: [Date: OutfitAssignment] = [:]
  private var lastWornDatesByItemID: [UUID: Date] = [:]

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
    self.importURLText = ""
  }

  func bootstrap() async {
    guard !hasBootstrapped else {
      return
    }
    hasBootstrapped = true
    async let wardrobeLoad: Void = loadWardrobe()
    async let weatherRefresh: Void = refreshWeather()
    _ = await (wardrobeLoad, weatherRefresh)
  }

  func loadWardrobe() async {
    do {
      let database = try await wardrobeRepository.load()
      if database == .empty {
        // Seed sample data in memory without blocking launch on a non-essential disk write.
        apply(database: ExampleData.seededDatabase())
      } else {
        apply(database: database)
      }
      persistenceMessage = nil
    } catch {
      let seeded = ExampleData.seededDatabase()
      apply(database: seeded)
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
    refreshPlanningDerivedState()
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
    replaceWardrobeState(
      items: sortWardrobeItems(wardrobeItems + [item]),
      assignments: assignments
    )
    await persist()
  }

  func addImportedItem(_ item: ImportedCatalogItem) async {
    await addImportedItems([item])
  }

  func removeWardrobeItem(_ item: WardrobeItem) async {
    let updatedItems = wardrobeItems.filter { $0.id != item.id }
    let updatedAssignments = assignments.compactMap { assignment in
      var updated = assignment
      updated.itemIDs.removeAll { $0 == item.id }
      let isMeaningful =
        !updated.itemIDs.isEmpty
        || !updated.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || updated.recordedTemperatureF != nil
        || updated.weatherSnapshot != nil
      return isMeaningful ? updated : nil
    }
    replaceWardrobeState(
      items: updatedItems,
      assignments: sortAssignments(updatedAssignments)
    )
    await persist()
  }

  func assignment(on date: Date) -> OutfitAssignment? {
    assignmentsByDate[calendar.startOfDay(for: date)]
  }

  func items(for assignment: OutfitAssignment) -> [WardrobeItem] {
    assignment.itemIDs.compactMap { itemID in
      wardrobeByID[itemID]
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

    var updatedAssignments = assignments

    if itemIDs.isEmpty && trimmedNote.isEmpty && effectiveTemperature == nil
      && weatherSnapshot == nil
    {
      updatedAssignments.removeAll { calendar.isDate($0.date, inSameDayAs: normalizedDate) }
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
      updatedAssignments.removeAll { calendar.isDate($0.date, inSameDayAs: normalizedDate) }
      updatedAssignments.append(updatedAssignment)
    }
    replaceWardrobeState(
      items: wardrobeItems,
      assignments: sortAssignments(updatedAssignments)
    )
    await persist()
  }

  func importCatalog() async {
    let trimmedURL = importURLText.trimmingCharacters(in: .whitespacesAndNewlines)
    let readiness = catalogURLClassifier.classify(text: trimmedURL)
    guard readiness.canImport, let url = URL(string: trimmedURL) else {
      importError = readiness.message
      importedItems = []
      selectedImportedItemIDs = []
      importNotice = nil
      return
    }

    isImportingCatalog = true
    defer { isImportingCatalog = false }
    do {
      let items = try await catalogImporter.importCatalog(from: url)
      importedItems = items
      selectedImportedItemIDs = Set(
        items
          .filter { !importedItemAlreadyExists($0) }
          .map(\.id)
      )
      importError = nil
      importNotice = importSuccessMessage(for: items)
    } catch {
      importedItems = []
      selectedImportedItemIDs = []
      importError = error.localizedDescription
      importNotice = nil
    }
  }

  func adoptPreset(_ preset: ImportPreset) {
    selectedImportPreset = preset
    importError = nil
    importNotice = nil
    importedItems = []
    selectedImportedItemIDs = []
  }

  func updateImportURLText(_ text: String) {
    importURLText = text
    importError = nil
    importNotice = nil
    importedItems = []
    selectedImportedItemIDs = []
  }

  func toggleImportedItemSelection(_ item: ImportedCatalogItem) {
    guard !importedItemAlreadyExists(item) else {
      return
    }

    if selectedImportedItemIDs.contains(item.id) {
      selectedImportedItemIDs.remove(item.id)
    } else {
      selectedImportedItemIDs.insert(item.id)
    }
  }

  func clearImportedPreview() {
    importedItems = []
    selectedImportedItemIDs = []
    importError = nil
    importNotice = nil
  }

  func addSelectedImportedItems() async {
    let selectedItems = importedItems.filter { selectedImportedItemIDs.contains($0.id) }
    await addImportedItems(selectedItems)
  }

  var importReadiness: CatalogImportReadiness {
    catalogURLClassifier.classify(text: importURLText)
  }

  var canStartImport: Bool {
    !isImportingCatalog && importReadiness.canImport
  }

  var selectedImportedItemCount: Int {
    importedItems
      .filter { selectedImportedItemIDs.contains($0.id) && !importedItemAlreadyExists($0) }
      .count
  }

  var importedExistingItemCount: Int {
    importedItems.filter(importedItemAlreadyExists).count
  }

  var importedNewItemCount: Int {
    importedItems.count - importedExistingItemCount
  }

  func importedItemAlreadyExists(_ item: ImportedCatalogItem) -> Bool {
    wardrobeImportKeys.contains(importKey(for: item))
  }

  func importedItemIsSelected(_ item: ImportedCatalogItem) -> Bool {
    selectedImportedItemIDs.contains(item.id)
  }

  func lastWornDate(for item: WardrobeItem) -> Date? {
    lastWornDatesByItemID[item.id]
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
      persistenceRevision += 1
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

  private func apply(database: WardrobeDatabase) {
    replaceWardrobeState(
      items: sortWardrobeItems(database.items),
      assignments: sortAssignments(database.assignments)
    )
  }

  private func replaceWardrobeState(items: [WardrobeItem], assignments: [OutfitAssignment]) {
    wardrobeItems = items
    self.assignments = assignments
    refreshWardrobeDerivedState()
  }

  private func refreshWardrobeDerivedState() {
    wardrobeByID = Dictionary(uniqueKeysWithValues: wardrobeItems.map { ($0.id, $0) })
    assignmentsByDate = assignments.reduce(into: [:]) { indexedAssignments, assignment in
      indexedAssignments[calendar.startOfDay(for: assignment.date)] = assignment
    }
    lastWornDatesByItemID = assignments.reduce(into: [:]) { datesByItemID, assignment in
      for itemID in assignment.itemIDs {
        if let lastRecordedDate = datesByItemID[itemID], lastRecordedDate >= assignment.date {
          continue
        }
        datesByItemID[itemID] = assignment.date
      }
    }
    refreshPlanningDerivedState()
  }

  private func addImportedItems(_ items: [ImportedCatalogItem]) async {
    let dedupedItems = uniqueImportedItems(items).filter { !importedItemAlreadyExists($0) }
    guard !dedupedItems.isEmpty else {
      importNotice = "Everything selected is already in your wardrobe."
      selectedImportedItemIDs = Set(
        importedItems.filter { !importedItemAlreadyExists($0) }.map(\.id)
      )
      return
    }

    let newWardrobeItems = dedupedItems.map(WardrobeItem.from(imported:))
    replaceWardrobeState(
      items: sortWardrobeItems(wardrobeItems + newWardrobeItems),
      assignments: assignments
    )
    selectedImportedItemIDs = Set(
      importedItems.filter { !importedItemAlreadyExists($0) }.map(\.id)
    )
    importNotice =
      dedupedItems.count == 1
      ? "Added \(dedupedItems[0].title) to your wardrobe."
      : "Added \(dedupedItems.count) pieces to your wardrobe."
    await persist()
  }

  private var wardrobeImportKeys: Set<String> {
    Set(wardrobeItems.map(importKey(for:)))
  }

  private func importKey(for item: ImportedCatalogItem) -> String {
    "\(item.sourceURL.normalizedCatalogKey)|\(normalizedImportTitle(item.title))|\(item.brand.lowercased())"
  }

  private func importKey(for item: WardrobeItem) -> String {
    let sourceKey = item.sourceURL?.normalizedCatalogKey ?? "manual"
    return "\(sourceKey)|\(normalizedImportTitle(item.name))|\(item.brand.lowercased())"
  }

  private func normalizedImportTitle(_ title: String) -> String {
    title
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func uniqueImportedItems(_ items: [ImportedCatalogItem]) -> [ImportedCatalogItem] {
    var seenKeys: Set<String> = []
    return items.filter { item in
      let key = importKey(for: item)
      if seenKeys.contains(key) {
        return false
      }
      seenKeys.insert(key)
      return true
    }
  }

  private func importSuccessMessage(for items: [ImportedCatalogItem]) -> String {
    let newCount = items.filter { !importedItemAlreadyExists($0) }.count
    if items.isEmpty {
      return "No wardrobe-ready pieces found."
    }
    if newCount == 0 {
      return "Everything on this page is already in your wardrobe."
    }
    if newCount == items.count {
      return "Imported \(items.count) wardrobe-ready pieces."
    }
    return "Imported \(items.count) pieces. \(newCount) are new to your wardrobe."
  }

  private func refreshPlanningDerivedState() {
    guard let currentWeather = weatherReport?.current else {
      recommendation = nil
      historyMatches = []
      return
    }
    let matchingHistory = outfitPlanner.historyMatches(
      for: currentWeather.temperatureF,
      assignments: assignments,
      wardrobeByID: wardrobeByID
    )
    historyMatches = matchingHistory
    recommendation = outfitPlanner.recommend(
      for: currentWeather,
      wardrobe: wardrobeItems,
      recentMatches: matchingHistory
    )
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

  static func sampleWeather(
    for location: LocationSummary,
    referenceDate: Date = .now
  ) -> WeatherReport {
    let now = referenceDate
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
