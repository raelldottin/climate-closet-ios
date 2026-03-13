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

struct WardrobeAddToolbarButton: View {
  @State private var isPresentingAddSheet = false

  let onSave: (WardrobeItem) -> Void

  var body: some View {
    Button {
      isPresentingAddSheet = true
    } label: {
      Image(systemName: "plus")
    }
    .tint(.white)
    .accessibilityLabel("Add clothing")
    .sheet(isPresented: $isPresentingAddSheet) {
      AddWardrobeItemSheet(onSave: onSave)
    }
  }
}

struct AddWardrobeItemSheet: View {
  @Environment(\.dismiss) private var dismiss

  @State private var name = ""
  @State private var brand = ""
  @State private var category: ClothingCategory = .top
  @State private var warmthLevel: WarmthLevel = .light
  @State private var minimumTemperature = 55
  @State private var maximumTemperature = 75
  @State private var color = ""
  @State private var notes = ""
  @State private var tags = ""
  @State private var sourceURL = ""
  @State private var imageURL = ""

  let onSave: (WardrobeItem) -> Void

  var body: some View {
    NavigationStack {
      Form {
        Section("Identity") {
          TextField("Name", text: $name)
          TextField("Brand", text: $brand)
          TextField("Color", text: $color)
        }

        Section("Fit") {
          Picker("Category", selection: $category) {
            ForEach(ClothingCategory.allCases) { item in
              Text(item.title).tag(item)
            }
          }
          Picker("Warmth", selection: $warmthLevel) {
            ForEach(WarmthLevel.allCases) { level in
              Text(level.title).tag(level)
            }
          }
          Stepper("Minimum \(minimumTemperature)°", value: $minimumTemperature, in: -10...110)
          Stepper("Maximum \(maximumTemperature)°", value: $maximumTemperature, in: -10...110)
        }

        Section("Notes") {
          TextField("Notes", text: $notes, axis: .vertical)
          TextField("Tags comma separated", text: $tags)
        }

        Section("Links") {
          TextField("Source URL", text: $sourceURL)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
          TextField("Image URL", text: $imageURL)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
        }
      }
      .navigationTitle("Add Clothing")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(
              WardrobeItem(
                name: name,
                brand: brand.isEmpty ? "Unspecified" : brand,
                category: category,
                warmthLevel: warmthLevel,
                preferredTemperature: TemperatureRange(
                  minimumF: min(minimumTemperature, maximumTemperature),
                  maximumF: max(minimumTemperature, maximumTemperature)
                ),
                color: color.isEmpty ? "Unspecified" : color,
                notes: notes,
                tags:
                  tags
                  .split(separator: ",")
                  .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                  .filter { !$0.isEmpty },
                sourceURL: URL(string: sourceURL),
                imageURL: URL(string: imageURL)
              )
            )
            dismiss()
          }
          .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
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
