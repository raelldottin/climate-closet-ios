import Observation
import SwiftUI

struct ScheduleView: View {
  @Bindable var model: AppModel
  @State private var monthAnchor = Date().startOfDay()
  @State private var selectedDate = Date().startOfDay()
  @State private var selectedItemIDs: Set<UUID> = []
  @State private var note = ""
  @State private var recordedTemperature = 68
  @State private var recordedCondition: WeatherCondition = .clear

  private let calendar = Calendar.autoupdatingCurrent

  var body: some View {
    ZStack {
      AtmosphericBackground()
      ScrollView {
        LazyVStack(spacing: ClimateUI.Layout.sectionSpacing) {
          monthNavigationCard
          monthGridCard
          editorCard
        }
        .padding(.horizontal, ClimateUI.Layout.screenInset)
        .padding(.vertical, ClimateUI.Layout.screenInset)
      }
      .accessibilityIdentifier("screen.planner")
    }
    .navigationTitle("Planner")
    .onAppear(perform: syncDraft)
    .onChange(of: selectedDate) { _, _ in
      syncDraft()
    }
    .onChange(of: model.assignments) { _, _ in
      syncDraft()
    }
  }

  private var monthNavigationCard: some View {
    GlassCard {
      SectionHeader(
        title: monthAnchor.formatted(.dateTime.month(.wide).year()),
        subtitle: "Tap a day to assign your outfit and record the weather context.",
        titleRole: .title
      ) {
        HStack(spacing: ClimateUI.Layout.compactSpacing) {
          Button {
            monthAnchor = calendar.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
          } label: {
            Image(systemName: "chevron.left")
          }
          .buttonStyle(ClimateIconButtonStyle())

          Button {
            monthAnchor = calendar.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
          } label: {
            Image(systemName: "chevron.right")
          }
          .buttonStyle(ClimateIconButtonStyle())
        }
      }
    }
  }

  private var monthGridCard: some View {
    GlassCard {
      let dayLabels = calendar.shortWeekdaySymbols
      LazyVGrid(
        columns: Array(
          repeating: GridItem(.flexible(), spacing: ClimateUI.Layout.mediumSpacing),
          count: 7
        ),
        spacing: ClimateUI.Layout.mediumSpacing
      ) {
        ForEach(dayLabels, id: \.self) { label in
          Text(label)
            .climateText(.captionStrong, color: ClimateUI.Palette.textSecondary)
        }

        ForEach(Array(monthCells().enumerated()), id: \.offset) { _, cellDate in
          if let cellDate {
            let assignment = model.assignment(on: cellDate)
            Button {
              selectedDate = cellDate
            } label: {
              GlassTile(
                cornerRadius: ClimateUI.Radius.selection,
                padding: ClimateUI.Layout.calendarTilePadding,
                fill:
                  calendar.isDate(cellDate, inSameDayAs: selectedDate)
                  ? ClimateUI.Palette.accent.opacity(0.48) : ClimateUI.Palette.surface
              ) {
                Text("\(calendar.component(.day, from: cellDate))")
                  .climateText(.bodyStrong)
                if let assignment {
                  Text("\(assignment.itemIDs.count) items")
                    .climateText(.eyebrow, color: ClimateUI.Palette.textSecondary)
                } else {
                  Text(" ")
                    .font(.caption2)
                }
              }
              .frame(maxWidth: .infinity, minHeight: ClimateUI.Layout.calendarCellMinHeight)
            }
            .accessibilityIdentifier(
              calendar.isDate(cellDate, inSameDayAs: selectedDate)
                ? "planner.day.selected" : plannerDayIdentifier(for: cellDate)
            )
            .accessibilityValue(assignment.map { String($0.itemIDs.count) } ?? "0")
          } else {
            Color.clear
              .frame(height: ClimateUI.Layout.calendarCellMinHeight)
          }
        }
      }
    }
  }

