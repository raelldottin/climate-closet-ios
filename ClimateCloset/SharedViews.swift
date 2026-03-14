import SwiftUI

enum ClimateUI {
  enum Layout {
    static let screenInset: CGFloat = 20
    static let sectionSpacing: CGFloat = 18
    static let cardSpacing: CGFloat = 16
    static let rowSpacing: CGFloat = 12
    static let compactSpacing: CGFloat = 8
    static let cardPadding: CGFloat = 20
    static let tilePadding: CGFloat = 14
    static let chipHorizontalPadding: CGFloat = 10
    static let chipVerticalPadding: CGFloat = 6
    static let inputHorizontalPadding: CGFloat = 14
    static let inputVerticalPadding: CGFloat = 12
  }

  enum Radius {
    static let card: CGFloat = 28
    static let tile: CGFloat = 22
    static let control: CGFloat = 18
    static let badge: CGFloat = 12
    static let capsule: CGFloat = 999
  }

  enum Palette {
    static let accent = Color(red: 0.95, green: 0.66, blue: 0.30)
    static let accentStrong = Color(red: 0.95, green: 0.74, blue: 0.44)
    static let success = Color(red: 0.64, green: 0.90, blue: 0.78)
    static let warning = Color(red: 0.95, green: 0.76, blue: 0.40)
    static let critical = Color(red: 0.95, green: 0.63, blue: 0.46)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.78)
    static let textMuted = Color.white.opacity(0.66)
    static let surface = Color.white.opacity(0.10)
    static let surfaceStrong = Color.white.opacity(0.16)
    static let surfaceSelected = Color.white.opacity(0.22)
    static let inputSurface = Color.black.opacity(0.20)
    static let toolbarSurface = Color.black.opacity(0.26)
    static let border = Color.white.opacity(0.18)
    static let borderStrong = Color.white.opacity(0.30)
    static let shadow = Color.black.opacity(0.14)
  }
}

enum ClimateTextRole {
  case display
  case displayValue
  case title
  case sectionTitle
  case sectionSubtitle
  case body
  case bodyStrong
  case detail
  case detailStrong
  case caption
  case captionStrong
  case eyebrow
  case button

  var font: Font {
    switch self {
    case .display:
      .system(.largeTitle, design: .rounded, weight: .bold)
    case .displayValue:
      .system(size: 78, weight: .thin, design: .rounded)
    case .title:
      .system(.title2, design: .rounded, weight: .semibold)
    case .sectionTitle:
      .system(.title3, design: .rounded, weight: .semibold)
    case .sectionSubtitle:
      .system(.subheadline, design: .rounded)
    case .body:
      .system(.subheadline, design: .rounded)
    case .bodyStrong:
      .system(.headline, design: .rounded, weight: .semibold)
    case .detail:
      .system(.footnote, design: .rounded)
    case .detailStrong:
      .system(.caption, design: .rounded, weight: .medium)
    case .caption:
      .system(.caption, design: .rounded)
    case .captionStrong:
      .system(.caption, design: .rounded, weight: .semibold)
    case .eyebrow:
      .system(.caption2, design: .rounded, weight: .bold)
    case .button:
      .system(.headline, design: .rounded, weight: .semibold)
    }
  }
}

extension View {
  func climateText(_ role: ClimateTextRole, color: Color = ClimateUI.Palette.textPrimary)
    -> some View
  {
    font(role.font)
      .foregroundStyle(color)
  }

  func climateInputField() -> some View {
    modifier(ClimateInputFieldModifier())
  }
}

private struct ClimateInputFieldModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .climateText(.body)
      .padding(.horizontal, ClimateUI.Layout.inputHorizontalPadding)
      .padding(.vertical, ClimateUI.Layout.inputVerticalPadding)
      .background(
        RoundedRectangle(cornerRadius: ClimateUI.Radius.control, style: .continuous)
          .fill(ClimateUI.Palette.inputSurface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: ClimateUI.Radius.control, style: .continuous)
          .stroke(ClimateUI.Palette.border, lineWidth: 1)
      )
      .tint(ClimateUI.Palette.accent)
  }
}

