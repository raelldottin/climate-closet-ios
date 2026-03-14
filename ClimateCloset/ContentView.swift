import Observation
import SwiftUI

private enum AppTab: Hashable {
  case weather
  case wardrobe
  case planner
  case importCatalog
}

struct ContentView: View {
  @Bindable var model: AppModel
  @State private var selectedTab: AppTab = .weather
  @State private var loadedTabs: Set<AppTab> = [.weather]

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack {
        WeatherDashboardView(model: model)
      }
      .tabItem {
        Label("Weather", systemImage: "cloud.sun.fill")
      }
      .tag(AppTab.weather)

      NavigationStack {
        if loadedTabs.contains(.wardrobe) {
          WardrobeView(model: model)
        } else {
          Color.clear
        }
      }
      .tabItem {
        Label("Wardrobe", systemImage: "tshirt.fill")
      }
      .tag(AppTab.wardrobe)

      NavigationStack {
        if loadedTabs.contains(.planner) {
          ScheduleView(model: model)
        } else {
          Color.clear
        }
      }
      .tabItem {
        Label("Planner", systemImage: "calendar")
      }
      .tag(AppTab.planner)

      NavigationStack {
        if loadedTabs.contains(.importCatalog) {
          ImportCatalogView(model: model)
        } else {
          Color.clear
        }
      }
      .tabItem {
        Label("Import", systemImage: "square.and.arrow.down")
      }
      .tag(AppTab.importCatalog)
    }
    .onChange(of: selectedTab) { _, newValue in
      loadedTabs.insert(newValue)
    }
    .task {
      await Task.yield()
      await model.bootstrap()
    }
    .tint(ClimateUI.Palette.accent)
  }
}
