import Observation
import SwiftUI

struct WardrobeView: View {
  @Bindable var model: AppModel
  @State private var isPresentingAddSheet = false
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
        Button {
          isPresentingAddSheet = true
        } label: {
          Image(systemName: "plus")
        }
        .tint(.white)
      }
    }
    .sheet(isPresented: $isPresentingAddSheet) {
      AddWardrobeItemSheet { item in
        Task { await model.addWardrobeItem(item) }
      }
    }
  }
}

private struct AddWardrobeItemSheet: View {
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
