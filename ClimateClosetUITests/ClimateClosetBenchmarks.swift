import XCTest

@MainActor
final class ClimateClosetBenchmarks: XCTestCase {
  private let iterationCount = 5
  private let timeout: TimeInterval = 15
  private let tomFordURL = "https://www.tomford.com/men/outerwear"

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testLaunchBenchmark() throws {
    let storeProfile = "launch-benchmark"
    let app = benchmarkApp(
      storeProfile: storeProfile,
      preseedStore: true,
      overwriteStore: true
    )
    app.launch()
    XCTAssertTrue(app.scrollViews["screen.weather"].waitForExistence(timeout: timeout))
    app.terminate()

    try benchmark(named: "launch_to_weather_root") { _ in
      let launchedApp = benchmarkApp(storeProfile: storeProfile)
      let start = DispatchTime.now().uptimeNanoseconds
      launchedApp.launch()
      XCTAssertTrue(launchedApp.scrollViews["screen.weather"].waitForExistence(timeout: timeout))
      let elapsedMilliseconds = elapsedMilliseconds(since: start)
      launchedApp.terminate()
      return elapsedMilliseconds
    }
  }

  func testTabSwitchBenchmarks() throws {
    try benchmark(named: "weather_to_wardrobe_first_load") { _ in
      let app = try launchInteractionApp(storeProfile: "tabs-wardrobe")
      let start = DispatchTime.now().uptimeNanoseconds
      app.tabBars.buttons["Wardrobe"].tap()
      XCTAssertTrue(app.scrollViews["screen.wardrobe"].waitForExistence(timeout: timeout))
      let elapsedMilliseconds = elapsedMilliseconds(since: start)
      app.terminate()
      return elapsedMilliseconds
    }

    try benchmark(named: "weather_to_planner_first_load") { _ in
      let app = try launchInteractionApp(storeProfile: "tabs-planner")
      let start = DispatchTime.now().uptimeNanoseconds
      app.tabBars.buttons["Planner"].tap()
      XCTAssertTrue(app.scrollViews["screen.planner"].waitForExistence(timeout: timeout))
      let elapsedMilliseconds = elapsedMilliseconds(since: start)
      app.terminate()
      return elapsedMilliseconds
    }

    try benchmark(named: "weather_to_import_first_load") { _ in
      let app = try launchInteractionApp(storeProfile: "tabs-import")
      let start = DispatchTime.now().uptimeNanoseconds
      app.tabBars.buttons["Import"].tap()
      XCTAssertTrue(app.scrollViews["screen.import"].waitForExistence(timeout: timeout))
      let elapsedMilliseconds = elapsedMilliseconds(since: start)
      app.terminate()
      return elapsedMilliseconds
    }
  }

  func testAddWardrobeItemBenchmark() throws {
    try benchmark(named: "save_new_wardrobe_item") { iteration in
      let app = try launchInteractionApp(storeProfile: "add-item")
      let itemName = "Benchmark Save Tee \(iteration)"

      app.tabBars.buttons["Wardrobe"].tap()
      XCTAssertTrue(app.scrollViews["screen.wardrobe"].waitForExistence(timeout: timeout))

      let searchField = app.textFields["field.wardrobe.search"]
      XCTAssertTrue(searchField.waitForExistence(timeout: timeout))
      replaceText(in: searchField, with: itemName)

      app.buttons["action.add-wardrobe-item"].tap()
      let nameField = app.textFields["field.add-wardrobe-item.name"]
      XCTAssertTrue(nameField.waitForExistence(timeout: timeout))
      replaceText(in: nameField, with: itemName)

      let saveButton = app.buttons["action.add-wardrobe-item.save"]
      XCTAssertTrue(saveButton.waitForExistence(timeout: timeout))
      let start = DispatchTime.now().uptimeNanoseconds
      saveButton.tap()
      XCTAssertTrue(app.staticTexts[itemName].waitForExistence(timeout: timeout))
      let elapsedMilliseconds = elapsedMilliseconds(since: start)
      app.terminate()
      return elapsedMilliseconds
    }
  }

