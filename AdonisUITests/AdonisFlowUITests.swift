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
  func testImageSharedFromAnotherAppAutomaticallyJoinsWardrobe() {
    let app = XCUIApplication()
    app.launchArguments.append(contentsOf: ["-ui-testing", "-ui-testing-shared-import"])
    app.launch()

    let notice = app.staticTexts["shared-import-notice"]
    XCTAssertTrue(notice.waitForExistence(timeout: 10))
    XCTAssertEqual(notice.label, "已收进衣橱 · 1 件")
    XCTAssertTrue(app.tabBars.buttons["衣橱"].isSelected)
    XCTAssertTrue(app.staticTexts["棕色单品"].exists)
    XCTAssertEqual(app.buttons.matching(identifier: "wardrobe-item-card").count, 1)
    keepScreenshot(named: "Adonis-shared-wardrobe-import")
  }

  @MainActor
  func testSystemShareExtensionCarriesImageAcrossAppGroupBoundary() {
    let app = XCUIApplication()
    app.launchArguments.append(
      contentsOf: ["-ui-testing", "-ui-testing-system-share-extension"]
    )
    app.launch()

    app.tabBars.buttons["衣橱"].tap()
    let openShare = app.buttons["open-system-share-test"]
    XCTAssertTrue(openShare.waitForExistence(timeout: 6))
    openShare.tap()

    let shareAction = app.cells["Adonis"]
    XCTAssertTrue(shareAction.waitForExistence(timeout: 8))
    shareAction.tap()

    let extensionFailure = app.staticTexts["这次没有收好"]
    if extensionFailure.waitForExistence(timeout: 4) {
      XCTFail(app.staticTexts["share-extension-detail"].label)
      return
    }

    let notice = app.staticTexts["shared-import-notice"]
    XCTAssertTrue(notice.waitForExistence(timeout: 12))
    XCTAssertEqual(notice.label, "已收进衣橱 · 1 件")
    XCTAssertEqual(app.buttons.matching(identifier: "wardrobe-item-card").count, 1)
    keepScreenshot(named: "Adonis-system-share-extension-result")
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

    let upgrade = app.buttons["wardrobe-image-upgrade-test-upperBody"]
    for _ in 0..<5 where !upgrade.isHittable {
      app.swipeUp()
    }
    XCTAssertTrue(upgrade.waitForExistence(timeout: 3))
    XCTAssertTrue(upgrade.isHittable)
    upgrade.tap()
    XCTAssertTrue(
      app.staticTexts["wardrobe-image-upgrade-success-upperBody"].waitForExistence(timeout: 8)
    )
    XCTAssertTrue(app.staticTexts["蓝色上装"].exists)
    let upgradedSource = app.staticTexts["wardrobe-image-upgrade-source-upperBody"]
    XCTAssertTrue(upgradedSource.exists)
    XCTAssertTrue(upgradedSource.label.contains("像商品图"))
    keepScreenshot(named: "Adonis-outfit-product-image-upgrade")

    app.buttons["完成"].tap()
    app.tabBars.buttons["衣橱"].tap()
    XCTAssertEqual(app.buttons.matching(identifier: "wardrobe-item-card").count, 2)
    XCTAssertTrue(app.staticTexts["蓝色上装"].exists)
  }

  @MainActor
  func testWardrobeItemCanExplicitlyReconnectPastOutfit() {
    let app = XCUIApplication()
    app.launchArguments.append(contentsOf: ["-ui-testing", "-ui-testing-wardrobe-import"])
    app.launch()

    let sample = app.buttons["sample-02"]
    XCTAssertTrue(sample.waitForExistence(timeout: 5))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 8))
    app.buttons["save-today"].tap()
    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 3))
    app.buttons["make-another"].tap()

    app.tabBars.buttons["衣橱"].tap()
    XCTAssertEqual(app.buttons.matching(identifier: "wardrobe-item-card").count, 0)
    let addTestItem = app.buttons["add-test-wardrobe-item"]
    XCTAssertTrue(addTestItem.waitForExistence(timeout: 5))
    addTestItem.tap()
    XCTAssertTrue(app.staticTexts["wardrobe-analysis-summary"].waitForExistence(timeout: 8))
    for _ in 0..<3 {
      app.swipeUp()
    }
    app.buttons["wardrobe-category-上装"].tap()
    XCTAssertTrue(app.staticTexts["棕色上装"].waitForExistence(timeout: 3))
    app.buttons["完成"].tap()

    XCTAssertEqual(app.buttons.matching(identifier: "wardrobe-item-card").count, 1)
    app.buttons.matching(identifier: "wardrobe-item-card").firstMatch.tap()

    let confirm = app.buttons["wardrobe-history-confirm"]
    for _ in 0..<4 where !confirm.isHittable {
      app.swipeUp()
    }
    XCTAssertTrue(confirm.waitForExistence(timeout: 4))
    app.swipeUp()
    XCTAssertTrue(confirm.isHittable)
    keepScreenshot(named: "Adonis-wardrobe-history-candidate")
    confirm.tap()

    XCTAssertTrue(app.staticTexts["wardrobe-history-linked"].waitForExistence(timeout: 4))
    XCTAssertTrue(app.staticTexts["wardrobe-history-linked"].label.contains("1 天"))
    keepScreenshot(named: "Adonis-wardrobe-history-linked")

    app.buttons["完成"].tap()
    app.tabBars.buttons["花历"].tap()
    let recordCard = app.buttons.matching(identifier: "bloom-record-card").firstMatch
    XCTAssertTrue(recordCard.waitForExistence(timeout: 5))
    recordCard.tap()

    let linked = app.staticTexts["garment-linked-upperBody"]
    for _ in 0..<4 where !linked.exists {
      app.swipeUp()
    }
    XCTAssertTrue(linked.waitForExistence(timeout: 4))
  }

  @MainActor
  private func keepScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
