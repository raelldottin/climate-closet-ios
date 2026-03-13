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
        VStack(spacing: 18) {
          monthNavigationCard
          monthGridCard
          editorCard
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
      }
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
      HStack {
        VStack(alignment: .leading, spacing: 6) {
          Text(monthAnchor, format: .dateTime.month(.wide).year())
            .font(.system(.title2, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
          Text("Tap a day to assign your outfit and record the weather context.")
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(.white.opacity(0.72))
        }
        Spacer()
        HStack(spacing: 10) {
          Button {
            monthAnchor = calendar.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
          } label: {
            Image(systemName: "chevron.left")
          }
          .buttonStyle(.bordered)
          .tint(.white.opacity(0.85))

          Button {
            monthAnchor = calendar.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
          } label: {
            Image(systemName: "chevron.right")
          }
          .buttonStyle(.bordered)
          .tint(.white.opacity(0.85))
        }
      }
    }
  }

  private var monthGridCard: some View {
    GlassCard {
      let dayLabels = calendar.shortWeekdaySymbols
      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 10
      ) {
        ForEach(dayLabels, id: \.self) { label in
          Text(label)
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(.white.opacity(0.75))
        }

        ForEach(Array(monthCells().enumerated()), id: \.offset) { _, cellDate in
          if let cellDate {
            Button {
              selectedDate = cellDate
            } label: {
              VStack(spacing: 8) {
                Text("\(calendar.component(.day, from: cellDate))")
                  .font(.system(.headline, design: .rounded, weight: .semibold))
                  .foregroundStyle(.white)
                if let assignment = model.assignment(on: cellDate) {
                  Text("\(assignment.itemIDs.count) items")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                } else {
                  Text(" ")
                    .font(.caption2)
                }
              }
              .frame(maxWidth: .infinity, minHeight: 58)
              .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .fill(
                    calendar.isDate(cellDate, inSameDayAs: selectedDate)
                      ? .orange.opacity(0.55) : .white.opacity(0.10))
              )
            }
          } else {
            Color.clear
              .frame(height: 58)
          }
        }
      }
    }
  }

  private var editorCard: some View {
    GlassCard {
      SectionTitle(
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
          .tint(.orange)

        Picker("Condition", selection: $recordedCondition) {
          ForEach(WeatherCondition.allCases) { condition in
            Text(condition.title).tag(condition)
          }
        }
        .pickerStyle(.menu)

        TextField("Notes for the day", text: $note, axis: .vertical)
          .textFieldStyle(.roundedBorder)

        VStack(spacing: 10) {
          ForEach(model.wardrobeItems) { item in
            Button {
              if selectedItemIDs.contains(item.id) {
                selectedItemIDs.remove(item.id)
              } else {
                selectedItemIDs.insert(item.id)
              }
            } label: {
              HStack {
                Image(
                  systemName: selectedItemIDs.contains(item.id) ? "checkmark.circle.fill" : "circle"
                )
                .foregroundStyle(selectedItemIDs.contains(item.id) ? .orange : .white.opacity(0.72))
                VStack(alignment: .leading, spacing: 4) {
                  Text(item.name)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                  Text("\(item.category.title) • \(item.preferredTemperature.label)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
              }
              .padding(14)
              .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .fill(.white.opacity(0.10))
              )
            }
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
          .buttonStyle(.bordered)
          .tint(.white.opacity(0.85))

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
          .buttonStyle(.borderedProminent)
          .tint(.orange)
        }
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
}
