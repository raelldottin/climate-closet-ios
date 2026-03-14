import Observation
import SwiftUI

struct WeatherDashboardView: View {
  @Bindable var model: AppModel

  var body: some View {
    ZStack {
      AtmosphericBackground()
      ScrollView {
        LazyVStack(spacing: ClimateUI.Layout.sectionSpacing) {
          searchCard

          if let weatherReport = model.weatherReport {
            currentWeatherCard(report: weatherReport)
            hourlyForecastCard(report: weatherReport)
            dailyForecastCard(report: weatherReport)

            if let recommendation = model.recommendation {
              recommendationCard(recommendation)
            }

            historyCard

            if let persistenceMessage = model.persistenceMessage {
              EmptyStateCard(
                title: "Persistence notice",
                message: persistenceMessage,
                symbol: "externaldrive.badge.exclamationmark"
              )
            }
          } else if model.isLoadingWeather {
            GlassCard {
              ProgressView()
                .tint(ClimateUI.Palette.textPrimary)
              Text("Loading forecast...")
                .climateText(.bodyStrong)
            }
          } else {
            EmptyStateCard(
              title: "No forecast loaded",
              message: model.weatherError ?? "Search for a city to load a forecast.",
              symbol: "exclamationmark.triangle"
            )
          }
        }
        .padding(.horizontal, ClimateUI.Layout.screenInset)
        .padding(.vertical, ClimateUI.Layout.screenInset)
      }
      .accessibilityIdentifier("screen.weather")
      .refreshable {
        await model.refreshWeather()
      }
    }
    .navigationTitle("Climate Closet")
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        ToolbarIconButton(
          systemImage: "arrow.clockwise",
          accessibilityLabel: "Refresh forecast",
          accessibilityIdentifier: "action.refresh-weather"
        ) {
          Task { await model.refreshWeather() }
        }

        WardrobeAddToolbarButton { item in
          Task { await model.addWardrobeItem(item) }
        }
      }
    }
  }

  private var searchCard: some View {
    GlassCard {
      SectionTitle(
        title: "Forecast lookup",
        subtitle: "Search a city, then compare it against your closet history."
      )

      HStack(alignment: .center, spacing: ClimateUI.Layout.rowSpacing) {
        TextField("Search city", text: $model.locationQuery)
          .climateInputField()
          .onSubmit {
            Task { await model.searchLocations() }
          }

        Button("Find") {
          Task { await model.searchLocations() }
        }
        .buttonStyle(ClimateActionButtonStyle(kind: .primary))
      }

      if !model.searchResults.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: ClimateUI.Layout.compactSpacing) {
            ForEach(model.searchResults) { location in
              Button {
                Task { await model.chooseLocation(location) }
              } label: {
                CapsuleTag(text: location.displayName, tint: ClimateUI.Palette.surfaceSelected)
              }
            }
          }
        }
      }

      if let weatherError = model.weatherError {
        Text(weatherError)
          .climateText(.detail, color: ClimateUI.Palette.textSecondary)
      }
    }
  }

  private func currentWeatherCard(report: WeatherReport) -> some View {
    GlassCard {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          Text(report.locationName)
            .climateText(.display)
          Text(report.current.condition.title)
            .climateText(.sectionTitle, color: ClimateUI.Palette.textSecondary)
        }
        Spacer()
        Image(systemName: report.current.condition.systemImageName)
          .font(.system(size: 34, weight: .medium))
          .foregroundStyle(report.current.condition.tintColor)
      }

      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text("\(report.current.temperatureF)°")
          .climateText(.displayValue)
        VStack(alignment: .leading, spacing: 6) {
          Text("Feels like \(report.current.apparentTemperatureF)°")
            .climateText(.bodyStrong, color: ClimateUI.Palette.textSecondary)
          Text("Humidity \(report.current.humidityPercent)%")
            .climateText(.body, color: ClimateUI.Palette.textSecondary)
        }
      }

      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        WeatherMetricView(title: "Wind", value: "\(report.current.windSpeedMPH) mph", icon: "wind")
        WeatherMetricView(
          title: "Precip", value: "\(report.current.precipitationChance)%", icon: "cloud.rain")
        WeatherMetricView(
          title: "High",
          value: "\(report.daily.first?.highTemperatureF ?? report.current.temperatureF)°",
          icon: "thermometer.high")
        WeatherMetricView(
          title: "Low",
          value: "\(report.daily.first?.lowTemperatureF ?? report.current.temperatureF)°",
          icon: "thermometer.low")
      }
    }
  }

  private func hourlyForecastCard(report: WeatherReport) -> some View {
    GlassCard {
      SectionTitle(title: "Next 12 hours")
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: ClimateUI.Layout.rowSpacing) {
          ForEach(report.hourly) { hour in
            GlassTile(cornerRadius: 20, padding: 12) {
              Text(hour.time, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                .climateText(.detailStrong, color: ClimateUI.Palette.textSecondary)
              Image(systemName: hour.condition.systemImageName)
                .foregroundStyle(hour.condition.tintColor)
              Text("\(hour.temperatureF)°")
                .climateText(.bodyStrong)
              Text("\(hour.precipitationChance)%")
                .climateText(.eyebrow, color: ClimateUI.Palette.textSecondary)
            }
          }
        }
      }
    }
  }

  private func dailyForecastCard(report: WeatherReport) -> some View {
    GlassCard {
      SectionTitle(title: "Next 7 days")
      VStack(spacing: ClimateUI.Layout.rowSpacing) {
        ForEach(report.daily) { day in
          GlassTile(cornerRadius: 20) {
            HStack {
              Text(day.date, format: .dateTime.weekday(.wide))
                .climateText(.bodyStrong)
              Spacer()
              Image(systemName: day.condition.systemImageName)
                .foregroundStyle(day.condition.tintColor)
              Text("\(day.lowTemperatureF)°")
                .climateText(.body, color: ClimateUI.Palette.textSecondary)
              Text("\(day.highTemperatureF)°")
                .climateText(.bodyStrong)
            }
          }
        }
      }
    }
  }

  private func recommendationCard(_ recommendation: OutfitRecommendation) -> some View {
    GlassCard {
      SectionTitle(title: recommendation.title, subtitle: recommendation.reason)
      HStack(spacing: ClimateUI.Layout.compactSpacing) {
        ForEach(recommendation.items) { item in
          GlassTile(cornerRadius: 18, padding: 12) {
            Image(systemName: item.category.systemImageName)
              .foregroundStyle(ClimateUI.Palette.textPrimary)
            Text(item.name)
              .climateText(.bodyStrong)
            Text(item.preferredTemperature.label)
              .climateText(.eyebrow, color: ClimateUI.Palette.textSecondary)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var historyCard: some View {
    let historyMatches = model.historyMatches
    if historyMatches.isEmpty {
      EmptyStateCard(
        title: "No nearby outfit history yet",
        message: "Plan or log outfits with temperatures to build your personal weather memory.",
        symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90"
      )
    } else {
      GlassCard {
        SectionTitle(title: "Similar weather history")
        VStack(spacing: ClimateUI.Layout.rowSpacing) {
          ForEach(historyMatches.prefix(3)) { match in
            GlassTile(cornerRadius: 18) {
              HStack {
                Text(match.assignment.date, format: .dateTime.month().day())
                  .climateText(.bodyStrong)
                Spacer()
                Text("Δ \(match.temperatureDelta)°")
                  .climateText(.captionStrong, color: ClimateUI.Palette.textSecondary)
              }
              Text(match.items.map(\.name).joined(separator: ", "))
                .climateText(.body, color: ClimateUI.Palette.textSecondary)
            }
          }
        }
      }
    }
  }
}

private struct WeatherMetricView: View {
  var title: String
  var value: String
  var icon: String

  var body: some View {
    GlassTile(cornerRadius: 20) {
      Label(title, systemImage: icon)
        .climateText(.detailStrong, color: ClimateUI.Palette.textSecondary)
      Text(value)
        .climateText(.bodyStrong)
    }
  }
}