  func testImportBenchmark() throws {
    try benchmark(named: "import_tom_ford_fixture") { _ in
      let app = try launchInteractionApp(storeProfile: "import-flow")

      app.tabBars.buttons["Import"].tap()
      XCTAssertTrue(app.scrollViews["screen.import"].waitForExistence(timeout: timeout))

      let urlField = app.textFields["field.import.url"]
      XCTAssertTrue(urlField.waitForExistence(timeout: timeout))
      replaceText(in: urlField, with: tomFordURL)

      let importButton = app.buttons["action.import-catalog"]
      XCTAssertTrue(importButton.waitForExistence(timeout: timeout))
      let start = DispatchTime.now().uptimeNanoseconds
      importButton.tap()
      XCTAssertTrue(
        app.staticTexts["Tom Ford Suede Trucker Jacket"].waitForExistence(timeout: timeout))
      let elapsedMilliseconds = elapsedMilliseconds(since: start)
      app.terminate()
      return elapsedMilliseconds
    }
  }

  func testSaveDayBenchmark() throws {
    let verificationNote = "Benchmark planner note persisted"

    try benchmark(named: "save_day_assignment_and_note") { iteration in
      let app = try launchInteractionApp(storeProfile: "planner-save")

      app.tabBars.buttons["Planner"].tap()
      XCTAssertTrue(app.scrollViews["screen.planner"].waitForExistence(timeout: timeout))

      let firstItem = plannerItemButton(in: app)
      XCTAssertTrue(firstItem.waitForExistence(timeout: timeout))
      firstItem.tap()

      let noteField = plannerNoteField(in: app)
      XCTAssertTrue(noteField.waitForExistence(timeout: timeout))
      replaceText(in: noteField, with: "\(verificationNote) \(iteration)")

      let saveButton = app.buttons["action.save-day"]
      let persistenceRevision = app.otherElements["planner.persistence-revision"]
      XCTAssertTrue(saveButton.waitForExistence(timeout: timeout))
      XCTAssertTrue(persistenceRevision.waitForExistence(timeout: timeout))

      let start = DispatchTime.now().uptimeNanoseconds
      saveButton.tap()
      waitForValue("1", in: persistenceRevision)
      let elapsedMilliseconds = elapsedMilliseconds(since: start)
      app.terminate()
      return elapsedMilliseconds
    }

    try verifyPlannerPersistence(
      storeProfile: "planner-save-persistence",
      note: verificationNote
    )
  }

  func testToolbarIconsRenderSmoke() throws {
    let app = benchmarkApp(
      storeProfile: "toolbar-render",
      preseedStore: true,
      overwriteStore: true
    )
    app.launch()
    XCTAssertTrue(app.scrollViews["screen.weather"].waitForExistence(timeout: timeout))

    let refreshButton = app.buttons["action.refresh-weather"]
    let weatherAddButton = app.buttons["action.add-wardrobe-item"]
    XCTAssertTrue(refreshButton.waitForExistence(timeout: timeout))
    XCTAssertTrue(weatherAddButton.waitForExistence(timeout: timeout))
    XCTAssertGreaterThan(refreshButton.frame.size.width, 0)
    XCTAssertGreaterThan(weatherAddButton.frame.size.width, 0)
    attachScreenshot(named: "weather-toolbar")

    app.tabBars.buttons["Wardrobe"].tap()
    XCTAssertTrue(app.scrollViews["screen.wardrobe"].waitForExistence(timeout: timeout))

    let wardrobeAddButton = app.buttons["action.add-wardrobe-item"]
    XCTAssertTrue(wardrobeAddButton.waitForExistence(timeout: timeout))
    XCTAssertGreaterThan(wardrobeAddButton.frame.size.width, 0)
    attachScreenshot(named: "wardrobe-toolbar")

    app.terminate()
  }

  func testDocumentationScreenshots() throws {
    let app = benchmarkApp(
      storeProfile: "docs-screenshots",
      preseedStore: true,
      overwriteStore: true
    )
    app.launch()
    XCTAssertTrue(app.scrollViews["screen.weather"].waitForExistence(timeout: timeout))
    attachScreenshot(named: "weather")

    app.tabBars.buttons["Wardrobe"].tap()
    XCTAssertTrue(app.scrollViews["screen.wardrobe"].waitForExistence(timeout: timeout))
    attachScreenshot(named: "wardrobe")

    app.tabBars.buttons["Planner"].tap()
    XCTAssertTrue(app.scrollViews["screen.planner"].waitForExistence(timeout: timeout))
    attachScreenshot(named: "planner")

    app.tabBars.buttons["Import"].tap()
    XCTAssertTrue(app.scrollViews["screen.import"].waitForExistence(timeout: timeout))

    let urlField = app.textFields["field.import.url"]
    XCTAssertTrue(urlField.waitForExistence(timeout: timeout))
    replaceText(in: urlField, with: tomFordURL)
    urlField.typeText("\n")

    let importButton = app.buttons["action.import-catalog"]
    XCTAssertTrue(importButton.waitForExistence(timeout: timeout))
    importButton.tap()
    XCTAssertTrue(
      app.staticTexts["Tom Ford Suede Trucker Jacket"].waitForExistence(timeout: timeout))
    app.scrollViews["screen.import"].swipeUp()
    attachScreenshot(named: "import")

    app.terminate()
  }

