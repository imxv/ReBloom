import XCTest

final class AdonisFlowUITests: XCTestCase {
  @MainActor
  func testTopLevelCreateAndWardrobeScreensRemainReadable() {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-testing")
    app.launch()

    XCTAssertTrue(app.buttons["sample-01"].waitForExistence(timeout: 8))
    keepScreenshot(named: "Adonis-create-home")

    app.tabBars.buttons["衣橱"].tap()
    XCTAssertTrue(app.buttons["add-first-wardrobe-item"].waitForExistence(timeout: 5))
    keepScreenshot(named: "Adonis-wardrobe-empty")
  }

  @MainActor
  func testPreparedSampleCanBeCollectedAndFoundInBloomCalendar() throws {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-testing")
    app.launch()

    let firstSample = app.buttons["sample-01"]
    XCTAssertTrue(firstSample.waitForExistence(timeout: 8))
    firstSample.tap()

    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 8))
    keepScreenshot(named: "Adonis-result-card")

    let saveButton = app.buttons["save-today"]
    XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
    saveButton.tap()
    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 3))

    app.buttons["make-another"].tap()
    XCTAssertTrue(app.buttons["sample-01"].waitForExistence(timeout: 5))

    app.tabBars.buttons["花历"].tap()
    XCTAssertTrue(app.otherElements["bloom-calendar"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["recent-blooms-title"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["今日穿搭"].exists)
    keepScreenshot(named: "Adonis-bloom-calendar")
  }

  @MainActor
  func testCatalogImageCanBeRememberedAndCorrectedWithOneTap() {
    let app = XCUIApplication()
    app.launchArguments.append(contentsOf: ["-ui-testing", "-ui-testing-wardrobe-import"])
    app.launch()

    app.tabBars.buttons["衣橱"].tap()
    let addTestItem = app.buttons["add-test-wardrobe-item"]
    XCTAssertTrue(addTestItem.waitForExistence(timeout: 5))
    addTestItem.tap()

    XCTAssertTrue(app.staticTexts["wardrobe-analysis-summary"].waitForExistence(timeout: 8))
    XCTAssertTrue(app.staticTexts["棕色单品"].exists)
    XCTAssertTrue(app.staticTexts["像商品图"].exists)
    keepScreenshot(named: "Adonis-wardrobe-analysis")

    let topCategory = app.buttons["wardrobe-category-上装"]
    XCTAssertTrue(topCategory.waitForExistence(timeout: 3))
    topCategory.tap()
    XCTAssertTrue(app.staticTexts["棕色上装"].waitForExistence(timeout: 3))
    keepScreenshot(named: "Adonis-wardrobe-corrected")

    app.buttons["完成"].tap()
    XCTAssertTrue(app.staticTexts["棕色上装"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.buttons.matching(identifier: "wardrobe-item-card").count, 1)

    let reimport = app.buttons["reimport-test-wardrobe-item"]
    XCTAssertTrue(reimport.waitForExistence(timeout: 3))
    reimport.tap()
    XCTAssertTrue(app.staticTexts["wardrobe-analysis-summary"].waitForExistence(timeout: 5))
    app.buttons["完成"].tap()
    XCTAssertEqual(app.buttons.matching(identifier: "wardrobe-item-card").count, 1)
  }

  @MainActor
  func testOutfitCluesStayProvisionalUntilOneTapConfirmation() {
    let app = XCUIApplication()
    app.launchArguments.append(contentsOf: ["-ui-testing", "-ui-testing-wardrobe-import"])
    app.launch()

    app.tabBars.buttons["衣橱"].tap()
    let addTestItem = app.buttons["add-test-wardrobe-item"]
    XCTAssertTrue(addTestItem.waitForExistence(timeout: 5))
    addTestItem.tap()
    XCTAssertTrue(app.staticTexts["wardrobe-analysis-summary"].waitForExistence(timeout: 8))
    app.buttons["wardrobe-category-上装"].tap()
    XCTAssertTrue(app.staticTexts["棕色上装"].waitForExistence(timeout: 3))
    app.buttons["完成"].tap()
    XCTAssertEqual(app.buttons.matching(identifier: "wardrobe-item-card").count, 1)

    app.tabBars.buttons["创作"].tap()
    let sample = app.buttons["sample-02"]
    XCTAssertTrue(sample.waitForExistence(timeout: 5))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 8))
    XCTAssertTrue(app.descendants(matching: .any)["garment-observation-hint"].exists)
    app.buttons["save-today"].tap()
    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 3))
    app.buttons["make-another"].tap()

    app.tabBars.buttons["衣橱"].tap()
    XCTAssertEqual(app.buttons.matching(identifier: "wardrobe-item-card").count, 1)

    app.tabBars.buttons["花历"].tap()
    let recordCard = app.buttons.matching(identifier: "bloom-record-card").firstMatch
    XCTAssertTrue(recordCard.waitForExistence(timeout: 5))
    recordCard.tap()

    let section = app.staticTexts["garment-observation-section"]
    XCTAssertTrue(section.waitForExistence(timeout: 5))
    let candidate = app.buttons["garment-candidate-棕色上装"]
    for _ in 0..<4 where !candidate.isHittable {
      app.swipeUp()
    }
    XCTAssertTrue(candidate.waitForExistence(timeout: 3))
    XCTAssertTrue(candidate.isHittable)
    keepScreenshot(named: "Adonis-outfit-candidate")

    candidate.tap()
    XCTAssertTrue(app.staticTexts["garment-linked-upperBody"].waitForExistence(timeout: 3))
    keepScreenshot(named: "Adonis-outfit-linked")

    app.buttons["garment-reject-upperBody"].tap()
    XCTAssertTrue(app.buttons["garment-new-upperBody"].waitForExistence(timeout: 3))
    XCTAssertFalse(candidate.exists)
    app.buttons["garment-new-upperBody"].tap()
    XCTAssertTrue(app.staticTexts["garment-linked-upperBody"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["已收进衣橱"].exists)

    app.buttons["完成"].tap()
    app.tabBars.buttons["衣橱"].tap()
    XCTAssertEqual(app.buttons.matching(identifier: "wardrobe-item-card").count, 2)
  }

  @MainActor
  private func keepScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
