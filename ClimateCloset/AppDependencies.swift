import Foundation

struct AppDependencies {
  let wardrobeRepository: any WardrobeRepository
  let weatherClient: any WeatherClient
  let catalogImporter: any CatalogImporting
  let initialLocation: LocationSummary

  static func make(processInfo: ProcessInfo = .processInfo) -> AppDependencies {
    let environment = processInfo.environment
    if processInfo.arguments.contains("--benchmark-mode") {
      return benchmark(environment: environment)
    }

    let wardrobeRepository: any WardrobeRepository
    if let storePath = environment["CLIMATE_CLOSET_STORE_PATH"], !storePath.isEmpty {
      wardrobeRepository = JSONWardrobeRepository(storeURL: URL(fileURLWithPath: storePath))
    } else {
      wardrobeRepository = JSONWardrobeRepository.live()
    }

    return AppDependencies(
      wardrobeRepository: wardrobeRepository,
      weatherClient: OpenMeteoWeatherClient(httpClient: URLSessionHTTPClient()),
      catalogImporter: HTMLCatalogImporter(httpClient: URLSessionHTTPClient()),
      initialLocation: ExampleData.defaultLocation
    )
  }

  private static func benchmark(environment: [String: String]) -> AppDependencies {
    let referenceDate = Date()
    let wardrobeRepository: any WardrobeRepository

    if environment.flag(named: "CLIMATE_CLOSET_BENCHMARK_PERSISTED_STORE") {
      let storeProfile = environment["CLIMATE_CLOSET_STORE_PROFILE"] ?? "ui"
      let storeURL = benchmarkStoreURL(profile: storeProfile)
      if environment.flag(named: "CLIMATE_CLOSET_PRESEED_BENCHMARK_STORE") {
        BenchmarkFixtures.writeStore(
          at: storeURL,
          referenceDate: referenceDate,
          overwriteExisting: environment.flag(named: "CLIMATE_CLOSET_OVERWRITE_BENCHMARK_STORE")
        )
      }
      wardrobeRepository = JSONWardrobeRepository(storeURL: storeURL)
    } else {
      wardrobeRepository = InMemoryWardrobeRepository(
        database: BenchmarkFixtures.database(referenceDate: referenceDate))
    }

    return AppDependencies(
      wardrobeRepository: wardrobeRepository,
      weatherClient: BenchmarkWeatherClient(referenceDate: referenceDate),
      catalogImporter: BenchmarkCatalogImporter(),
      initialLocation: BenchmarkFixtures.location
    )
  }

  private static func benchmarkStoreURL(profile: String) -> URL {
    let fileManager = FileManager.default
    let baseDirectory =
      fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())

    return
      baseDirectory
      .appendingPathComponent("ClimateCloset", isDirectory: true)
      .appendingPathComponent("Benchmarks", isDirectory: true)
      .appendingPathComponent("\(profile).json")
  }
}

private struct BenchmarkWeatherClient: WeatherClient {
  let referenceDate: Date

  func searchLocations(matching query: String) async throws -> [LocationSummary] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else {
      return []
    }
    return [BenchmarkFixtures.location]
  }

  func forecast(for location: LocationSummary) async throws -> WeatherReport {
    ExampleData.sampleWeather(for: location, referenceDate: referenceDate)
  }
}

private struct BenchmarkCatalogImporter: CatalogImporting {
  func importCatalog(from url: URL) async throws -> [ImportedCatalogItem] {
    BenchmarkFixtures.catalogItems(for: url)
  }
}

private enum BenchmarkFixtures {
  static let location = ExampleData.defaultLocation

  static func database(referenceDate: Date = .now) -> WardrobeDatabase {
    let createdAt = Date(timeIntervalSince1970: floor(referenceDate.timeIntervalSince1970))
    let categories = ClothingCategory.allCases
    let warmthLevels = WarmthLevel.allCases
    let colors = ["Black", "Navy", "Camel", "Olive", "White", "Stone", "Gray", "Blue"]
    let brands = [
      "TOM FORD", "J.Crew", "Levi's", "Banana Republic", "Theory", "COS", "A.P.C.", "Buck Mason",
    ]

    var items: [WardrobeItem] = [
      WardrobeItem(
        name: "A Benchmark Scarf",
        brand: "TOM FORD",
        category: .accessory,
        warmthLevel: .light,
        preferredTemperature: TemperatureRange(minimumF: 28, maximumF: 68),
        color: "Black",
        notes: "Anchor item for planner and save benchmarks",
        tags: ["benchmark", "anchor"],
        sourceURL: URL(string: "https://www.tomford.com"),
        imageURL: nil,
        createdAt: createdAt
      )
    ]

    for index in 0..<191 {
      let category = categories[index % categories.count]
      let warmthLevel = warmthLevels[index % warmthLevels.count]
      let range = TemperatureRange.defaultFor(category: category, warmth: warmthLevel)
      items.append(
        WardrobeItem(
          name: benchmarkItemName(category: category, index: index),
          brand: brands[index % brands.count],
          category: category,
          warmthLevel: warmthLevel,
          preferredTemperature: range,
          color: colors[index % colors.count],
          notes: index.isMultiple(of: 3) ? "Benchmark fixture item \(index)" : "",
          tags: ["benchmark", category.title.lowercased()],
          sourceURL: URL(string: "https://www.tomford.com"),
          imageURL: nil,
          createdAt: createdAt
        )
      )
    }

    let assignments = (1...90).compactMap { offset -> OutfitAssignment? in
      guard
        let date = Calendar.autoupdatingCurrent.date(
          byAdding: .day,
          value: -offset,
          to: referenceDate
        )
      else {
        return nil
      }
      let itemCount = 3 + (offset % 3)
      let startIndex = (offset * 5) % max(items.count - itemCount, 1)
      let itemIDs = Array(items[startIndex..<(startIndex + itemCount)]).map(\.id)
      return OutfitAssignment(
        date: date.startOfDay(),
        itemIDs: itemIDs,
        note: "Benchmark log \(offset)",
        recordedTemperatureF: 38 + (offset % 35),
        recordedCondition: WeatherCondition.allCases[offset % WeatherCondition.allCases.count],
        weatherSnapshot: nil
      )
    }

    return WardrobeDatabase(items: items, assignments: assignments)
  }

