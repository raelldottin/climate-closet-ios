import Observation
import SwiftUI

struct ImportCatalogView: View {
  @Bindable var model: AppModel

  var body: some View {
    ZStack {
      AtmosphericBackground()
      ScrollView {
        VStack(spacing: 18) {
          GlassCard {
            SectionTitle(
              title: "Catalog importer",
              subtitle:
                "Use the preset storefronts or paste a clothing-site URL. Product and category pages usually work best."
            )

            Picker(
              "Preset",
              selection: Binding(
                get: { model.selectedImportPreset },
                set: { model.adoptPreset($0) }
              )
            ) {
              ForEach(ImportPreset.allCases) { preset in
                Text(preset.title).tag(preset)
              }
            }
            .pickerStyle(.segmented)

            TextField("Paste a storefront URL", text: $model.importURLText)
              .textFieldStyle(.roundedBorder)
              .textInputAutocapitalization(.never)
              .keyboardType(.URL)

            Text(model.selectedImportPreset.helperText)
              .font(.system(.footnote, design: .rounded))
              .foregroundStyle(.white.opacity(0.72))

            Button {
              Task { await model.importCatalog() }
            } label: {
              HStack {
                if model.isImportingCatalog {
                  ProgressView()
                    .tint(.white)
                }
                Text(model.isImportingCatalog ? "Importing..." : "Import Catalog")
              }
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            if let importError = model.importError {
              Text(importError)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.74))
            }
          }

          if model.importedItems.isEmpty {
            EmptyStateCard(
              title: "No imported items yet",
              message: "Run an import to preview clothing items and add them to your wardrobe.",
              symbol: "shippingbox"
            )
          } else {
            ForEach(model.importedItems) { item in
              GlassCard {
                HStack(alignment: .top, spacing: 14) {
                  AsyncImage(url: item.imageURL) { image in
                    image
                      .resizable()
                      .scaledToFill()
                  } placeholder: {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                      .fill(.white.opacity(0.12))
                      .overlay {
                        Image(systemName: "photo")
                          .foregroundStyle(.white.opacity(0.70))
                      }
                  }
                  .frame(width: 88, height: 104)
                  .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                  VStack(alignment: .leading, spacing: 10) {
                    Text(item.title)
                      .font(.system(.headline, design: .rounded, weight: .semibold))
                      .foregroundStyle(.white)
                    Text(item.brand)
                      .font(.system(.subheadline, design: .rounded))
                      .foregroundStyle(.white.opacity(0.72))
                    HStack {
                      if let priceText = item.priceText {
                        CapsuleTag(text: priceText)
                      }
                      CapsuleTag(text: item.sourceURL.hostDisplayName)
                    }
                    if let categoryHint = item.categoryHint {
                      Text(categoryHint)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                    }
                    Button("Add to wardrobe") {
                      Task { await model.addImportedItem(item) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
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
    .navigationTitle("Import")
  }
}