  private func benchmark(
    named name: String,
    iterations: Int? = nil,
    action: (Int) throws -> Double
  ) throws {
    let actualIterations = iterations ?? iterationCount
    var samples: [Double] = []

    for iteration in 1...actualIterations {
      samples.append(try action(iteration))
    }

    let expectation = try XCTUnwrap(
      BenchmarkExpectation.expectation(for: name),
      "Missing benchmark expectation for \(name)"
    )
    let summary = BenchmarkSummary(
      name: name,
      samplesInMilliseconds: samples,
      expectation: expectation
    )
    let renderedSummary = summary.rendered
    print("BENCHMARK \(renderedSummary)")
    XCTContext.runActivity(named: "Benchmark \(name)") { activity in
      activity.add(XCTAttachment(string: renderedSummary))
    }
    XCTAssertNotEqual(
      summary.assessment,
      .underperforming,
      "Benchmark \(name) exceeded its hard ceiling. \(renderedSummary)"
    )
  }

  private func launchInteractionApp(storeProfile: String) throws -> XCUIApplication {
    let app = benchmarkApp(
      storeProfile: storeProfile,
      preseedStore: true,
      overwriteStore: true
    )
    app.launch()
    XCTAssertTrue(app.scrollViews["screen.weather"].waitForExistence(timeout: timeout))
    return app
  }

  private func verifyPlannerPersistence(storeProfile: String, note: String) throws {
    let writeApp = try launchInteractionApp(storeProfile: storeProfile)
    writeApp.tabBars.buttons["Planner"].tap()
    XCTAssertTrue(writeApp.scrollViews["screen.planner"].waitForExistence(timeout: timeout))

    let firstItem = plannerItemButton(in: writeApp)
    XCTAssertTrue(firstItem.waitForExistence(timeout: timeout))
    firstItem.tap()

    let noteField = plannerNoteField(in: writeApp)
    XCTAssertTrue(noteField.waitForExistence(timeout: timeout))
    replaceText(in: noteField, with: note)

    let saveButton = writeApp.buttons["action.save-day"]
    let persistenceRevision = writeApp.otherElements["planner.persistence-revision"]
    XCTAssertTrue(persistenceRevision.waitForExistence(timeout: timeout))
    saveButton.tap()
    waitForValue("1", in: persistenceRevision)
    writeApp.terminate()

    let readApp = benchmarkApp(storeProfile: storeProfile)
    readApp.launch()
    XCTAssertTrue(readApp.scrollViews["screen.weather"].waitForExistence(timeout: timeout))
    readApp.tabBars.buttons["Planner"].tap()
    XCTAssertTrue(readApp.scrollViews["screen.planner"].waitForExistence(timeout: timeout))

    let persistedNoteField = plannerNoteField(in: readApp)
    XCTAssertTrue(persistedNoteField.waitForExistence(timeout: timeout))
    XCTAssertEqual(persistedNoteField.value as? String, note)
    readApp.terminate()
  }

  private func benchmarkApp(
    storeProfile: String,
    preseedStore: Bool = false,
    overwriteStore: Bool = false
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--benchmark-mode"]
    app.launchEnvironment = [
      "CLIMATE_CLOSET_BENCHMARK_PERSISTED_STORE": "1",
      "CLIMATE_CLOSET_STORE_PROFILE": storeProfile,
      "CLIMATE_CLOSET_PRESEED_BENCHMARK_STORE": preseedStore ? "1" : "0",
      "CLIMATE_CLOSET_OVERWRITE_BENCHMARK_STORE": overwriteStore ? "1" : "0",
    ]
    return app
  }

