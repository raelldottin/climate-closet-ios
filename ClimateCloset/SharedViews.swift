import SwiftUI

struct AtmosphericBackground: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.07, green: 0.13, blue: 0.28), Color(red: 0.11, green: 0.25, blue: 0.40),
          Color(red: 0.95, green: 0.74, blue: 0.44),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      RadialGradient(
        colors: [Color.white.opacity(0.28), Color.clear],
        center: .topTrailing,
        startRadius: 20,
        endRadius: 320
      )
      RadialGradient(
        colors: [Color(red: 0.20, green: 0.33, blue: 0.54).opacity(0.8), Color.clear],
        center: .bottomLeading,
        startRadius: 10,
        endRadius: 360
      )
    }
    .ignoresSafeArea()
  }
}

struct GlassCard<Content: View>: View {
  private let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      content
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(.white.opacity(0.16))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(.white.opacity(0.18), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
  }
}

struct SectionTitle: View {
  var title: String
  var subtitle: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.system(.title3, design: .rounded, weight: .semibold))
        .foregroundStyle(.white)
      if let subtitle {
        Text(subtitle)
          .font(.system(.subheadline, design: .rounded))
          .foregroundStyle(.white.opacity(0.72))
      }
    }
  }
}

struct CapsuleTag: View {
  var text: String
  var tint: Color = .white.opacity(0.18)

  var body: some View {
    Text(text)
      .font(.system(.caption, design: .rounded, weight: .semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
        Capsule()
          .fill(tint)
      )
  }
}

struct EmptyStateCard: View {
  var title: String
  var message: String
  var symbol: String

  var body: some View {
    GlassCard {
      Image(systemName: symbol)
        .font(.system(size: 28, weight: .regular))
        .foregroundStyle(.white.opacity(0.9))
      Text(title)
        .font(.system(.headline, design: .rounded, weight: .semibold))
        .foregroundStyle(.white)
      Text(message)
        .font(.system(.subheadline, design: .rounded))
        .foregroundStyle(.white.opacity(0.74))
    }
  }
}

extension WeatherCondition {
  var tintColor: Color {
    switch self {
    case .clear:
      Color.yellow
    case .partlyCloudy:
      Color.orange
    case .cloudy:
      Color.gray
    case .fog:
      Color.mint
    case .drizzle:
      Color.cyan
    case .rain:
      Color.blue
    case .thunderstorm:
      Color.indigo
    case .snow:
      Color.white
    case .windy:
      Color.teal
    }
  }
}
