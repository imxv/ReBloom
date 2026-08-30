import Foundation
import XCTest

final class AdonisFlowUITests: XCTestCase {
  @MainActor
  func testCuratedStyleGardenSelectsPersistsAndReopensFloralSketch() {
    let app = XCUIApplication()
    let persistentStoreID = UUID().uuidString
    app.launchArguments.append(
      contentsOf: [
        "-ui-testing",
        "-ui-testing-persistent-store",
        persistentStoreID,
        "-ui-testing-system-creative",
      ]
    )
    app.launch()

    let sample = app.buttons["sample-01"]
    XCTAssertTrue(sample.waitForExistence(timeout: 8))
    XCTAssertTrue(scrollToHittable(sample, in: app, attempts: 8))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 10))

    let garden = app.buttons["curated-style-garden-entry"]
    XCTAssertTrue(scrollToHittable(garden, in: app, attempts: 12))
    garden.tap()

    let picker = app.descendants(matching: .any)["curated-style-picker"]
    XCTAssertTrue(picker.waitForExistence(timeout: 4))
    let mythic = app.buttons["curated-style-option-mythic_garden"]
    let sketch = app.buttons["curated-style-option-floral_sketch"]
    let theater = app.buttons["curated-style-option-moonlit_theater"]
    XCTAssertTrue(mythic.exists)
    XCTAssertTrue(sketch.exists)
    XCTAssertTrue(theater.exists)
    keepScreenshot(named: "Adonis-curated-style-picker")
    XCTAssertTrue(scrollToHittable(sketch, in: app, attempts: 5))
    sketch.tap()

    let processing = app.descendants(matching: .any)["system-creative-processing"]
    XCTAssertTrue(processing.waitForExistence(timeout: 3))
    let status = app.descendants(matching: .any)["system-creative-status"]
    XCTAssertTrue(status.exists)
    XCTAssertTrue(status.label.contains("花神速写"))

    let preview = app.descendants(matching: .any)["creative-work-preview"]
    XCTAssertTrue(preview.waitForExistence(timeout: 8))
    XCTAssertTrue(preview.label.contains("花神速写"))
    let provenance = app.descendants(matching: .any)["creative-work-provenance"]
    XCTAssertTrue(scrollToHittable(provenance, in: app, attempts: 8))
    XCTAssertTrue(provenance.label.contains("AI 生成"))
    let boundary = app.descendants(matching: .any)["creative-work-boundary"]
    XCTAssertTrue(scrollToHittable(boundary, in: app, attempts: 5))
    XCTAssertTrue(boundary.label.contains("人物和衣服都可能改变"))

    selectCreativeWorkPreview(
      assetID: "originalPhoto",
      title: "原始照片",
      preview: preview,
      in: app
    )
    selectCreativeWorkPreview(
      assetID: "work",
      title: "花神速写",
      preview: preview,
      in: app
    )

    let save = app.buttons["save-creative-work"]
    XCTAssertTrue(scrollToHittable(save, in: app, attempts: 8))
    save.tap()
    XCTAssertTrue(app.buttons["作品已经收藏"].waitForExistence(timeout: 5))
    let share = app.buttons["share-creative-work"]
    XCTAssertTrue(scrollToHittable(share, in: app, attempts: 5))
    share.tap()
    XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 8))
    app.buttons["关闭"].tap()
    let closeWork = app.buttons["close-creative-work"]
    XCTAssertTrue(scrollDownToHittable(closeWork, in: app, attempts: 8))
    closeWork.tap()

    app.terminate()
    app.launch()
    app.tabBars.buttons["花历"].tap()
    let record = app.buttons.matching(identifier: "bloom-record-card").firstMatch
    XCTAssertTrue(record.waitForExistence(timeout: 5))
    record.tap()
    let savedEntry = app.buttons["creative-work-history-entry"]
    XCTAssertTrue(scrollToHittable(savedEntry, in: app, attempts: 10))
    XCTAssertTrue(savedEntry.label.contains("花神速写"))
    savedEntry.tap()
    XCTAssertTrue(preview.waitForExistence(timeout: 5))
    XCTAssertTrue(preview.label.contains("花神速写"))
    keepScreenshot(named: "Adonis-floral-sketch-fixture-history")
  }

  @MainActor
  func testUnavailableSystemCreationDoesNotShowADeadEntry() {
    let app = XCUIApplication()
    app.launchArguments.append(
      contentsOf: ["-ui-testing", "-ui-testing-system-creative-unavailable"]
    )
    app.launch()

    let sample = app.buttons["sample-01"]
    XCTAssertTrue(sample.waitForExistence(timeout: 8))
    XCTAssertTrue(scrollToHittable(sample, in: app, attempts: 8))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["curated-style-garden-entry"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.buttons["botanical-poster-entry"].exists)
  }

  @MainActor
  func testSystemCreationTimeoutStopsWaitingAndKeepsOriginalResult() {
    let app = XCUIApplication()
    app.launchArguments.append(
      contentsOf: [
        "-ui-testing",
        "-ui-testing-system-creative",
        "-ui-testing-system-creative-never-finishes",
        "-ui-testing-system-creative-timeout",
      ]
    )
    app.launch()

    let sample = app.buttons["sample-01"]
    XCTAssertTrue(sample.waitForExistence(timeout: 8))
    XCTAssertTrue(scrollToHittable(sample, in: app, attempts: 8))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 10))

    let entry = beginCuratedStyle("mythic_garden", in: app)
    let processing = app.descendants(matching: .any)["system-creative-processing"]
    XCTAssertTrue(processing.waitForExistence(timeout: 3))
    XCTAssertTrue(app.alerts["作品还没做好"].waitForExistence(timeout: 6))
    XCTAssertTrue(
      app.staticTexts["等了 90 秒仍没有完成，这次已经停止；原照片和贴纸没有改变。"].exists
    )
    app.buttons["知道了"].tap()

    XCTAssertTrue(processing.waitForNonExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["result-title"].exists)
    XCTAssertTrue(entry.exists)
    XCTAssertFalse(app.descendants(matching: .any)["creative-work-preview"].exists)
  }

  @MainActor
  func testAvailableSystemCreationBuildsReviewableMythicGardenAndPersistsIt() {
    let app = XCUIApplication()
    let persistentStoreID = UUID().uuidString
    app.launchArguments.append(
      contentsOf: [
        "-ui-testing",
        "-ui-testing-persistent-store",
        persistentStoreID,
        "-ui-testing-system-creative",
      ]
    )
    app.launch()

    let sample = app.buttons["sample-01"]
    XCTAssertTrue(sample.waitForExistence(timeout: 8))
    XCTAssertTrue(scrollToHittable(sample, in: app, attempts: 8))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 10))

    _ = beginCuratedStyle("mythic_garden", in: app)
    XCTAssertTrue(
      app.descendants(matching: .any)["system-creative-processing"].waitForExistence(
        timeout: 3
      )
    )

    let preview = app.descendants(matching: .any)["creative-work-preview"]
    XCTAssertTrue(preview.waitForExistence(timeout: 8))
    XCTAssertTrue(preview.label.contains("永生花园"))
    let provenance = app.descendants(matching: .any)["creative-work-provenance"]
    XCTAssertTrue(scrollToHittable(provenance, in: app, attempts: 8))
    XCTAssertTrue(provenance.label.contains("AI 生成"))
    let boundary = app.descendants(matching: .any)["creative-work-boundary"]
    XCTAssertTrue(scrollToHittable(boundary, in: app, attempts: 5))
    XCTAssertTrue(boundary.label.contains("人物和衣服都可能改变"))

    selectCreativeWorkPreview(
      assetID: "originalPhoto",
      title: "原始照片",
      preview: preview,
      in: app
    )
    selectCreativeWorkPreview(
      assetID: "work",
      title: "永生花园",
      preview: preview,
      in: app
    )

    let save = app.buttons["save-creative-work"]
    XCTAssertTrue(scrollToHittable(save, in: app, attempts: 8))
    save.tap()
    XCTAssertTrue(app.buttons["作品已经收藏"].waitForExistence(timeout: 5))

    let share = app.buttons["share-creative-work"]
    XCTAssertTrue(scrollToHittable(share, in: app, attempts: 5))
    share.tap()
    XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 8))
    app.buttons["关闭"].tap()
    let closeWork = app.buttons["close-creative-work"]
    XCTAssertTrue(scrollDownToHittable(closeWork, in: app, attempts: 8))
    closeWork.tap()

    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 4))
    app.terminate()
    app.launch()
    app.tabBars.buttons["花历"].tap()

    let record = app.buttons.matching(identifier: "bloom-record-card").firstMatch
    XCTAssertTrue(record.waitForExistence(timeout: 5))
    record.tap()
    let savedEntry = app.buttons["creative-work-history-entry"]
    XCTAssertTrue(scrollToHittable(savedEntry, in: app, attempts: 10))
    XCTAssertTrue(savedEntry.label.contains("永生花园"))
    savedEntry.tap()
    XCTAssertTrue(preview.waitForExistence(timeout: 5))
    XCTAssertTrue(preview.label.contains("永生花园"))
    XCTAssertTrue(scrollToHittable(provenance, in: app, attempts: 8))
    XCTAssertTrue(provenance.label.contains("AI 生成"))
    keepScreenshot(named: "Adonis-mythic-garden-fixture-history")
  }

  @MainActor
  func testSystemCreationCanBeCancelledWithoutChangingOriginalResult() {
    let app = XCUIApplication()
    app.launchArguments.append(
      contentsOf: [
        "-ui-testing",
        "-ui-testing-system-creative",
        "-ui-testing-system-creative-never-finishes",
      ]
    )
    app.launch()

    let sample = app.buttons["sample-01"]
    XCTAssertTrue(sample.waitForExistence(timeout: 8))
    XCTAssertTrue(scrollToHittable(sample, in: app, attempts: 8))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 10))

    let entry = beginCuratedStyle("mythic_garden", in: app)
    let processing = app.descendants(matching: .any)["system-creative-processing"]
    XCTAssertTrue(processing.waitForExistence(timeout: 3))
    app.buttons["system-creative-cancel"].tap()
    XCTAssertTrue(processing.waitForNonExistence(timeout: 4))
    XCTAssertTrue(app.staticTexts["result-title"].exists)
    XCTAssertTrue(entry.exists)
    XCTAssertFalse(app.descendants(matching: .any)["creative-work-preview"].exists)
  }

  @MainActor
  func testGeneratedStickerCreatesTraceableBotanicalPosterReadyToCompareSaveAndShare() {
    let app = XCUIApplication()
    let persistentStoreID = UUID().uuidString
    app.launchArguments.append(
      contentsOf: ["-ui-testing", "-ui-testing-persistent-store", persistentStoreID]
    )
    app.launch()

    let sample = app.buttons["sample-01"]
    XCTAssertTrue(sample.waitForExistence(timeout: 8))
    XCTAssertTrue(scrollToHittable(sample, in: app, attempts: 8))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 10))

    let entry = app.buttons["botanical-poster-entry"]
    XCTAssertTrue(scrollToHittable(entry, in: app, attempts: 10))
    entry.tap()

    let preview = app.descendants(matching: .any)["creative-work-preview"]
    XCTAssertTrue(preview.waitForExistence(timeout: 6))
    XCTAssertTrue(preview.label.contains("花影海报"))
    let provenance = app.descendants(matching: .any)["creative-work-provenance"]
    XCTAssertTrue(scrollToHittable(provenance, in: app, attempts: 8))
    XCTAssertTrue(provenance.label.contains("不含 AI 重绘"))

    selectCreativeWorkPreview(
      assetID: "originalPhoto",
      title: "原始照片",
      preview: preview,
      in: app
    )
    selectCreativeWorkPreview(
      assetID: "work",
      title: "花影海报",
      preview: preview,
      in: app
    )

    let save = app.buttons["save-creative-work"]
    XCTAssertTrue(scrollToHittable(save, in: app, attempts: 8))
    save.tap()
    XCTAssertTrue(app.buttons["作品已经收藏"].waitForExistence(timeout: 5))

    let share = app.buttons["share-creative-work"]
    XCTAssertTrue(scrollToHittable(share, in: app, attempts: 5))
    share.tap()
    XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 8))
    app.buttons["关闭"].tap()
    app.buttons["close-creative-work"].tap()

    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 4))
    app.terminate()
    app.launch()
    app.tabBars.buttons["花历"].tap()

    let record = app.buttons.matching(identifier: "bloom-record-card").firstMatch
    XCTAssertTrue(record.waitForExistence(timeout: 5))
    record.tap()

    let savedEntry = app.buttons["creative-work-history-entry"]
    XCTAssertTrue(scrollToHittable(savedEntry, in: app, attempts: 10))
    savedEntry.tap()
    XCTAssertTrue(preview.waitForExistence(timeout: 5))
    XCTAssertTrue(preview.label.contains("花影海报"))
    XCTAssertTrue(scrollToHittable(provenance, in: app, attempts: 8))
    XCTAssertTrue(provenance.label.contains("不含 AI 重绘"))
    keepScreenshot(named: "Adonis-botanical-poster-history")
  }

  @MainActor
  func testDeniedCameraPermissionOffersSettingsWithoutOpeningCamera() {
    let app = XCUIApplication()
    app.launchArguments.append(contentsOf: ["-ui-testing", "-ui-testing-camera-denied"])
    app.launch()

    let camera = app.buttons["take-photo"]
    XCTAssertTrue(camera.waitForExistence(timeout: 8))
    camera.tap()

    let alert = app.alerts["需要相机权限"]
    XCTAssertTrue(alert.waitForExistence(timeout: 4))
    XCTAssertTrue(
      app.staticTexts[
        "要拍一张新照片，请先在系统设置里允许 Adonis 使用相机。你也可以继续从相册选择。"
      ].exists
    )
    XCTAssertTrue(alert.buttons["打开系统设置"].exists)
    XCTAssertTrue(alert.buttons["先不用"].exists)
    XCTAssertFalse(app.descendants(matching: .any)["camera-picker"].exists)
    keepScreenshot(named: "Adonis-camera-permission-denied")
  }

  @MainActor
  func testRestrictedCameraPermissionKeepsAlbumAlternativeWithoutSettingsShortcut() {
    let app = XCUIApplication()
    app.launchArguments.append(contentsOf: ["-ui-testing", "-ui-testing-camera-restricted"])
    app.launch()

    let camera = app.buttons["take-photo"]
    XCTAssertTrue(camera.waitForExistence(timeout: 8))
    camera.tap()

    let alert = app.alerts["这台 iPhone 限制了相机"]
    XCTAssertTrue(alert.waitForExistence(timeout: 4))
    XCTAssertTrue(
      app.staticTexts["当前系统限制不允许 Adonis 使用相机。你仍然可以从相册选择照片。"].exists
    )
    XCTAssertTrue(alert.buttons["知道了"].exists)
    XCTAssertFalse(alert.buttons["打开系统设置"].exists)
    XCTAssertFalse(app.descendants(matching: .any)["camera-picker"].exists)
    keepScreenshot(named: "Adonis-camera-permission-restricted")
  }

  @MainActor
  func testAccessibleCoreFlowSurvivesBackgroundAndKeepsActionsReachable() {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-testing")
    app.launch()

    let hero = app.descendants(matching: .any)["create-hero"]
    XCTAssertTrue(hero.waitForExistence(timeout: 8))
    XCTAssertTrue(hero.label.contains("一张照片"))
    XCTAssertTrue(hero.label.contains("保留原来的你"))
    keepScreenshot(named: "Adonis-accessibility-create")

    let firstSample = app.buttons["sample-01"]
    XCTAssertTrue(firstSample.waitForExistence(timeout: 5))
    XCTAssertTrue(scrollToHittable(firstSample, in: app, attempts: 8))
    firstSample.tap()

    let resultTitle = app.staticTexts["result-title"]
    XCTAssertTrue(resultTitle.waitForExistence(timeout: 10))
    XCTAssertEqual(resultTitle.label, "今天开了一朵花")
    let resultModeMenu = app.descendants(matching: .any)["result-mode-menu"]
    let resultModePicker = app.segmentedControls["result-mode-picker"]
    XCTAssertTrue(resultModeMenu.exists || resultModePicker.exists)
    keepScreenshot(named: "Adonis-accessibility-result")

    XCUIDevice.shared.press(.home)
    let backgroundExpectation = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in app.state != .runningForeground },
      object: nil
    )
    XCTAssertEqual(XCTWaiter.wait(for: [backgroundExpectation], timeout: 3), .completed)
    app.activate()
    XCTAssertTrue(resultTitle.waitForExistence(timeout: 8))

    let figurineEntry = app.buttons["digital-figurine-card-entry"]
    XCTAssertTrue(figurineEntry.waitForExistence(timeout: 4))
    XCTAssertTrue(scrollToHittable(figurineEntry, in: app, attempts: 8))
    figurineEntry.tap()

    let figurinePreview = app.descendants(matching: .any)["digital-figurine-card-preview"]
    XCTAssertTrue(figurinePreview.waitForExistence(timeout: 6))
    let figurineBoundary = app.descendants(matching: .any)["digital-figurine-card-boundary"]
    XCTAssertTrue(scrollToHittable(figurineBoundary, in: app, attempts: 10))
    XCTAssertTrue(figurineBoundary.label.contains("不是可旋转的 3D 模型"))
    let figurineShare = app.buttons["share-digital-figurine-card"]
    XCTAssertTrue(scrollToHittable(figurineShare, in: app, attempts: 5))
    XCTAssertTrue(figurineShare.isHittable)
    app.buttons["close-digital-figurine-card"].tap()

    let saveButton = app.buttons["save-today"]
    XCTAssertTrue(saveButton.waitForExistence(timeout: 4))
    XCTAssertTrue(scrollToHittable(saveButton, in: app, attempts: 8))
    saveButton.tap()
    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 4))

    let makeAnother = app.buttons["make-another"]
    XCTAssertTrue(scrollToHittable(makeAnother, in: app, attempts: 4))
    makeAnother.tap()

    app.tabBars.buttons["花历"].tap()
    let lookbookEntry = app.buttons["monthly-lookbook-entry"]
    XCTAssertTrue(lookbookEntry.waitForExistence(timeout: 5))
    XCTAssertTrue(scrollToHittable(lookbookEntry, in: app, attempts: 8))
    lookbookEntry.tap()

    let lookbookPreview = app.descendants(matching: .any)["monthly-lookbook-preview"]
    XCTAssertTrue(lookbookPreview.waitForExistence(timeout: 5))
    let lookbookProvenance =
      app.descendants(matching: .any)["content-provenance-programmatic_composition"]
    XCTAssertTrue(scrollToHittable(lookbookProvenance, in: app, attempts: 8))
    XCTAssertTrue(lookbookProvenance.label.contains("没有补画人物或衣物"))
    let lookbookShare = app.buttons["share-monthly-lookbook"]
    XCTAssertTrue(scrollToHittable(lookbookShare, in: app, attempts: 5))
    XCTAssertTrue(lookbookShare.isHittable)
    app.buttons["完成"].tap()

    let seasonalEntry = app.buttons["seasonal-bloom-entry"]
    XCTAssertTrue(seasonalEntry.waitForExistence(timeout: 5))
    for _ in 0..<6 where !seasonalEntry.isHittable {
      app.swipeDown()
    }
    XCTAssertTrue(seasonalEntry.isHittable)
    seasonalEntry.tap()

    XCTAssertTrue(
      app.descendants(matching: .any)["seasonal-bloom-archive"]
        .waitForExistence(timeout: 5)
    )
    let seasonalGroup = app.buttons.matching(identifier: "seasonal-bloom-group").firstMatch
    XCTAssertTrue(scrollToHittable(seasonalGroup, in: app, attempts: 8))
    seasonalGroup.tap()
    let seasonalRecord = app.buttons.matching(identifier: "seasonal-bloom-record").firstMatch
    XCTAssertTrue(scrollToHittable(seasonalRecord, in: app, attempts: 8))
    XCTAssertTrue(seasonalRecord.label.contains("Bloom No."))
    app.buttons["close-seasonal-bloom"].tap()

    let cabinetEntry = app.buttons["digital-cabinet-entry"]
    XCTAssertTrue(cabinetEntry.waitForExistence(timeout: 5))
    for _ in 0..<5 where !cabinetEntry.isHittable {
      app.swipeDown()
    }
    XCTAssertTrue(cabinetEntry.isHittable)
    cabinetEntry.tap()

    XCTAssertTrue(
      app.descendants(matching: .any)["digital-cabinet-screen"]
        .waitForExistence(timeout: 5)
    )
    let cabinetBoundary = app.descendants(matching: .any)["digital-cabinet-boundary"]
    XCTAssertTrue(scrollToHittable(cabinetBoundary, in: app, attempts: 8))
    XCTAssertTrue(cabinetBoundary.label.contains("不是可旋转的 3D 模型"))
    let cabinetOutfit = app.buttons.matching(identifier: "digital-cabinet-outfit").firstMatch
    XCTAssertTrue(scrollToHittable(cabinetOutfit, in: app, attempts: 8))
    XCTAssertTrue(cabinetOutfit.label.contains("Bloom No."))
    app.buttons["close-digital-cabinet"].tap()

    app.tabBars.buttons["衣橱"].tap()
    let addFirstItem = app.buttons["add-first-wardrobe-item"]
    XCTAssertTrue(addFirstItem.waitForExistence(timeout: 5))
    XCTAssertTrue(scrollToHittable(addFirstItem, in: app, attempts: 8))
    keepScreenshot(named: "Adonis-accessibility-wardrobe")
  }

  @MainActor
  func testProcessingOverlayKeepsCancelReachable() {
    let app = XCUIApplication()
    app.launchArguments.append(contentsOf: ["-ui-testing", "-ui-testing-hold-generation"])
    app.launch()

    let firstSample = app.buttons["sample-01"]
    XCTAssertTrue(firstSample.waitForExistence(timeout: 8))
    XCTAssertTrue(scrollToHittable(firstSample, in: app, attempts: 8))
    firstSample.tap()

    let overlay = app.descendants(matching: .any)["processing-overlay"]
    XCTAssertTrue(overlay.waitForExistence(timeout: 3))
    let cancel = app.buttons["processing-cancel"]
    XCTAssertTrue(cancel.waitForExistence(timeout: 3))
    XCTAssertTrue(cancel.isHittable)
    cancel.tap()

    XCTAssertTrue(firstSample.waitForExistence(timeout: 4))
    XCTAssertFalse(overlay.exists)

    let settings = app.buttons["本地设置"]
    for _ in 0..<8 where !settings.isHittable {
      app.swipeDown()
    }
    XCTAssertTrue(settings.waitForExistence(timeout: 4))
    XCTAssertTrue(settings.isHittable)
    settings.tap()
    XCTAssertTrue(app.navigationBars["本地设置"].waitForExistence(timeout: 4))

    let latestEvent = app.descendants(matching: .any)["performance-latest-event"]
    XCTAssertTrue(scrollToHittable(latestEvent, in: app, attempts: 8))
    XCTAssertTrue(latestEvent.label.contains("取消处理"))
    let interruptedStage =
      app.descendants(matching: .any)["performance-interrupted-stage"]
    XCTAssertTrue(scrollToHittable(interruptedStage, in: app, attempts: 3))
    XCTAssertTrue(interruptedStage.label.contains("抠图与白边"))
    keepScreenshot(named: "Adonis-performance-cancelled")
  }

  @MainActor
  func testHardTimeoutExitsWaitingAndRejectsLateResult() {
    let app = XCUIApplication()
    app.launchArguments.append(
      contentsOf: [
        "-ui-testing",
        "-ui-testing-hold-generation",
        "-ui-testing-force-generation-timeout",
      ]
    )
    app.launch()

    let firstSample = app.buttons["sample-01"]
    XCTAssertTrue(firstSample.waitForExistence(timeout: 8))
    XCTAssertTrue(scrollToHittable(firstSample, in: app, attempts: 8))
    firstSample.tap()

    let overlay = app.descendants(matching: .any)["processing-overlay"]
    XCTAssertTrue(overlay.waitForExistence(timeout: 3))
    let timeoutAlert = app.alerts["这次等得有点久"]
    XCTAssertTrue(timeoutAlert.waitForExistence(timeout: 5))
    XCTAssertTrue(
      app.staticTexts["处理超过 90 秒，已经停止等待。可以再试一次，或换一张照片。"].exists
    )
    XCTAssertTrue(timeoutAlert.buttons["再试一次"].exists)
    XCTAssertTrue(timeoutAlert.buttons["换一张照片"].exists)
    keepScreenshot(named: "Adonis-generation-timeout-alert")
    timeoutAlert.buttons["换一张照片"].tap()

    XCTAssertFalse(overlay.exists)
    let settings = app.buttons["本地设置"]
    for _ in 0..<8 where !settings.isHittable {
      app.swipeDown()
    }
    XCTAssertTrue(settings.waitForExistence(timeout: 4))
    settings.tap()
    XCTAssertTrue(app.navigationBars["本地设置"].waitForExistence(timeout: 4))

    let lateResultWait = expectation(description: "迟到处理有机会返回")
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
      lateResultWait.fulfill()
    }
    wait(for: [lateResultWait], timeout: 4)

    XCTAssertTrue(app.navigationBars["本地设置"].exists)
    XCTAssertFalse(app.staticTexts["result-title"].exists)
    let latestEvent = app.descendants(matching: .any)["performance-latest-event"]
    XCTAssertTrue(scrollToHittable(latestEvent, in: app, attempts: 8))
    XCTAssertTrue(latestEvent.label.contains("处理超时"))
    keepScreenshot(named: "Adonis-generation-timeout")
  }

  @MainActor
  func testTimeoutDeliversAndPersistsValidatedBasicStickerFallback() {
    let app = XCUIApplication()
    app.launchArguments.append(
      contentsOf: ["-ui-testing", "-ui-testing-force-generation-fallback-timeout"]
    )
    app.launch()

    let firstSample = app.buttons["sample-01"]
    XCTAssertTrue(firstSample.waitForExistence(timeout: 8))
    XCTAssertTrue(scrollToHittable(firstSample, in: app, attempts: 8))
    firstSample.tap()

    let resultTitle = app.staticTexts["result-title"]
    XCTAssertTrue(resultTitle.waitForExistence(timeout: 10))
    XCTAssertEqual(resultTitle.label, "先收下这张贴纸")
    let fallbackNotice = app.descendants(matching: .any)["generation-fallback-notice"]
    XCTAssertTrue(fallbackNotice.exists)
    XCTAssertTrue(fallbackNotice.label.contains("衣物线索"))
    XCTAssertFalse(app.descendants(matching: .any)["garment-observation-hint"].exists)
    XCTAssertTrue(scrollToHittable(fallbackNotice, in: app, attempts: 5))
    keepScreenshot(named: "Adonis-generation-fallback-result")

    let save = app.buttons["save-today"]
    XCTAssertTrue(scrollToHittable(save, in: app, attempts: 8))
    save.tap()
    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 3))
    let makeAnother = app.buttons["make-another"]
    XCTAssertTrue(scrollToHittable(makeAnother, in: app, attempts: 5))
    makeAnother.tap()

    app.tabBars.buttons["花历"].tap()
    let record = app.buttons.matching(identifier: "bloom-record-card").firstMatch
    XCTAssertTrue(record.waitForExistence(timeout: 5))
    record.tap()
    let historyNotice =
      app.descendants(matching: .any)["history-generation-fallback-notice"]
    XCTAssertTrue(historyNotice.waitForExistence(timeout: 5))
    XCTAssertTrue(historyNotice.label.contains("基础贴纸"))
    keepScreenshot(named: "Adonis-generation-fallback-history")
  }

  @MainActor
  func testLocalPerformanceTraceShowsBudgetAndStages() {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-testing")
    app.launch()

    let firstSample = app.buttons["sample-01"]
    XCTAssertTrue(firstSample.waitForExistence(timeout: 8))
    XCTAssertTrue(scrollToHittable(firstSample, in: app, attempts: 8))
    firstSample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 10))

    let makeAnother = app.buttons["make-another"]
    XCTAssertTrue(scrollToHittable(makeAnother, in: app, attempts: 5))
    makeAnother.tap()
    XCTAssertTrue(firstSample.waitForExistence(timeout: 5))

    let settings = app.buttons["本地设置"]
    for _ in 0..<8 where !settings.isHittable {
      app.swipeDown()
    }
    XCTAssertTrue(settings.isHittable)
    settings.tap()
    XCTAssertTrue(app.navigationBars["本地设置"].waitForExistence(timeout: 4))

    let budget = app.descendants(matching: .any)["performance-budget-summary"]
    XCTAssertTrue(scrollToHittable(budget, in: app, attempts: 8))
    XCTAssertTrue(budget.label.contains("45 秒目标内"))
    XCTAssertTrue(budget.label.contains("1 / 1 次"))

    let latestEvent = app.descendants(matching: .any)["performance-latest-event"]
    XCTAssertTrue(scrollToHittable(latestEvent, in: app, attempts: 3))
    XCTAssertTrue(latestEvent.label.contains("处理成功"))

    let latestStage = app.descendants(matching: .any)["performance-latest-stage"]
    XCTAssertTrue(scrollToHittable(latestStage, in: app, attempts: 3))
    XCTAssertFalse(latestStage.label.isEmpty)
    let externalCost = app.descendants(matching: .any)["performance-external-cost"]
    XCTAssertTrue(scrollToHittable(externalCost, in: app, attempts: 3))
    XCTAssertTrue(externalCost.label.contains("不适用（全本机）"))
    keepScreenshot(named: "Adonis-performance-budget")
  }

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
    XCTAssertFalse(
      app.descendants(matching: .any)["sticker-quality-review_recommended"].exists
    )
    XCTAssertTrue(
      app.descendants(matching: .any)["content-provenance-programmatic_composition"]
        .waitForExistence(timeout: 3)
    )

    let resultModes = app.segmentedControls["result-mode-picker"]
    XCTAssertTrue(resultModes.buttons["透明贴纸"].waitForExistence(timeout: 3))
    resultModes.buttons["透明贴纸"].tap()
    XCTAssertTrue(
      app.descendants(matching: .any)["content-provenance-derived_from_original"]
        .waitForExistence(timeout: 3)
    )
    resultModes.buttons["原始照片"].tap()
    XCTAssertTrue(
      app.descendants(matching: .any)["content-provenance-user_provided"]
        .waitForExistence(timeout: 3)
    )
    resultModes.buttons["收藏卡"].tap()

    let resultProvenance =
      app.descendants(matching: .any)["content-provenance-programmatic_composition"]
    for _ in 0..<3 where !resultProvenance.isHittable {
      app.swipeUp()
    }
    XCTAssertTrue(resultProvenance.isHittable)
    keepScreenshot(named: "Adonis-content-provenance-result")

    let saveButton = app.buttons["save-today"]
    XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
    for _ in 0..<3 where !saveButton.isHittable {
      app.swipeUp()
    }
    saveButton.tap()
    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 3))

    let makeAnother = app.buttons["make-another"]
    XCTAssertTrue(makeAnother.waitForExistence(timeout: 3))
    for _ in 0..<2 where !makeAnother.isHittable {
      app.swipeUp()
    }
    makeAnother.tap()
    XCTAssertTrue(app.buttons["sample-01"].waitForExistence(timeout: 5))

    app.tabBars.buttons["花历"].tap()
    XCTAssertTrue(app.otherElements["bloom-calendar"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["recent-blooms-title"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["今日穿搭"].exists)

    let recordCard = app.buttons.matching(identifier: "bloom-record-card").firstMatch
    XCTAssertTrue(recordCard.waitForExistence(timeout: 5))
    recordCard.tap()
    let historyModes = app.segmentedControls["history-visual-picker"]
    XCTAssertTrue(historyModes.buttons["收藏卡"].waitForExistence(timeout: 5))
    XCTAssertTrue(historyModes.buttons["透明贴纸"].exists)
    XCTAssertTrue(historyModes.buttons["原始照片"].exists)
    let historyProvenance =
      app.descendants(matching: .any)["content-provenance-programmatic_composition"]
    XCTAssertTrue(historyProvenance.waitForExistence(timeout: 3))
    for _ in 0..<3 where !historyProvenance.isHittable {
      app.swipeUp()
    }
    XCTAssertTrue(historyProvenance.isHittable)
    keepScreenshot(named: "Adonis-content-provenance-history")

    let historyFigurineEntry = app.buttons["digital-figurine-card-entry"]
    XCTAssertTrue(scrollToHittable(historyFigurineEntry, in: app, attempts: 4))
    historyFigurineEntry.tap()
    XCTAssertTrue(
      app.descendants(matching: .any)["digital-figurine-card-preview"]
        .waitForExistence(timeout: 6)
    )
    app.buttons["close-digital-figurine-card"].tap()
  }

  @MainActor
  func testGeneratedStickerCreatesShareableDigitalFigurineCardWithoutConfiguration() {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-testing")
    app.launch()

    let sample = app.buttons["sample-01"]
    XCTAssertTrue(sample.waitForExistence(timeout: 5))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 8))

    let entry = app.buttons["digital-figurine-card-entry"]
    XCTAssertTrue(scrollToHittable(entry, in: app, attempts: 5))
    XCTAssertTrue(entry.label.contains("人物和衣服保持原样"))
    entry.tap()

    let preview = app.descendants(matching: .any)["digital-figurine-card-preview"]
    XCTAssertTrue(preview.waitForExistence(timeout: 6))
    XCTAssertTrue(preview.label.contains("Bloom No."))
    keepScreenshot(named: "Adonis-digital-figurine-card")

    let provenance = app.descendants(matching: .any)["digital-figurine-card-provenance"]
    XCTAssertTrue(scrollToHittable(provenance, in: app, attempts: 8))
    XCTAssertTrue(provenance.label.contains("没有重绘人物或衣物"))

    let boundary = app.descendants(matching: .any)["digital-figurine-card-boundary"]
    XCTAssertTrue(scrollToHittable(boundary, in: app, attempts: 4))
    XCTAssertTrue(boundary.label.contains("2.5D 展台卡"))

    let share = app.buttons["share-digital-figurine-card"]
    XCTAssertTrue(scrollToHittable(share, in: app, attempts: 4))
    share.tap()
    XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 8))
  }

  @MainActor
  func testSavedOutfitCreatesMonthlyStickerLookbookReadyToShare() {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-testing")
    app.launch()

    app.tabBars.buttons["花历"].tap()
    XCTAssertTrue(app.otherElements["bloom-calendar"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["monthly-lookbook-entry"].exists)

    app.tabBars.buttons["创作"].tap()
    let sample = app.buttons["sample-01"]
    XCTAssertTrue(sample.waitForExistence(timeout: 5))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 8))

    let saveButton = app.buttons["save-today"]
    XCTAssertTrue(scrollToHittable(saveButton, in: app, attempts: 4))
    saveButton.tap()
    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 3))

    let makeAnother = app.buttons["make-another"]
    XCTAssertTrue(scrollToHittable(makeAnother, in: app, attempts: 4))
    makeAnother.tap()

    app.tabBars.buttons["花历"].tap()
    let entry = app.buttons["monthly-lookbook-entry"]
    XCTAssertTrue(entry.waitForExistence(timeout: 5))
    XCTAssertTrue(scrollToHittable(entry, in: app, attempts: 4))
    XCTAssertTrue(entry.label.contains("共 1 次盛开"))
    entry.tap()

    let preview = app.descendants(matching: .any)["monthly-lookbook-preview"]
    XCTAssertTrue(preview.waitForExistence(timeout: 6))
    XCTAssertTrue(preview.label.contains("包含 1 次盛开"))
    let provenance =
      app.descendants(matching: .any)["content-provenance-programmatic_composition"]
    XCTAssertTrue(provenance.waitForExistence(timeout: 4))
    XCTAssertTrue(provenance.label.contains("没有补画人物或衣物"))
    keepScreenshot(named: "Adonis-monthly-lookbook")

    let share = app.buttons["share-monthly-lookbook"]
    XCTAssertTrue(scrollToHittable(share, in: app, attempts: 5))
    share.tap()
    XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 8))
  }

  @MainActor
  func testConfirmedPiecesFromDifferentOutfitsCreateShareableRebloomSuggestion() {
    let app = XCUIApplication()
    let persistentStoreID = UUID().uuidString
    let baseLaunchArguments = [
      "-ui-testing",
      "-ui-testing-persistent-store",
      persistentStoreID,
    ]
    app.launchArguments = baseLaunchArguments + ["-ui-testing-rebloom-reminder-authorized"]
    app.launch()

    app.tabBars.buttons["花历"].tap()
    XCTAssertTrue(app.otherElements["bloom-calendar"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["rebloom-entry"].exists)

    app.tabBars.buttons["创作"].tap()
    saveSampleAndConfirmGarment(
      "sample-02",
      slot: "upperBody",
      in: app
    )
    XCTAssertFalse(app.buttons["rebloom-entry"].exists)

    app.tabBars.buttons["创作"].tap()
    saveSampleAndConfirmGarment(
      "sample-01",
      slot: "lowerBody",
      in: app
    )

    let entry = app.buttons["rebloom-entry"]
    XCTAssertTrue(entry.waitForExistence(timeout: 5))
    XCTAssertTrue(scrollDownToHittable(entry, in: app, attempts: 12))
    XCTAssertTrue(entry.label.contains("不用选模板"))
    entry.tap()

    XCTAssertTrue(
      app.descendants(matching: .any)["rebloom-screen"]
        .waitForExistence(timeout: 5)
    )
    let provenance = app.descendants(matching: .any)["rebloom-provenance"]
    XCTAssertTrue(provenance.waitForExistence(timeout: 4))
    XCTAssertTrue(provenance.label.contains("没有生成试穿照片"))

    let boundary = app.descendants(matching: .any)["rebloom-boundary"]
    XCTAssertTrue(boundary.waitForExistence(timeout: 4))
    XCTAssertTrue(boundary.label.contains("从未在同一条 OOTD 中确认过"))

    let card = app.descendants(matching: .any)["rebloom-card"]
    XCTAssertTrue(scrollToHittable(card, in: app, attempts: 5))
    XCTAssertTrue(card.label.contains("上装"))
    XCTAssertTrue(card.label.contains("下装"))
    XCTAssertTrue(card.label.contains("今天可以直接照着穿"))
    keepScreenshot(named: "Adonis-rebloom-suggestion")

    let reminderBoundary = app.descendants(matching: .any)["rebloom-reminder-boundary"]
    XCTAssertTrue(reminderBoundary.waitForExistence(timeout: 4))
    XCTAssertTrue(reminderBoundary.label.contains("不会自动重复"))
    XCTAssertTrue(reminderBoundary.label.contains("锁屏文案不显示衣物名称"))
    let reminderToggle = app.buttons["rebloom-reminder-toggle"]
    XCTAssertTrue(scrollToHittable(reminderToggle, in: app, attempts: 8))
    XCTAssertEqual(reminderToggle.label, "7 天后提醒我")

    app.terminate()
    app.launchArguments =
      baseLaunchArguments + [
        "-ui-testing-rebloom-reminder-denied",
        "-ui-testing-open-rebloom-reminder",
      ]
    app.launch()

    XCTAssertTrue(
      app.descendants(matching: .any)["rebloom-screen"]
        .waitForExistence(timeout: 8)
    )
    let deniedReminderToggle = app.buttons["rebloom-reminder-toggle"]
    XCTAssertTrue(scrollToHittable(deniedReminderToggle, in: app, attempts: 8))
    deniedReminderToggle.tap()
    let deniedAlert = app.alerts["通知没有打开"]
    XCTAssertTrue(deniedAlert.waitForExistence(timeout: 4))
    XCTAssertTrue(
      app.staticTexts[
        "通知没有打开。原搭配不会改变；需要时可以在系统设置里允许 Adonis 通知。"
      ].exists
    )
    XCTAssertTrue(deniedAlert.buttons["打开系统设置"].exists)
    XCTAssertTrue(deniedAlert.buttons["先不用"].exists)
    keepScreenshot(named: "Adonis-rebloom-reminder-denied")
    deniedAlert.buttons["先不用"].tap()
    XCTAssertEqual(deniedReminderToggle.label, "7 天后提醒我")

    app.terminate()
    app.launchArguments =
      baseLaunchArguments + [
        "-ui-testing-rebloom-reminder-authorized",
        "-ui-testing-open-rebloom-reminder",
      ]
    app.launch()

    XCTAssertTrue(
      app.descendants(matching: .any)["rebloom-screen"]
        .waitForExistence(timeout: 8)
    )
    let authorizedReminderToggle = app.buttons["rebloom-reminder-toggle"]
    XCTAssertTrue(scrollToHittable(authorizedReminderToggle, in: app, attempts: 8))
    XCTAssertEqual(authorizedReminderToggle.label, "7 天后提醒我")
    authorizedReminderToggle.tap()
    let reminderStatus = app.descendants(matching: .any)["rebloom-reminder-status"]
    XCTAssertTrue(reminderStatus.waitForExistence(timeout: 4))
    XCTAssertTrue(reminderStatus.label.contains("已约在"))
    XCTAssertEqual(authorizedReminderToggle.label, "取消这次提醒")
    authorizedReminderToggle.tap()
    let cancelledExpectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", "7 天后提醒我"),
      object: authorizedReminderToggle
    )
    XCTAssertEqual(XCTWaiter.wait(for: [cancelledExpectation], timeout: 4), .completed)
    authorizedReminderToggle.tap()
    XCTAssertTrue(reminderStatus.waitForExistence(timeout: 4))
    XCTAssertEqual(authorizedReminderToggle.label, "取消这次提醒")
    keepScreenshot(named: "Adonis-rebloom-reminder")

    let share = app.buttons["share-rebloom"]
    XCTAssertTrue(scrollToHittable(share, in: app, attempts: 14))
    share.tap()
    XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 8))
    app.buttons["关闭"].tap()

    app.terminate()
    app.launchArguments =
      baseLaunchArguments + [
        "-ui-testing-rebloom-reminder-authorized",
        "-ui-testing-open-rebloom-reminder",
      ]
    app.launch()

    XCTAssertTrue(
      app.descendants(matching: .any)["rebloom-screen"]
        .waitForExistence(timeout: 8)
    )
    XCTAssertTrue(app.descendants(matching: .any)["rebloom-boundary"].exists)
    keepScreenshot(named: "Adonis-rebloom-reminder-return")

    let sourceOutfit = app.buttons.matching(identifier: "rebloom-source-outfit").firstMatch
    XCTAssertTrue(scrollToHittable(sourceOutfit, in: app, attempts: 8))
    sourceOutfit.tap()
    let historyPicker = app.segmentedControls["history-visual-picker"]
    let historyMenu = app.descendants(matching: .any)["history-visual-menu"]
    XCTAssertTrue(
      historyPicker.waitForExistence(timeout: 3)
        || historyMenu.waitForExistence(timeout: 3)
    )
    let deleteRecord = app.buttons["删除这条记录"]
    XCTAssertTrue(scrollToHittable(deleteRecord, in: app, attempts: 8))
    deleteRecord.tap()
    XCTAssertTrue(app.buttons["删除"].waitForExistence(timeout: 4))
    app.buttons["删除"].tap()

    XCTAssertTrue(
      app.descendants(matching: .any)["rebloom-empty"]
        .waitForExistence(timeout: 5)
    )
    XCTAssertEqual(app.buttons.matching(identifier: "rebloom-source-outfit").count, 0)
  }

  @MainActor
  func testSavedOutfitAutomaticallyBuildsSeasonalBloomArchive() {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-testing")
    app.launch()

    app.tabBars.buttons["花历"].tap()
    XCTAssertTrue(app.otherElements["bloom-calendar"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["seasonal-bloom-entry"].exists)

    app.tabBars.buttons["创作"].tap()
    let sample = app.buttons["sample-01"]
    XCTAssertTrue(sample.waitForExistence(timeout: 5))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 8))

    let save = app.buttons["save-today"]
    XCTAssertTrue(scrollToHittable(save, in: app, attempts: 4))
    save.tap()
    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 3))

    let makeAnother = app.buttons["make-another"]
    XCTAssertTrue(scrollToHittable(makeAnother, in: app, attempts: 4))
    makeAnother.tap()

    app.tabBars.buttons["花历"].tap()
    let seasonalEntry = app.buttons["seasonal-bloom-entry"]
    XCTAssertTrue(seasonalEntry.waitForExistence(timeout: 5))
    XCTAssertTrue(scrollToHittable(seasonalEntry, in: app, attempts: 4))
    XCTAssertTrue(seasonalEntry.label.contains("1 个季节"))
    seasonalEntry.tap()

    XCTAssertTrue(
      app.descendants(matching: .any)["seasonal-bloom-archive"]
        .waitForExistence(timeout: 5)
    )
    let provenance = app.descendants(matching: .any)["seasonal-bloom-provenance"]
    XCTAssertTrue(provenance.waitForExistence(timeout: 4))
    XCTAssertTrue(provenance.label.contains("只整理已收藏记录"))
    let noPressure = app.descendants(matching: .any)["seasonal-bloom-no-pressure"]
    XCTAssertTrue(noPressure.waitForExistence(timeout: 4))
    XCTAssertTrue(noPressure.label.contains("不是打卡"))

    let group = app.buttons.matching(identifier: "seasonal-bloom-group").firstMatch
    XCTAssertTrue(scrollToHittable(group, in: app, attempts: 5))
    XCTAssertTrue(group.label.contains("1 次盛开"))
    group.tap()

    XCTAssertTrue(
      app.descendants(matching: .any)["seasonal-bloom-detail"]
        .waitForExistence(timeout: 5)
    )
    let record = app.buttons.matching(identifier: "seasonal-bloom-record").firstMatch
    XCTAssertTrue(scrollToHittable(record, in: app, attempts: 5))
    XCTAssertTrue(record.label.contains("Bloom No. 001"))
    XCTAssertTrue(record.label.contains("今日穿搭"))
    keepScreenshot(named: "Adonis-seasonal-bloom")

    record.tap()
    XCTAssertTrue(
      app.segmentedControls["history-visual-picker"].waitForExistence(timeout: 5)
    )
    let deleteRecord = app.buttons["删除这条记录"]
    XCTAssertTrue(scrollToHittable(deleteRecord, in: app, attempts: 8))
    deleteRecord.tap()
    let confirmDelete = app.buttons["删除"]
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 4))
    confirmDelete.tap()

    XCTAssertTrue(
      app.descendants(matching: .any)["seasonal-bloom-empty"]
        .waitForExistence(timeout: 5)
    )
    XCTAssertEqual(app.buttons.matching(identifier: "seasonal-bloom-record").count, 0)
  }

  @MainActor
  func testSavedOutfitAutomaticallyAppearsInTraceableDigitalCabinet() {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-testing")
    app.launch()

    app.tabBars.buttons["花历"].tap()
    XCTAssertTrue(app.otherElements["bloom-calendar"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["digital-cabinet-entry"].exists)

    app.tabBars.buttons["创作"].tap()
    let sample = app.buttons["sample-01"]
    XCTAssertTrue(sample.waitForExistence(timeout: 5))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 8))

    let save = app.buttons["save-today"]
    XCTAssertTrue(scrollToHittable(save, in: app, attempts: 4))
    save.tap()
    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 3))

    let makeAnother = app.buttons["make-another"]
    XCTAssertTrue(scrollToHittable(makeAnother, in: app, attempts: 4))
    makeAnother.tap()

    app.tabBars.buttons["花历"].tap()
    let cabinetEntry = app.buttons["digital-cabinet-entry"]
    XCTAssertTrue(cabinetEntry.waitForExistence(timeout: 5))
    XCTAssertTrue(scrollToHittable(cabinetEntry, in: app, attempts: 4))
    XCTAssertTrue(cabinetEntry.label.contains("已自动收进 1 个贴纸手办"))
    cabinetEntry.tap()

    XCTAssertTrue(
      app.descendants(matching: .any)["digital-cabinet-screen"]
        .waitForExistence(timeout: 5)
    )
    let provenance = app.descendants(matching: .any)["digital-cabinet-provenance"]
    XCTAssertTrue(provenance.waitForExistence(timeout: 4))
    XCTAssertTrue(provenance.label.contains("人物、衣服、姿势与纯白边保持原样"))
    let boundary = app.descendants(matching: .any)["digital-cabinet-boundary"]
    XCTAssertTrue(boundary.waitForExistence(timeout: 4))
    XCTAssertTrue(boundary.label.contains("待确认"))

    let outfit = app.buttons.matching(identifier: "digital-cabinet-outfit").firstMatch
    XCTAssertTrue(scrollToHittable(outfit, in: app, attempts: 5))
    XCTAssertEqual(app.buttons.matching(identifier: "digital-cabinet-outfit").count, 1)
    XCTAssertTrue(outfit.label.contains("Bloom No. 001"))
    XCTAssertTrue(outfit.label.contains("今日穿搭"))
    XCTAssertTrue(outfit.label.contains("衣物"))
    keepScreenshot(named: "Adonis-digital-cabinet")

    outfit.tap()
    XCTAssertTrue(
      app.segmentedControls["history-visual-picker"].waitForExistence(timeout: 5)
    )
    XCTAssertTrue(app.staticTexts["garment-observation-section"].waitForExistence(timeout: 5))

    let deleteRecord = app.buttons["删除这条记录"]
    XCTAssertTrue(scrollToHittable(deleteRecord, in: app, attempts: 8))
    deleteRecord.tap()
    let confirmDelete = app.buttons["删除"]
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 4))
    confirmDelete.tap()

    XCTAssertTrue(
      app.descendants(matching: .any)["digital-cabinet-empty"]
        .waitForExistence(timeout: 5)
    )
    XCTAssertEqual(app.buttons.matching(identifier: "digital-cabinet-outfit").count, 0)
  }

  @MainActor
  func testCollectedOutfitSurvivesProcessTerminationAndRelaunch() {
    let app = XCUIApplication()
    let persistentStoreID = UUID().uuidString
    app.launchArguments.append(
      contentsOf: ["-ui-testing", "-ui-testing-persistent-store", persistentStoreID]
    )
    app.launch()

    let firstSample = app.buttons["sample-01"]
    XCTAssertTrue(firstSample.waitForExistence(timeout: 8))
    firstSample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 8))

    let saveButton = app.buttons["save-today"]
    XCTAssertTrue(scrollToHittable(saveButton, in: app, attempts: 3))
    saveButton.tap()
    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 3))

    app.terminate()
    app.launch()

    XCTAssertTrue(app.buttons["sample-01"].waitForExistence(timeout: 8))
    app.tabBars.buttons["花历"].tap()
    let recordCard = app.buttons.matching(identifier: "bloom-record-card").firstMatch
    XCTAssertTrue(recordCard.waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons.matching(identifier: "bloom-record-card").count, 1)
    recordCard.tap()

    let historyModes = app.segmentedControls["history-visual-picker"]
    XCTAssertTrue(historyModes.buttons["收藏卡"].waitForExistence(timeout: 5))
    XCTAssertTrue(
      app.descendants(matching: .any)["content-provenance-programmatic_composition"]
        .waitForExistence(timeout: 3)
    )
    keepScreenshot(named: "Adonis-cold-launch-restored-outfit")
  }

  @MainActor
  func testReviewRecommendedStickerStartsInspectableAndKeepsWarningInHistory() {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-testing")
    app.launch()

    let sample = app.buttons["sample-04"]
    XCTAssertTrue(sample.waitForExistence(timeout: 8))
    sample.tap()

    let title = app.staticTexts["result-title"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertEqual(title.label, "先看看这张贴纸")
    let modes = app.segmentedControls["result-mode-picker"]
    XCTAssertTrue(modes.buttons["透明贴纸"].isSelected)

    let notice = app.descendants(matching: .any)["sticker-quality-review_recommended"]
    XCTAssertTrue(notice.waitForExistence(timeout: 5))
    for _ in 0..<3 where !notice.isHittable {
      app.swipeUp()
    }
    XCTAssertTrue(notice.isHittable)
    XCTAssertFalse(notice.label.contains("%"))
    keepScreenshot(named: "Adonis-sticker-quality-review-result")

    let saveButton = app.buttons["save-today"]
    for _ in 0..<3 where !saveButton.isHittable {
      app.swipeUp()
    }
    XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
    XCTAssertTrue(saveButton.label.contains("这样也收藏"))
    saveButton.tap()
    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 3))

    let makeAnother = app.buttons["make-another"]
    for _ in 0..<2 where !makeAnother.isHittable {
      app.swipeUp()
    }
    makeAnother.tap()

    app.tabBars.buttons["花历"].tap()
    let recordCard = app.buttons.matching(identifier: "bloom-record-card").firstMatch
    XCTAssertTrue(recordCard.waitForExistence(timeout: 5))
    recordCard.tap()

    let historyModes = app.segmentedControls["history-visual-picker"]
    XCTAssertTrue(historyModes.buttons["透明贴纸"].waitForExistence(timeout: 5))
    XCTAssertTrue(historyModes.buttons["透明贴纸"].isSelected)
    let historyNotice =
      app.descendants(matching: .any)["sticker-quality-review_recommended"]
    XCTAssertTrue(historyNotice.waitForExistence(timeout: 4))
    for _ in 0..<3 where !historyNotice.isHittable {
      app.swipeUp()
    }
    XCTAssertTrue(historyNotice.isHittable)
    keepScreenshot(named: "Adonis-sticker-quality-review-history")
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
    let recognitionNotice =
      app.descendants(matching: .any)["content-provenance-recognition_suggestion"]
    XCTAssertTrue(recognitionNotice.waitForExistence(timeout: 3))
    for _ in 0..<2 where !recognitionNotice.isHittable {
      app.swipeUp()
    }
    XCTAssertTrue(recognitionNotice.isHittable)
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
  func testCatalogTopCanCreateReviewSaveShareAndReopenStickerTryOn() {
    let app = XCUIApplication()
    let persistentStoreID = UUID().uuidString
    app.launchArguments.append(
      contentsOf: [
        "-ui-testing",
        "-ui-testing-persistent-store",
        persistentStoreID,
        "-ui-testing-wardrobe-import",
        "-ui-testing-sticker-try-on",
      ]
    )
    app.launch()

    let sample = app.buttons["sample-02"]
    XCTAssertTrue(sample.waitForExistence(timeout: 8))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 10))
    app.buttons["save-today"].tap()
    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 4))
    app.buttons["make-another"].tap()

    app.tabBars.buttons["衣橱"].tap()
    let addItem = app.buttons["add-test-wardrobe-item"]
    XCTAssertTrue(addItem.waitForExistence(timeout: 5))
    addItem.tap()
    XCTAssertTrue(app.staticTexts["wardrobe-analysis-summary"].waitForExistence(timeout: 8))
    let topCategory = app.buttons["wardrobe-category-上装"]
    XCTAssertTrue(scrollToHittable(topCategory, in: app, attempts: 5))
    topCategory.tap()

    let tryOn = app.buttons["sticker-try-on-entry"]
    XCTAssertTrue(scrollToHittable(tryOn, in: app, attempts: 8))
    tryOn.tap()
    XCTAssertTrue(
      app.descendants(matching: .any)["sticker-try-on-processing"]
        .waitForExistence(timeout: 3)
    )

    let preview = app.descendants(matching: .any)["creative-work-preview"]
    XCTAssertTrue(preview.waitForExistence(timeout: 8))
    XCTAssertTrue(preview.label.contains("贴纸试搭"))
    let provenance = app.descendants(matching: .any)["creative-work-provenance"]
    XCTAssertTrue(scrollToHittable(provenance, in: app, attempts: 8))
    XCTAssertTrue(provenance.label.contains("不含 AI 重绘"))
    XCTAssertTrue(provenance.label.contains("人物与背景来自 OOTD"))
    XCTAssertTrue(provenance.label.contains("衣物来自商品图"))
    let boundary = app.descendants(matching: .any)["creative-work-boundary"]
    XCTAssertTrue(scrollToHittable(boundary, in: app, attempts: 5))
    XCTAssertTrue(boundary.label.contains("贴纸试搭草图"))
    XCTAssertTrue(boundary.label.contains("不预测尺码"))

    selectCreativeWorkPreview(
      assetID: "originalPhoto",
      title: "原始照片",
      preview: preview,
      in: app
    )
    selectCreativeWorkPreview(
      assetID: "work",
      title: "贴纸试搭",
      preview: preview,
      in: app
    )

    let save = app.buttons["save-creative-work"]
    XCTAssertTrue(scrollToHittable(save, in: app, attempts: 8))
    save.tap()
    XCTAssertTrue(app.buttons["作品已经收藏"].waitForExistence(timeout: 4))
    let share = app.buttons["share-creative-work"]
    XCTAssertTrue(scrollToHittable(share, in: app, attempts: 5))
    share.tap()
    XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 8))
    app.buttons["关闭"].tap()
    app.buttons["close-creative-work"].tap()

    app.terminate()
    app.launch()
    app.tabBars.buttons["花历"].tap()
    let record = app.buttons.matching(identifier: "bloom-record-card").firstMatch
    XCTAssertTrue(record.waitForExistence(timeout: 6))
    record.tap()
    let history = app.buttons["creative-work-history-entry"]
    XCTAssertTrue(scrollToHittable(history, in: app, attempts: 10))
    XCTAssertTrue(history.label.contains("贴纸试搭"))
    history.tap()
    XCTAssertTrue(preview.waitForExistence(timeout: 5))
    XCTAssertTrue(preview.label.contains("贴纸试搭"))
    keepScreenshot(named: "Adonis-sticker-try-on-history")
  }

  @MainActor
  func testStickerTryOnCanBeStoppedWithoutOpeningOrChangingAWork() {
    let app = XCUIApplication()
    app.launchArguments.append(
      contentsOf: [
        "-ui-testing",
        "-ui-testing-wardrobe-import",
        "-ui-testing-sticker-try-on",
        "-ui-testing-sticker-try-on-never-finishes",
      ]
    )
    app.launch()

    let sample = app.buttons["sample-02"]
    XCTAssertTrue(sample.waitForExistence(timeout: 8))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 10))
    app.buttons["save-today"].tap()
    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 4))
    app.buttons["make-another"].tap()

    app.tabBars.buttons["衣橱"].tap()
    let addItem = app.buttons["add-test-wardrobe-item"]
    XCTAssertTrue(addItem.waitForExistence(timeout: 5))
    addItem.tap()
    XCTAssertTrue(app.staticTexts["wardrobe-analysis-summary"].waitForExistence(timeout: 8))
    let topCategory = app.buttons["wardrobe-category-上装"]
    XCTAssertTrue(scrollToHittable(topCategory, in: app, attempts: 5))
    topCategory.tap()

    let tryOn = app.buttons["sticker-try-on-entry"]
    XCTAssertTrue(scrollToHittable(tryOn, in: app, attempts: 8))
    tryOn.tap()
    let processing = app.descendants(matching: .any)["sticker-try-on-processing"]
    XCTAssertTrue(processing.waitForExistence(timeout: 3))
    app.buttons["sticker-try-on-cancel"].tap()

    XCTAssertTrue(processing.waitForNonExistence(timeout: 4))
    XCTAssertTrue(tryOn.waitForExistence(timeout: 3))
    XCTAssertTrue(app.descendants(matching: .any)["wardrobe-item-detail"].exists)
    XCTAssertFalse(app.descendants(matching: .any)["creative-work-preview"].exists)
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
  func testLocalDataCanBeReviewedAndExported() {
    let app = XCUIApplication()
    app.launchArguments.append(contentsOf: ["-ui-testing", "-ui-testing-privacy-data"])
    app.launch()

    let settings = app.buttons["本地设置"]
    XCTAssertTrue(settings.waitForExistence(timeout: 8))
    settings.tap()
    XCTAssertTrue(app.navigationBars["本地设置"].waitForExistence(timeout: 5))

    let wardrobeCount = app.descendants(matching: .any)["privacy-wardrobe-count"]
    let inboxCount = app.descendants(matching: .any)["privacy-inbox-count"]
    XCTAssertTrue(wardrobeCount.waitForExistence(timeout: 5))
    XCTAssertEqual(wardrobeCount.label, "衣橱单品 1")
    XCTAssertEqual(inboxCount.label, "待导入图片 1")
    keepScreenshot(named: "Adonis-local-data-controls")

    app.buttons["export-personal-data"].tap()
    XCTAssertTrue(app.buttons["生成导出包"].waitForExistence(timeout: 3))
    app.buttons["生成导出包"].tap()
    let closeShareSheet = app.buttons["关闭"]
    XCTAssertTrue(closeShareSheet.waitForExistence(timeout: 10))
    keepScreenshot(named: "Adonis-local-data-export-share")
  }

  @MainActor
  func testLocalDataCanBeDeletedCompletely() {
    let app = XCUIApplication()
    app.launchArguments.append(contentsOf: ["-ui-testing", "-ui-testing-privacy-data"])
    app.launch()

    let settings = app.buttons["本地设置"]
    XCTAssertTrue(settings.waitForExistence(timeout: 8))
    settings.tap()
    XCTAssertTrue(app.navigationBars["本地设置"].waitForExistence(timeout: 5))

    let wardrobeCount = app.descendants(matching: .any)["privacy-wardrobe-count"]
    let inboxCount = app.descendants(matching: .any)["privacy-inbox-count"]
    XCTAssertTrue(wardrobeCount.waitForExistence(timeout: 5))
    XCTAssertEqual(wardrobeCount.label, "衣橱单品 1")
    XCTAssertEqual(inboxCount.label, "待导入图片 1")

    let deleteAllData = app.buttons["delete-all-personal-data"]
    deleteAllData.tap()
    XCTAssertTrue(app.buttons["全部删除"].waitForExistence(timeout: 3))
    app.buttons["全部删除"].tap()
    XCTAssertTrue(app.alerts["已经清空本地数据"].waitForExistence(timeout: 5))
    app.alerts["已经清空本地数据"].buttons["知道了"].tap()

    XCTAssertEqual(wardrobeCount.label, "衣橱单品 0")
    XCTAssertEqual(inboxCount.label, "待导入图片 0")
    keepScreenshot(named: "Adonis-local-data-cleared")
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
    XCTAssertTrue(candidate.label.contains("候选"), candidate.label)
    XCTAssertTrue(candidate.label.contains("有商品图"), candidate.label)
    XCTAssertTrue(candidate.label.contains("画面线索"), candidate.label)
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
    let topCategory = app.buttons["wardrobe-category-上装"]
    XCTAssertTrue(scrollToHittable(topCategory, in: app, attempts: 8))
    topCategory.tap()
    XCTAssertTrue(app.staticTexts["棕色上装"].waitForExistence(timeout: 3))
    app.buttons["完成"].tap()

    XCTAssertEqual(app.buttons.matching(identifier: "wardrobe-item-card").count, 1)
    app.buttons.matching(identifier: "wardrobe-item-card").firstMatch.tap()

    let confirm = app.buttons["wardrobe-history-confirm"]
    XCTAssertTrue(confirm.waitForExistence(timeout: 4))
    XCTAssertTrue(scrollToHittable(confirm, in: app, attempts: 8))
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

  @MainActor
  private func saveSampleAndConfirmGarment(
    _ sampleID: String,
    slot: String,
    in app: XCUIApplication
  ) {
    let sample = app.buttons[sampleID]
    XCTAssertTrue(sample.waitForExistence(timeout: 5))
    XCTAssertTrue(scrollToHittable(sample, in: app, attempts: 6))
    sample.tap()
    XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 8))

    let save = app.buttons["save-today"]
    XCTAssertTrue(scrollToHittable(save, in: app, attempts: 5))
    save.tap()
    XCTAssertTrue(app.buttons["今天已经收藏"].waitForExistence(timeout: 3))

    let makeAnother = app.buttons["make-another"]
    XCTAssertTrue(scrollToHittable(makeAnother, in: app, attempts: 4))
    makeAnother.tap()
    app.tabBars.buttons["花历"].tap()

    let record = app.buttons.matching(identifier: "bloom-record-card").firstMatch
    XCTAssertTrue(record.waitForExistence(timeout: 5))
    XCTAssertTrue(scrollToHittable(record, in: app, attempts: 8))
    record.tap()

    let createItem = app.buttons["garment-new-\(slot)"]
    XCTAssertTrue(scrollToHittable(createItem, in: app, attempts: 10))
    createItem.tap()
    XCTAssertTrue(app.staticTexts["garment-linked-\(slot)"].waitForExistence(timeout: 4))
    app.buttons["完成"].tap()
  }

  @MainActor
  private func scrollToHittable(
    _ element: XCUIElement,
    in app: XCUIApplication,
    attempts: Int
  ) -> Bool {
    for _ in 0..<attempts where !element.isHittable {
      app.swipeUp()
    }
    return element.isHittable
  }

  @MainActor
  private func scrollDownToHittable(
    _ element: XCUIElement,
    in app: XCUIApplication,
    attempts: Int
  ) -> Bool {
    for _ in 0..<attempts where !element.isHittable {
      app.swipeDown()
    }
    return element.isHittable
  }

  @MainActor
  private func beginCuratedStyle(
    _ recipeID: String,
    in app: XCUIApplication
  ) -> XCUIElement {
    let garden = app.buttons["curated-style-garden-entry"]
    XCTAssertTrue(scrollToHittable(garden, in: app, attempts: 12))
    garden.tap()

    let option = app.buttons["curated-style-option-\(recipeID)"]
    XCTAssertTrue(option.waitForExistence(timeout: 4))
    XCTAssertTrue(scrollToHittable(option, in: app, attempts: 5))
    option.tap()
    return garden
  }

  @MainActor
  private func selectCreativeWorkPreview(
    assetID: String,
    title: String,
    preview: XCUIElement,
    in app: XCUIApplication
  ) {
    let segmented = app.segmentedControls["creative-work-mode-picker"]
    if segmented.waitForExistence(timeout: 2) {
      XCTAssertTrue(scrollDownToHittable(segmented, in: app, attempts: 8))
      segmented.buttons[title].tap()
    } else {
      let directButton = app.buttons["creative-work-mode-\(assetID)"]
      XCTAssertTrue(directButton.waitForExistence(timeout: 3))
      XCTAssertTrue(scrollDownToHittable(directButton, in: app, attempts: 8))
      directButton.tap()
    }
    XCTAssertTrue(preview.label.contains(title))
  }
}
