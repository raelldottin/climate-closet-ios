import Observation
import SwiftUI

struct ImportCatalogView: View {
  @Bindable var model: AppModel

  private let presetColumns = [
    GridItem(.flexible(), spacing: ClimateUI.Layout.rowSpacing),
    GridItem(.flexible(), spacing: ClimateUI.Layout.rowSpacing),
  ]

  var body: some View {
    ZStack {
      AtmosphericBackground()
      ScrollView {
        LazyVStack(spacing: ClimateUI.Layout.sectionSpacing) {
          GlassCard {
            SectionHeader(
              title: "Import studio",
              subtitle:
                "Only wardrobe-ready product and category pages make it through. Homepages and beauty catalogs stop at the door."
            )

            LazyVGrid(columns: presetColumns, spacing: ClimateUI.Layout.rowSpacing) {
              ForEach(ImportPreset.allCases) { preset in
                Button {
                  model.adoptPreset(preset)
                } label: {
                  ImportPresetCard(
                    preset: preset,
                    isSelected: model.selectedImportPreset == preset
                  )
                }
                .buttonStyle(.plain)
              }
            }

            VStack(alignment: .leading, spacing: ClimateUI.Layout.compactSpacing) {
              Text(model.selectedImportPreset.helperText)
                .climateText(.detail, color: ClimateUI.Palette.textSecondary)
              Text(model.selectedImportPreset.exampleText)
                .climateText(.caption, color: ClimateUI.Palette.textMuted)
            }

            TextField(
              model.selectedImportPreset.placeholder,
              text: Binding(
                get: { model.importURLText },
                set: { model.updateImportURLText($0) }
              )
            )
            .climateInputField()
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            .accessibilityIdentifier("field.import.url")

            ImportReadinessCard(readiness: model.importReadiness)

            HStack(spacing: ClimateUI.Layout.rowSpacing) {
              Button {
                Task { await model.importCatalog() }
              } label: {
                HStack(spacing: ClimateUI.Layout.compactSpacing) {
                  if model.isImportingCatalog {
                    ProgressView()
                      .tint(ClimateUI.Palette.textPrimary)
                  }
                  Text(model.isImportingCatalog ? "Importing..." : "Import Catalog")
                }
                .frame(maxWidth: .infinity)
              }
              .buttonStyle(ClimateActionButtonStyle(kind: .primary))
              .disabled(!model.canStartImport)
              .accessibilityIdentifier("action.import-catalog")

              if !model.importedItems.isEmpty {
                Button("Clear") {
                  model.clearImportedPreview()
                }
                .buttonStyle(ClimateActionButtonStyle(kind: .secondary))
                .accessibilityIdentifier("action.import-clear")
              }
            }

            if let importError = model.importError {
              ImportMessageRow(
                symbolName: "exclamationmark.triangle.fill",
                text: importError,
                tint: ClimateUI.Palette.warning
              )
            } else if let importNotice = model.importNotice {
              ImportMessageRow(
                symbolName: "checkmark.circle.fill",
                text: importNotice,
                tint: ClimateUI.Palette.success
              )
            }
          }

          if model.importedItems.isEmpty {
            EmptyStateCard(
              title: emptyStateTitle,
              message: emptyStateMessage,
              symbol: model.importReadiness.symbolName
            )
          } else {
            ImportBatchSummaryCard(model: model)

            ForEach(model.importedItems) { item in
              ImportedCatalogItemCard(
                item: item,
                isSelected: model.importedItemIsSelected(item),
                isAlreadyOwned: model.importedItemAlreadyExists(item),
                onToggleSelection: { model.toggleImportedItemSelection(item) },
                onAddNow: { Task { await model.addImportedItem(item) } }
              )
            }
          }
        }
        .padding(.horizontal, ClimateUI.Layout.screenInset)
        .padding(.vertical, ClimateUI.Layout.screenInset)
      }
      .accessibilityIdentifier("screen.import")
    }
    .navigationTitle("Import")
  }

  private var emptyStateTitle: String {
    switch model.importReadiness {
    case .empty:
      return "Bring in a product or category page"
    case .ready:
      return "Import preview will appear here"
    case .needsCatalogPage:
      return "That link is too broad"
    case .invalidURL, .unsupportedScheme, .nonWardrobeSource:
      return "Importer is waiting on a wardrobe source"
    }
  }

