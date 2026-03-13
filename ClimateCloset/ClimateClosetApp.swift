import SwiftUI

@main
struct ClimateClosetApp: App {
  @State private var model = AppModel(
    wardrobeRepository: JSONWardrobeRepository.live(),
    weatherClient: OpenMeteoWeatherClient(httpClient: URLSessionHTTPClient()),
    catalogImporter: HTMLCatalogImporter(httpClient: URLSessionHTTPClient())
  )

  var body: some Scene {
    WindowGroup {
      ContentView(model: model)
    }
  }
}