  private var editorCard: some View {
    GlassCard {
      SectionHeader(
        title: selectedDate.formatted(date: .complete, time: .omitted),
        subtitle:
          "Assign clothing and log the weather so future recommendations are grounded in your own history."
      )

      if model.wardrobeItems.isEmpty {
        EmptyStateCard(
          title: "Wardrobe is empty",
          message: "Add clothing on the Wardrobe tab before planning an outfit.",
          symbol: "hanger"
        )
      } else {
        Stepper("Temperature \(recordedTemperature)°", value: $recordedTemperature, in: -10...110)
          .tint(ClimateUI.Palette.accent)

        Picker("Condition", selection: $recordedCondition) {
          ForEach(WeatherCondition.allCases) { condition in
            Text(condition.title).tag(condition)
          }
        }
        .pickerStyle(.menu)

        TextField("Notes for the day", text: $note, axis: .vertical)
          .climateInputField()
          .accessibilityIdentifier("field.planner.note")

        LazyVStack(spacing: ClimateUI.Layout.compactSpacing) {
          ForEach(model.wardrobeItems) { item in
            Button {
              if selectedItemIDs.contains(item.id) {
                selectedItemIDs.remove(item.id)
              } else {
                selectedItemIDs.insert(item.id)
              }
            } label: {
              GlassTile(
                cornerRadius: ClimateUI.Radius.selection,
                fill:
                  selectedItemIDs.contains(item.id)
                  ? ClimateUI.Palette.surfaceSelected : ClimateUI.Palette.surface
              ) {
                HStack {
                  Image(
                    systemName:
                      selectedItemIDs.contains(item.id) ? "checkmark.circle.fill" : "circle"
                  )
                  .foregroundStyle(
                    selectedItemIDs.contains(item.id)
                      ? ClimateUI.Palette.accent : ClimateUI.Palette.textSecondary
                  )
                  VStack(alignment: .leading, spacing: ClimateUI.Layout.sectionHeaderSpacing) {
                    Text(item.name)
                      .climateText(.bodyStrong)
                    Text("\(item.category.title) • \(item.preferredTemperature.label)")
                      .climateText(.caption, color: ClimateUI.Palette.textSecondary)
                  }
                  Spacer()
                }
              }
            }
            .accessibilityIdentifier("planner.item.\(item.id.uuidString)")
          }
        }

        HStack {
          Button("Clear") {
            selectedItemIDs.removeAll()
            note = ""
            Task {
              await model.saveAssignment(
                for: selectedDate,
                itemIDs: [],
                note: "",
                recordedTemperatureF: nil,
                recordedCondition: nil
              )
            }
          }
          .buttonStyle(ClimateActionButtonStyle(kind: .secondary))

          Spacer()

          Button("Save Day") {
            Task {
              await model.saveAssignment(
                for: selectedDate,
                itemIDs: selectedItemIDs,
                note: note,
                recordedTemperatureF: recordedTemperature,
                recordedCondition: recordedCondition
              )
            }
          }
          .buttonStyle(ClimateActionButtonStyle(kind: .primary))
          .accessibilityIdentifier("action.save-day")
        }

        Color.clear
          .frame(width: ClimateUI.Metrics.hiddenMarker, height: ClimateUI.Metrics.hiddenMarker)
          .accessibilityElement()
          .accessibilityIdentifier("planner.persistence-revision")
          .accessibilityValue(String(model.persistenceRevision))
      }
    }
  }

  private func syncDraft() {
    if let assignment = model.assignment(on: selectedDate) {
      selectedItemIDs = Set(assignment.itemIDs)
      note = assignment.note
      recordedTemperature =
        assignment.recordedTemperatureF
        ?? assignment.weatherSnapshot?.temperatureF
        ?? model.weatherReport?.current.temperatureF
        ?? 68
      recordedCondition =
        assignment.recordedCondition
        ?? assignment.weatherSnapshot?.condition
        ?? model.weatherReport?.current.condition
        ?? .clear
    } else {
      selectedItemIDs = []
      note = ""
      let snapshot = model.forecastSnapshot(
        for: selectedDate, explicitTemperature: nil, explicitCondition: nil)
      recordedTemperature =
        snapshot?.temperatureF ?? model.weatherReport?.current.temperatureF ?? 68
      recordedCondition = snapshot?.condition ?? model.weatherReport?.current.condition ?? .clear
    }
  }

  private func monthCells() -> [Date?] {
    guard let monthRange = calendar.dateInterval(of: .month, for: monthAnchor) else {
      return []
    }
    let firstDay = monthRange.start
    let numberOfDays = calendar.range(of: .day, in: .month, for: firstDay)?.count ?? 0
    let weekday = calendar.component(.weekday, from: firstDay)
    let leadingPadding = (weekday - calendar.firstWeekday + 7) % 7
    var cells: [Date?] = Array(repeating: nil, count: leadingPadding)
    for offset in 0..<numberOfDays {
      cells.append(calendar.date(byAdding: .day, value: offset, to: firstDay))
    }
    while !cells.count.isMultiple(of: 7) {
      cells.append(nil)
    }
    return cells
  }

  private func plannerDayIdentifier(for date: Date) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    let year = components.year ?? 0
    let month = components.month ?? 0
    let day = components.day ?? 0
    return String(format: "planner.day.%04d-%02d-%02d", year, month, day)
  }
}