  private var emptyStateMessage: String {
    if let importError = model.importError {
      return importError
    }
    return model.importReadiness.message
  }
}

private struct ImportPresetCard: View {
  let preset: ImportPreset
  let isSelected: Bool

  var body: some View {
    GlassTile(
      cornerRadius: ClimateUI.Radius.tile,
      padding: ClimateUI.Layout.cardSpacing,
      fill: isSelected ? ClimateUI.Palette.surfaceSelected : ClimateUI.Palette.surface
    ) {
      ClimateIconBadge(
        systemImage: preset.symbolName,
        tint:
          isSelected
          ? ClimateUI.Palette.accent.opacity(0.38) : ClimateUI.Palette.surfaceSelected
      )
      Text(preset.title)
        .climateText(.bodyStrong)

      Text(preset.subtitle)
        .climateText(.caption, color: ClimateUI.Palette.textSecondary)
        .multilineTextAlignment(.leading)
    }
    .overlay {
      if isSelected {
        RoundedRectangle(cornerRadius: ClimateUI.Radius.tile, style: .continuous)
          .stroke(ClimateUI.Palette.borderStrong, lineWidth: 1)
      }
    }
  }
}

private struct ImportReadinessCard: View {
  let readiness: CatalogImportReadiness

  var body: some View {
    GlassTile(cornerRadius: ClimateUI.Radius.tile, padding: ClimateUI.Layout.cardSpacing) {
      HStack(alignment: .top, spacing: ClimateUI.Layout.rowSpacing) {
        ClimateIconBadge(systemImage: readiness.symbolName, tint: tint.opacity(0.34))

        VStack(alignment: .leading, spacing: ClimateUI.Layout.sectionHeaderSpacing) {
          Text(readiness.title)
            .climateText(.bodyStrong)
          Text(readiness.message)
            .climateText(.body, color: ClimateUI.Palette.textSecondary)
        }

        Spacer(minLength: 0)
      }
    }
    .overlay(
      RoundedRectangle(cornerRadius: ClimateUI.Radius.tile, style: .continuous)
        .stroke(tint.opacity(0.42), lineWidth: 1)
    )
  }

  private var tint: Color {
    switch readiness {
    case .ready(.product, _):
      ClimateUI.Palette.success
    case .ready(.category, _):
      ClimateUI.Palette.warning
    case .empty:
      ClimateUI.Palette.textPrimary
    case .needsCatalogPage:
      ClimateUI.Palette.warning
    case .invalidURL, .unsupportedScheme, .nonWardrobeSource:
      ClimateUI.Palette.critical
    }
  }
}

private struct ImportMessageRow: View {
  let symbolName: String
  let text: String
  let tint: Color

  var body: some View {
    HStack(alignment: .top, spacing: ClimateUI.Layout.compactSpacing) {
      Image(systemName: symbolName)
        .foregroundStyle(tint)
      Text(text)
        .climateText(.detail, color: ClimateUI.Palette.textSecondary)
    }
  }
}

private struct ImportBatchSummaryCard: View {
  @Bindable var model: AppModel

  var body: some View {
    GlassCard {
      SectionHeader(
        title: "Import queue",
        subtitle: "Review every piece before it enters your wardrobe."
      )

      HStack(spacing: ClimateUI.Layout.compactSpacing) {
        CapsuleTag(text: "\(model.importedItems.count) ready")
        if model.importedNewItemCount > 0 {
          CapsuleTag(
            text: "\(model.importedNewItemCount) new",
            tint: ClimateUI.Palette.success.opacity(0.28)
          )
        }
        if model.importedExistingItemCount > 0 {
          CapsuleTag(
            text: "\(model.importedExistingItemCount) already owned",
            tint: ClimateUI.Palette.surface
          )
        }
      }

      HStack(spacing: ClimateUI.Layout.rowSpacing) {
        Button {
          Task { await model.addSelectedImportedItems() }
        } label: {
          Text(
            model.selectedImportedItemCount > 0
              ? "Add \(model.selectedImportedItemCount) selected"
              : "Select pieces to add"
          )
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(ClimateActionButtonStyle(kind: .primary))
        .disabled(model.selectedImportedItemCount == 0)
        .accessibilityIdentifier("action.import-add-selected")

        Button("Clear") {
          model.clearImportedPreview()
        }
        .buttonStyle(ClimateActionButtonStyle(kind: .secondary))
      }
    }
  }
}

private struct ImportedCatalogItemCard: View {
  let item: ImportedCatalogItem
  let isSelected: Bool
  let isAlreadyOwned: Bool
  let onToggleSelection: () -> Void
  let onAddNow: () -> Void

