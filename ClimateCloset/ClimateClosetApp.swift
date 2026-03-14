import SwiftUI

@main
struct ClimateClosetApp: App {
  @State private var model: AppModel

  init() {
    let dependencies = AppDependencies.make()
    _model = State(
      initialValue: AppModel(
        wardrobeRepository: dependencies.wardrobeRepository,
        weatherClient: dependencies.weatherClient,
        catalogImporter: dependencies.catalogImporter,
        initialLocation: dependencies.initialLocation
      )
    )
  }

  var body: some Scene {
    WindowGroup {
      ContentView(model: model)
    }
  }
}
