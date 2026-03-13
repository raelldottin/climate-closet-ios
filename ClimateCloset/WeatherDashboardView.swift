import Observation
import SwiftUI

struct WeatherDashboardView: View {
  @Bindable var model: AppModel

  var body: some View {
    ZStack {
      AtmosphericBackground()
      ScrollView {
        VStack(spacing: 18) {
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
                .tint(.white)
              Text("Loading forecast...")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
            }
          } else {
            EmptyStateCard(
              title: "No forecast loaded",
              message: model.weatherError ?? "Search for a city to load a forecast.",
              symbol: "exclamationmark.triangle"
            )
          }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
      }
      .refreshable {
        await model.refreshWeather()
      }
    }
    .navigationTitle("Climate Closet")
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button {
          Task { await model.refreshWeather() }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .tint(.white)

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

      HStack(spacing: 12) {
        TextField("Search city", text: $model.locationQuery)
          .textFieldStyle(.roundedBorder)
          .onSubmit {
            Task { await model.searchLocations() }
          }

        Button("Find") {
          Task { await model.searchLocations() }
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
      }

      if !model.searchResults.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(model.searchResults) { location in
              Button {
                Task { await model.chooseLocation(location) }
              } label: {
                CapsuleTag(text: location.displayName, tint: .white.opacity(0.20))
              }
            }
          }
        }
      }

      if let weatherError = model.weatherError {
        Text(weatherError)
          .font(.system(.footnote, design: .rounded))
          .foregroundStyle(.white.opacity(0.74))
      }
    }
  }

  private func currentWeatherCard(report: WeatherReport) -> some View {
    GlassCard {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          Text(report.locationName)
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
          Text(report.current.condition.title)
            .font(.system(.title3, design: .rounded, weight: .medium))
            .foregroundStyle(.white.opacity(0.82))
        }
        Spacer()
        Image(systemName: report.current.condition.systemImageName)
          .font(.system(size: 34, weight: .medium))
          .foregroundStyle(report.current.condition.tintColor)
      }

      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text("\(report.current.temperatureF)°")
          .font(.system(size: 78, weight: .thin, design: .rounded))
          .foregroundStyle(.white)
        VStack(alignment: .leading, spacing: 6) {
          Text("Feels like \(report.current.apparentTemperatureF)°")
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(.white.opacity(0.82))
          Text("Humidity \(report.current.humidityPercent)%")
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(.white.opacity(0.74))
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
        HStack(spacing: 12) {
          ForEach(report.hourly) { hour in
            VStack(spacing: 10) {
              Text(hour.time, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
              Image(systemName: hour.condition.systemImageName)
                .foregroundStyle(hour.condition.tintColor)
              Text("\(hour.temperatureF)°")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
              Text("\(hour.precipitationChance)%")
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
              RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.10))
            )
          }
        }
      }
    }
  }

  private func dailyForecastCard(report: WeatherReport) -> some View {
    GlassCard {
      SectionTitle(title: "Next 7 days")
      VStack(spacing: 12) {
        ForEach(report.daily) { day in
          HStack {
            Text(day.date, format: .dateTime.weekday(.wide))
              .font(.system(.headline, design: .rounded, weight: .medium))
              .foregroundStyle(.white)
            Spacer()
            Image(systemName: day.condition.systemImageName)
              .foregroundStyle(day.condition.tintColor)
            Text("\(day.lowTemperatureF)°")
              .foregroundStyle(.white.opacity(0.75))
            Text("\(day.highTemperatureF)°")
              .font(.system(.headline, design: .rounded, weight: .semibold))
              .foregroundStyle(.white)
          }
        }
      }
    }
  }

  private func recommendationCard(_ recommendation: OutfitRecommendation) -> some View {
    GlassCard {
      SectionTitle(title: recommendation.title, subtitle: recommendation.reason)
      HStack(spacing: 10) {
        ForEach(recommendation.items) { item in
          VStack(alignment: .leading, spacing: 8) {
            Image(systemName: item.category.systemImageName)
              .foregroundStyle(.white)
            Text(item.name)
              .font(.system(.subheadline, design: .rounded, weight: .semibold))
              .foregroundStyle(.white)
            Text(item.preferredTemperature.label)
              .font(.system(.caption2, design: .rounded))
              .foregroundStyle(.white.opacity(0.72))
          }
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .fill(.white.opacity(0.10))
          )
        }
      }
    }
  }

  private var historyCard: some View {
    Group {
      if model.historyMatches.isEmpty {
        EmptyStateCard(
          title: "No nearby outfit history yet",
          message: "Plan or log outfits with temperatures to build your personal weather memory.",
          symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        )
      } else {
        GlassCard {
          SectionTitle(title: "Similar weather history")
          VStack(spacing: 12) {
            ForEach(model.historyMatches.prefix(3)) { match in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(match.assignment.date, format: .dateTime.month().day())
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                  Spacer()
                  Text("Δ \(match.temperatureDelta)°")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.76))
                }
                Text(match.items.map(\.name).joined(separator: ", "))
                  .font(.system(.subheadline, design: .rounded))
                  .foregroundStyle(.white.opacity(0.78))
              }
              .padding(14)
              .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .fill(.white.opacity(0.10))
              )
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
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: icon)
        .font(.system(.caption, design: .rounded, weight: .medium))
        .foregroundStyle(.white.opacity(0.70))
      Text(value)
        .font(.system(.headline, design: .rounded, weight: .semibold))
        .foregroundStyle(.white)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(.white.opacity(0.10))
    )
  }
}
