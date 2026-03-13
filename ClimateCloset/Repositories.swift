import Foundation

protocol WardrobeRepository: Sendable {
  func load() async throws -> WardrobeDatabase
  func save(_ database: WardrobeDatabase) async throws
}

enum WardrobeRepositoryError: LocalizedError {
  case invalidDirectory

  var errorDescription: String? {
    switch self {
    case .invalidDirectory:
      "Unable to create the wardrobe storage directory."
    }
  }
}

actor JSONWardrobeRepository: WardrobeRepository {
  private let storeURL: URL

  init(storeURL: URL) {
    self.storeURL = storeURL
  }

  func load() async throws -> WardrobeDatabase {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: storeURL.path) else {
      return .empty
    }
    let data = try Data(contentsOf: storeURL)
    return try JSONDecoder.climateCloset.decode(WardrobeDatabase.self, from: data)
  }

  func save(_ database: WardrobeDatabase) async throws {
    let fileManager = FileManager.default
    let directoryURL = storeURL.deletingLastPathComponent()
    var isDirectory = ObjCBool(false)
    if !fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) {
      try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
    guard isDirectory.boolValue || fileManager.fileExists(atPath: directoryURL.path) else {
      throw WardrobeRepositoryError.invalidDirectory
    }
    let data = try JSONEncoder.climateCloset.encode(database)
    try data.write(to: storeURL, options: [.atomic])
  }

  static func live() -> JSONWardrobeRepository {
    let fileManager = FileManager.default
    let baseDirectory =
      fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    let storeURL =
      baseDirectory
      .appendingPathComponent("ClimateCloset", isDirectory: true)
      .appendingPathComponent("wardrobe.json")
    return JSONWardrobeRepository(storeURL: storeURL)
  }
}

actor InMemoryWardrobeRepository: WardrobeRepository {
  private var database: WardrobeDatabase

  init(database: WardrobeDatabase = .empty) {
    self.database = database
  }

  func load() async throws -> WardrobeDatabase {
    database
  }

  func save(_ database: WardrobeDatabase) async throws {
    self.database = database
  }
}

extension JSONEncoder {
  static var climateCloset: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }
}

extension JSONDecoder {
  static var climateCloset: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
