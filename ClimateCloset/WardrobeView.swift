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
        VStack(spacing: 18) {
          GlassCard {
            SectionTitle(
              title: "Your wardrobe",
              subtitle:
                "Track every clothing piece and remember what worked for each temperature band."
            )
            TextField("Search wardrobe", text: $searchText)
              .textFieldStyle(.roundedBorder)

            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 10) {
                Button {
                  selectedCategory = nil
                } label: {
                  CapsuleTag(
                    text: "All",
                    tint: selectedCategory == nil ? .orange.opacity(0.55) : .white.opacity(0.16)
                  )
                }
                ForEach(ClothingCategory.allCases) { category in
                  Button {
                    selectedCategory = category
                  } label: {
                    CapsuleTag(
                      text: category.title,
                      tint: selectedCategory == category
                        ? .orange.opacity(0.55) : .white.opacity(0.16)
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
                HStack(alignment: .top) {
                  VStack(alignment: .leading, spacing: 10) {
                    HStack {
                      Image(systemName: item.category.systemImageName)
                        .foregroundStyle(.white)
                      Text(item.name)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                    }
                    Text(item.brand)
                      .font(.system(.subheadline, design: .rounded))
                      .foregroundStyle(.white.opacity(0.72))
                    HStack {
                      CapsuleTag(text: item.category.title)
                      CapsuleTag(text: item.preferredTemperature.label)
                      CapsuleTag(text: item.warmthLevel.title)
                    }
                    if !item.notes.isEmpty {
                      Text(item.notes)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                    }
                    if let lastWornDate = model.lastWornDate(for: item) {
                      Text(
                        "Last assigned \(lastWornDate.formatted(date: .abbreviated, time: .omitted))"
                      )
                      .font(.system(.caption, design: .rounded, weight: .medium))
                      .foregroundStyle(.white.opacity(0.70))
                    }
                  }
                  Spacer()
                  Button(role: .destructive) {
                    Task { await model.removeWardrobeItem(item) }
                  } label: {
                    Image(systemName: "trash")
                      .foregroundStyle(.white.opacity(0.84))
                  }
                }
              }
            }
          }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
      }
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