enum ClimateActionButtonKind {
  case primary
  case secondary
}

struct ClimateActionButtonStyle: ButtonStyle {
  let kind: ClimateActionButtonKind

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .climateText(.button)
      .padding(.horizontal, 18)
      .padding(.vertical, 12)
      .frame(minHeight: 50)
      .background(background(isPressed: configuration.isPressed))
      .overlay(border(isPressed: configuration.isPressed))
      .clipShape(RoundedRectangle(cornerRadius: ClimateUI.Radius.control, style: .continuous))
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
      .opacity(configuration.isPressed ? 0.94 : 1)
      .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
  }

  @ViewBuilder
  private func background(isPressed: Bool) -> some View {
    switch kind {
    case .primary:
      RoundedRectangle(cornerRadius: ClimateUI.Radius.control, style: .continuous)
        .fill(
          LinearGradient(
            colors: [
              ClimateUI.Palette.accentStrong.opacity(isPressed ? 0.88 : 1),
              ClimateUI.Palette.accent.opacity(isPressed ? 0.94 : 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    case .secondary:
      RoundedRectangle(cornerRadius: ClimateUI.Radius.control, style: .continuous)
        .fill(ClimateUI.Palette.surfaceStrong.opacity(isPressed ? 0.9 : 1))
    }
  }

  @ViewBuilder
  private func border(isPressed: Bool) -> some View {
    switch kind {
    case .primary:
      RoundedRectangle(cornerRadius: ClimateUI.Radius.control, style: .continuous)
        .stroke(ClimateUI.Palette.accentStrong.opacity(isPressed ? 0.45 : 0.60), lineWidth: 1)
    case .secondary:
      RoundedRectangle(cornerRadius: ClimateUI.Radius.control, style: .continuous)
        .stroke(ClimateUI.Palette.borderStrong.opacity(isPressed ? 0.85 : 1), lineWidth: 1)
    }
  }
}

struct ClimateIconButtonStyle: ButtonStyle {
  let tint: Color

  init(tint: Color = ClimateUI.Palette.textPrimary) {
    self.tint = tint
  }

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(tint)
      .frame(width: 38, height: 38)
      .background(
        RoundedRectangle(cornerRadius: ClimateUI.Radius.control, style: .continuous)
          .fill(ClimateUI.Palette.surfaceStrong.opacity(configuration.isPressed ? 0.92 : 1))
      )
      .overlay(
        RoundedRectangle(cornerRadius: ClimateUI.Radius.control, style: .continuous)
          .stroke(ClimateUI.Palette.border, lineWidth: 1)
      )
      .shadow(color: ClimateUI.Palette.shadow.opacity(0.7), radius: 8, x: 0, y: 4)
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
  }
}

struct GlassTile<Content: View>: View {
  private let content: Content
  private let cornerRadius: CGFloat
  private let padding: CGFloat
  private let fill: Color

  init(
    cornerRadius: CGFloat = ClimateUI.Radius.tile,
    padding: CGFloat = ClimateUI.Layout.tilePadding,
    fill: Color = ClimateUI.Palette.surface,
    @ViewBuilder content: () -> Content
  ) {
    self.cornerRadius = cornerRadius
    self.padding = padding
    self.fill = fill
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: ClimateUI.Layout.compactSpacing) {
      content
    }
    .padding(padding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(fill)
    )
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .stroke(ClimateUI.Palette.border, lineWidth: 1)
    )
  }
}

struct ClimateIconBadge: View {
  let systemImage: String
  let tint: Color

  init(systemImage: String, tint: Color = ClimateUI.Palette.surfaceSelected) {
    self.systemImage = systemImage
    self.tint = tint
  }

