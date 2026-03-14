import Observation
import SwiftUI

struct WardrobeView: View {
  @Bindable var model: AppModel
  @State private var searchText = ""
  @State private var selectedCategory: ClothingCategory?

  private var filteredItems: [WardrobeItem] {
    model.wardrobeItems.filter { item in
      let matchesSearch =
        searchText.isEmpty
        || item.name.localizedCaseInsensitiveContains(searchText)
        || item.brand.localizedCaseInsensitiveContains(searchText)
        || item.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
      let matchesCategory = selectedCategory == nil || item.category == selectedCategory
      return matchesSearch && matchesCategory
    }
  }

  var body: some View {
    ZStack {
      AtmosphericBackground()
      ScrollView {
        LazyVStack(spacing: ClimateUI.Layout.sectionSpacing) {
          GlassCard {
            SectionHeader(
              title: "Your wardrobe",
              subtitle:
                "Track every clothing piece and remember what worked for each temperature band."
            )
            TextField("Search wardrobe", text: $searchText)
              .climateInputField()
              .accessibilityIdentifier("field.wardrobe.search")

            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: ClimateUI.Layout.compactSpacing) {
                Button {
                  selectedCategory = nil
                } label: {
                  CapsuleTag(
                    text: "All",
                    tint:
                      selectedCategory == nil
                      ? ClimateUI.Palette.accent.opacity(0.62) : ClimateUI.Palette.surfaceStrong
                  )
                }
                ForEach(ClothingCategory.allCases) { category in
                  Button {
                    selectedCategory = category
                  } label: {
                    CapsuleTag(
                      text: category.title,
                      tint:
                        selectedCategory == category
                        ? ClimateUI.Palette.accent.opacity(0.62) : ClimateUI.Palette.surfaceStrong
                    )
                  }
                }
              }
            }
          }

          if filteredItems.isEmpty {
            EmptyStateCard(
              title: "No wardrobe matches",
              message: "Add a clothing item or relax the filters to see more pieces.",
              symbol: "tray"
            )
          } else {
            ForEach(filteredItems) { item in
              GlassCard {
                HStack(alignment: .top, spacing: ClimateUI.Layout.rowSpacing) {
                  VStack(alignment: .leading, spacing: ClimateUI.Layout.mediumSpacing) {
                    HStack {
                      Image(systemName: item.category.systemImageName)
                        .foregroundStyle(ClimateUI.Palette.textPrimary)
                      Text(item.name)
                        .climateText(.bodyStrong)
                    }
                    Text(item.brand)
                      .climateText(.body, color: ClimateUI.Palette.textSecondary)
                    HStack {
                      CapsuleTag(text: item.category.title)
                      CapsuleTag(text: item.preferredTemperature.label)
                      CapsuleTag(text: item.warmthLevel.title)
                    }
                    if !item.notes.isEmpty {
                      Text(item.notes)
                        .climateText(.detail, color: ClimateUI.Palette.textSecondary)
                    }
                    if let lastWornDate = model.lastWornDate(for: item) {
                      Text(
                        "Last assigned \(lastWornDate.formatted(date: .abbreviated, time: .omitted))"
                      )
                      .climateText(.detailStrong, color: ClimateUI.Palette.textSecondary)
                    }
                  }
                  Spacer()
                  Button(role: .destructive) {
                    Task { await model.removeWardrobeItem(item) }
                  } label: {
                    Image(systemName: "trash")
                      .font(.system(size: ClimateUI.Icon.toolbar, weight: .semibold))
                  }
                  .buttonStyle(ClimateIconButtonStyle(tint: ClimateUI.Palette.critical))
                }
              }
            }
          }
        }
        .padding(.horizontal, ClimateUI.Layout.screenInset)
        .padding(.vertical, ClimateUI.Layout.screenInset)
      }
      .accessibilityIdentifier("screen.wardrobe")
    }
    .navigationTitle("Wardrobe")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        WardrobeAddToolbarButton { item in
          Task { await model.addWardrobeItem(item) }
        }
      }
    }
  }
}