  private func plannerNoteField(in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: "field.planner.note").firstMatch
  }

  private func plannerItemButton(in app: XCUIApplication) -> XCUIElement {
    let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "planner.item.")
    return app.buttons.matching(predicate).firstMatch
  }

  private func waitForValue(_ value: String, in element: XCUIElement) {
    let predicate = NSPredicate(format: "value == %@", value)
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed)
  }

  private func replaceText(in element: XCUIElement, with text: String) {
    element.tap()
    if let currentValue = element.value as? String, !currentValue.isEmpty {
      let deleteSequence = String(
        repeating: XCUIKeyboardKey.delete.rawValue,
        count: currentValue.count
      )
      element.typeText(deleteSequence)
    }
    element.typeText(text)
  }

  private func elapsedMilliseconds(since start: UInt64) -> Double {
    Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
  }

  private func attachScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}

private struct BenchmarkSummary {
  let name: String
  let samplesInMilliseconds: [Double]
  let expectation: BenchmarkExpectation

  var mean: Double {
    samplesInMilliseconds.reduce(0, +) / Double(samplesInMilliseconds.count)
  }

  var median: Double {
    percentile(0.5, in: sortedSamples)
  }

  var p90: Double {
    percentile(0.9, in: sortedSamples)
  }

  var minimum: Double {
    sortedSamples.first ?? 0
  }

  var maximum: Double {
    sortedSamples.last ?? 0
  }

  var assessment: BenchmarkAssessment {
    if mean <= expectation.targetMeanMilliseconds {
      return .outperforming
    }
    if mean <= expectation.maximumMeanMilliseconds {
      return .meeting
    }
    return .underperforming
  }

  var rendered: String {
    return String(
      format:
        "%@ | status=%@ | target<=%.1f ms | ceiling<=%.1f ms | n=%d | mean=%.1f ms | median=%.1f ms | p90=%.1f ms | min=%.1f ms | max=%.1f ms",
      name,
      assessment.rawValue,
      expectation.targetMeanMilliseconds,
      expectation.maximumMeanMilliseconds,
      samplesInMilliseconds.count,
      mean,
      median,
      p90,
      minimum,
      maximum
    )
  }

  private var sortedSamples: [Double] {
    samplesInMilliseconds.sorted()
  }

  private func percentile(_ percentile: Double, in sortedSamples: [Double]) -> Double {
    guard !sortedSamples.isEmpty else {
      return 0
    }
    let rank = percentile * Double(sortedSamples.count - 1)
    let lowerIndex = Int(rank.rounded(.down))
    let upperIndex = Int(rank.rounded(.up))
    if lowerIndex == upperIndex {
      return sortedSamples[lowerIndex]
    }
    let interpolation = rank - Double(lowerIndex)
    return sortedSamples[lowerIndex]
      + ((sortedSamples[upperIndex] - sortedSamples[lowerIndex]) * interpolation)
  }
}

private struct BenchmarkExpectation {
  let targetMeanMilliseconds: Double
  let maximumMeanMilliseconds: Double

  static func expectation(for name: String) -> BenchmarkExpectation? {
    switch name {
    case "launch_to_weather_root":
      BenchmarkExpectation(targetMeanMilliseconds: 3500, maximumMeanMilliseconds: 4250)
    case "weather_to_wardrobe_first_load":
      BenchmarkExpectation(targetMeanMilliseconds: 2750, maximumMeanMilliseconds: 3300)
    case "weather_to_planner_first_load":
      BenchmarkExpectation(targetMeanMilliseconds: 2900, maximumMeanMilliseconds: 3400)
    case "weather_to_import_first_load":
      BenchmarkExpectation(targetMeanMilliseconds: 2600, maximumMeanMilliseconds: 3150)
    case "save_new_wardrobe_item":
      BenchmarkExpectation(targetMeanMilliseconds: 2000, maximumMeanMilliseconds: 2500)
    case "import_tom_ford_fixture":
      BenchmarkExpectation(targetMeanMilliseconds: 1400, maximumMeanMilliseconds: 1800)
    case "save_day_assignment_and_note":
      BenchmarkExpectation(targetMeanMilliseconds: 1500, maximumMeanMilliseconds: 1900)
    default:
      nil
    }
  }
}

private enum BenchmarkAssessment: String {
  case outperforming = "OUTPERFORMING"
  case meeting = "MEETING"
  case underperforming = "UNDERPERFORMING"
}