  var body: some View {
    Image(systemName: systemImage)
      .font(.system(size: 16, weight: .semibold))
      .foregroundStyle(ClimateUI.Palette.textPrimary)
      .frame(width: 34, height: 34)
      .background(
        RoundedRectangle(cornerRadius: ClimateUI.Radius.badge, style: .continuous)
          .fill(tint)
      )
  }
}

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
    VStack(alignment: .leading, spacing: ClimateUI.Layout.cardSpacing) {
      content
    }
    .padding(ClimateUI.Layout.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: ClimateUI.Radius.card, style: .continuous)
        .fill(ClimateUI.Palette.surfaceStrong)
    )
    .overlay(
      RoundedRectangle(cornerRadius: ClimateUI.Radius.card, style: .continuous)
        .stroke(ClimateUI.Palette.border, lineWidth: 1)
    )
    .shadow(color: ClimateUI.Palette.shadow, radius: 14, x: 0, y: 8)
  }
}

struct SectionTitle: View {
  var title: String
  var subtitle: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .climateText(.sectionTitle)
      if let subtitle {
        Text(subtitle)
          .climateText(.sectionSubtitle, color: ClimateUI.Palette.textSecondary)
      }
    }
  }
}

struct CapsuleTag: View {
  var text: String
  var tint: Color = ClimateUI.Palette.surfaceStrong

  var body: some View {
    Text(text)
      .climateText(.captionStrong)
      .padding(.horizontal, ClimateUI.Layout.chipHorizontalPadding)
      .padding(.vertical, ClimateUI.Layout.chipVerticalPadding)
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
        .foregroundStyle(ClimateUI.Palette.textPrimary.opacity(0.9))
      Text(title)
        .climateText(.bodyStrong)
      Text(message)
        .climateText(.body, color: ClimateUI.Palette.textSecondary)
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
      ToolbarIconLabel(systemImage: "plus")
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Add clothing")
    .accessibilityIdentifier("action.add-wardrobe-item")
    .sheet(isPresented: $isPresentingAddSheet) {
      AddWardrobeItemSheet(onSave: onSave)
    }
  }
}

struct ToolbarIconButton: View {
  let systemImage: String
  let accessibilityLabel: String
  let accessibilityIdentifier: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ToolbarIconLabel(systemImage: systemImage)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityIdentifier(accessibilityIdentifier)
  }
}

private struct ToolbarIconLabel: View {
  let systemImage: String

  var body: some View {
    Image(systemName: systemImage)
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(ClimateUI.Palette.textPrimary)
      .frame(width: 32, height: 32)
      .background(
        Circle()
          .fill(ClimateUI.Palette.toolbarSurface)
      )
      .overlay(
        Circle()
          .stroke(ClimateUI.Palette.border, lineWidth: 1)
      )
      .contentShape(Circle())
      .shadow(color: ClimateUI.Palette.shadow.opacity(1.2), radius: 6, x: 0, y: 3)
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
            .accessibilityIdentifier("field.add-wardrobe-item.name")
          TextField("Brand", text: $brand)
            .accessibilityIdentifier("field.add-wardrobe-item.brand")
          TextField("Color", text: $color)
            .accessibilityIdentifier("field.add-wardrobe-item.color")
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
            .accessibilityIdentifier("field.add-wardrobe-item.notes")
          TextField("Tags comma separated", text: $tags)
            .accessibilityIdentifier("field.add-wardrobe-item.tags")
        }

        Section("Links") {
          TextField("Source URL", text: $sourceURL)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            .accessibilityIdentifier("field.add-wardrobe-item.source-url")
          TextField("Image URL", text: $imageURL)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            .accessibilityIdentifier("field.add-wardrobe-item.image-url")
        }
      }
      .accessibilityIdentifier("sheet.add-wardrobe-item")
      .navigationTitle("Add Clothing")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
          .accessibilityIdentifier("action.add-wardrobe-item.cancel")
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
          .accessibilityIdentifier("action.add-wardrobe-item.save")
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