  var body: some View {
    GlassCard {
      HStack(alignment: .top, spacing: ClimateUI.Layout.mediaSpacing) {
        AsyncImage(url: item.imageURL) { image in
          image
            .resizable()
            .scaledToFill()
        } placeholder: {
          RoundedRectangle(cornerRadius: ClimateUI.Radius.tile, style: .continuous)
            .fill(ClimateUI.Palette.surface)
            .overlay {
              Image(systemName: "photo")
                .foregroundStyle(ClimateUI.Palette.textSecondary)
            }
        }
        .frame(
          width: ClimateUI.Layout.importThumbnailWidth,
          height: ClimateUI.Layout.importThumbnailHeight
        )
        .clipShape(RoundedRectangle(cornerRadius: ClimateUI.Radius.tile, style: .continuous))

        VStack(alignment: .leading, spacing: ClimateUI.Layout.mediumSpacing) {
          HStack(alignment: .top, spacing: ClimateUI.Layout.mediumSpacing) {
            VStack(alignment: .leading, spacing: ClimateUI.Layout.tightSpacing) {
              Text(item.title)
                .climateText(.bodyStrong)
              Text(item.brand)
                .climateText(.body, color: ClimateUI.Palette.textSecondary)
            }

            Spacer(minLength: 0)

            Button(action: onToggleSelection) {
              Image(systemName: selectionImageName)
                .font(.system(size: ClimateUI.Icon.selection, weight: .semibold))
                .foregroundStyle(selectionTint)
            }
            .buttonStyle(.plain)
            .disabled(isAlreadyOwned)
          }

          HStack(spacing: ClimateUI.Layout.compactSpacing) {
            CapsuleTag(text: item.confidence.title, tint: confidenceTint)
            if let priceText = item.priceText {
              CapsuleTag(text: priceText)
            }
            CapsuleTag(text: item.sourceURL.hostDisplayName)
          }

          if let categoryHint = item.categoryHint, !categoryHint.isEmpty {
            Text(categoryHint)
              .climateText(.caption, color: ClimateUI.Palette.textSecondary)
          }

          if let notes = item.notes, !notes.isEmpty {
            Text(notes)
              .climateText(.caption, color: ClimateUI.Palette.textMuted)
              .lineLimit(2)
          }

          HStack(spacing: ClimateUI.Layout.rowSpacing) {
            if isAlreadyOwned {
              Label("Already in wardrobe", systemImage: "checkmark.circle.fill")
                .climateText(.captionStrong, color: ClimateUI.Palette.textSecondary)
            } else {
              if isSelected {
                Label("Selected for batch add", systemImage: "checkmark.circle.fill")
                  .climateText(.captionStrong, color: ClimateUI.Palette.textSecondary)
              }

              Spacer(minLength: 0)

              Button("Add now", action: onAddNow)
                .buttonStyle(ClimateActionButtonStyle(kind: .primary))
            }
          }
        }
      }
    }
  }

  private var selectionImageName: String {
    if isAlreadyOwned {
      return "checkmark.circle.fill"
    }
    return isSelected ? "checkmark.circle.fill" : "circle"
  }

  private var selectionTint: Color {
    if isAlreadyOwned || isSelected {
      return ClimateUI.Palette.success
    }
    return ClimateUI.Palette.textMuted
  }

  private var confidenceTint: Color {
    switch item.confidence {
    case .fallback:
      return ClimateUI.Palette.surfaceStrong
    case .likely:
      return ClimateUI.Palette.accent.opacity(0.32)
    case .verified:
      return ClimateUI.Palette.success.opacity(0.30)
    }
  }
}
