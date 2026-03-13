import Observation
import SwiftUI

struct ContentView: View {
  @Bindable var model: AppModel

  var body: some View {
    TabView {
      NavigationStack {
        WeatherDashboardView(model: model)
      }
      .tabItem {
        Label("Weather", systemImage: "cloud.sun.fill")
      }

      NavigationStack {
        WardrobeView(model: model)
      }
      .tabItem {
        Label("Wardrobe", systemImage: "tshirt.fill")
      }

      NavigationStack {
        ScheduleView(model: model)
      }
      .tabItem {
        Label("Planner", systemImage: "calendar")
      }

      NavigationStack {
        ImportCatalogView(model: model)
      }
      .tabItem {
        Label("Import", systemImage: "square.and.arrow.down")
      }
    }
    .task {
      await model.bootstrap()
    }
    .tint(.orange)
  }
}
