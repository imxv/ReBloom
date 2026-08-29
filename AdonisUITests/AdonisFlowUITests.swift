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
  private func keepScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