  static func writeStore(at storeURL: URL, referenceDate: Date, overwriteExisting: Bool) {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: storeURL.path), !overwriteExisting {
      return
    }

    do {
      try fileManager.createDirectory(
        at: storeURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try JSONEncoder.climateCloset.encode(database(referenceDate: referenceDate))
      try data.write(to: storeURL, options: [.atomic])
    } catch {
      // Fall back to the repository's normal empty-store behavior if pre-seeding fails.
    }
  }

  static func catalogItems(for url: URL) -> [ImportedCatalogItem] {
    let sourceURL =
      URL(
        string: url.absoluteString.hasSuffix("/") ? url.absoluteString : "\(url.absoluteString)/"
      )
      ?? url

    return [
      ImportedCatalogItem(
        title: "Tom Ford Buckley Sunglasses",
        brand: "TOM FORD",
        priceText: "$480.00",
        categoryHint: "Accessory",
        imageURL: nil,
        sourceURL: sourceURL.appendingPathComponent("buckley-sunglasses"),
        notes: "Benchmark fixture import item"
      ),
      ImportedCatalogItem(
        title: "Tom Ford Suede Trucker Jacket",
        brand: "TOM FORD",
        priceText: "$5,990.00",
        categoryHint: "Outerwear",
        imageURL: nil,
        sourceURL: sourceURL.appendingPathComponent("suede-trucker-jacket"),
        notes: "Benchmark fixture import item"
      ),
      ImportedCatalogItem(
        title: "Tom Ford Silk Camp Shirt",
        brand: "TOM FORD",
        priceText: "$1,490.00",
        categoryHint: "Top",
        imageURL: nil,
        sourceURL: sourceURL.appendingPathComponent("silk-camp-shirt"),
        notes: "Benchmark fixture import item"
      ),
      ImportedCatalogItem(
        title: "Tom Ford Cashmere Crewneck",
        brand: "TOM FORD",
        priceText: "$1,790.00",
        categoryHint: "Top",
        imageURL: nil,
        sourceURL: sourceURL.appendingPathComponent("cashmere-crewneck"),
        notes: "Benchmark fixture import item"
      ),
      ImportedCatalogItem(
        title: "Tom Ford Wool Trousers",
        brand: "TOM FORD",
        priceText: "$1,290.00",
        categoryHint: "Bottom",
        imageURL: nil,
        sourceURL: sourceURL.appendingPathComponent("wool-trousers"),
        notes: "Benchmark fixture import item"
      ),
      ImportedCatalogItem(
        title: "Tom Ford Leather Chelsea Boot",
        brand: "TOM FORD",
        priceText: "$1,750.00",
        categoryHint: "Shoes",
        imageURL: nil,
        sourceURL: sourceURL.appendingPathComponent("leather-chelsea-boot"),
        notes: "Benchmark fixture import item"
      ),
      ImportedCatalogItem(
        title: "Tom Ford Technical Track Pant",
        brand: "TOM FORD",
        priceText: "$890.00",
        categoryHint: "Activewear",
        imageURL: nil,
        sourceURL: sourceURL.appendingPathComponent("technical-track-pant"),
        notes: "Benchmark fixture import item"
      ),
      ImportedCatalogItem(
        title: "Tom Ford Cotton Poplin Pajama Set",
        brand: "TOM FORD",
        priceText: "$1,150.00",
        categoryHint: "Sleepwear",
        imageURL: nil,
        sourceURL: sourceURL.appendingPathComponent("cotton-poplin-pajama-set"),
        notes: "Benchmark fixture import item"
      ),
    ]
  }

  private static func benchmarkItemName(category: ClothingCategory, index: Int) -> String {
    let paddedIndex = String(format: "%03d", index)
    switch category {
    case .accessory:
      return "Benchmark Accessory \(paddedIndex)"
    case .activewear:
      return "Benchmark Activewear \(paddedIndex)"
    case .bottom:
      return "Benchmark Bottom \(paddedIndex)"
    case .dress:
      return "Benchmark Dress \(paddedIndex)"
    case .outerwear:
      return "Benchmark Outerwear \(paddedIndex)"
    case .shoes:
      return "Benchmark Shoes \(paddedIndex)"
    case .sleepwear:
      return "Benchmark Sleepwear \(paddedIndex)"
    case .top:
      return "Benchmark Top \(paddedIndex)"
    }
  }
}

extension [String: String] {
  fileprivate func flag(named key: String) -> Bool {
    guard let rawValue = self[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    else {
      return false
    }
    return rawValue == "1" || rawValue == "true" || rawValue == "yes"
  }
}
