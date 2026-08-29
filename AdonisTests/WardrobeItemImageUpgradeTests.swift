import SwiftData
import XCTest

@testable import Adonis

final class WardrobeItemImageUpgradeTests: XCTestCase {
  @MainActor
  func testProductImageUpgradesOutfitItemInPlaceAndDeletesOldFileAfterSave() async throws {
    let fixture = try makeFixture()
    defer { fixture.cleanup() }

    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    let oldFilename = try fixture.store.savePNG(
      WardrobeTestImageFactory.brownCatalogShirt(),
      filename: "ootd-upper.png"
    )
    let item = WardrobeItem(
      createdAt: createdAt,
      name: "棕色上装",
      category: .top,
      imageFilename: oldFilename,
      note: "周末常穿",
      sourceKind: .outfitObservation,
      dominantColorName: "棕色",
      dominantColorHex: "#6B3D1F",
      analysisVersion: AdonisProcessingVersion.outfitObservation
    )
    fixture.context.insert(item)
    try fixture.context.save()

    let data = try XCTUnwrap(WardrobeTestImageFactory.blueCatalogShirt().pngData())
    let analysis = makeAnalysis(
      fingerprint: "blue-product-image",
      colorName: "蓝色",
      colorHex: "#1F57B8",
      suggestedCategory: .top,
      categoryConfidence: 0.91
    )
    let result = try await WardrobeItemImageUpgradeService(
      mediaStore: fixture.store,
      analyze: { _ in analysis }
    ).upgrade(
      item: item,
      with: data,
      among: [item],
      in: fixture.context
    )

    XCTAssertEqual(try fixture.context.fetchCount(FetchDescriptor<WardrobeItem>()), 1)
    XCTAssertEqual(item.createdAt, createdAt)
    XCTAssertEqual(item.name, "蓝色上装")
    XCTAssertEqual(item.note, "周末常穿")
    XCTAssertEqual(item.category, .top)
    XCTAssertEqual(item.sourceKind, .catalogImage)
    XCTAssertEqual(item.originSourceKind, .outfitObservation)
    XCTAssertEqual(item.imageFingerprint, "blue-product-image")
    XCTAssertEqual(item.analysisVersion, AdonisProcessingVersion.wardrobeAnalysis)
    XCTAssertEqual(result.previousFilename, oldFilename)
    XCTAssertEqual(result.newFilename, item.imageFilename)
    XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.store.url(for: oldFilename).path))
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: fixture.store.url(for: item.imageFilename).path)
    )
  }

  @MainActor
  func testUpgradePreservesCustomNameAndExistingCategoryAgainstConflictingSuggestion() {
    let item = WardrobeItem(
      name: "在京都买的旧外套",
      category: .outerwear,
      imageFilename: "old.png",
      note: "不要覆盖",
      sourceKind: .outfitObservation,
      dominantColorName: "棕色"
    )
    let analysis = makeAnalysis(
      fingerprint: "conflicting-suggestion",
      colorName: "蓝色",
      colorHex: "#1F57B8",
      suggestedCategory: .top,
      categoryConfidence: 0.98
    )

    WardrobeItemImageUpdater.apply(
      analysis: analysis,
      newFilename: "new.png",
      to: item
    )

    XCTAssertEqual(item.name, "在京都买的旧外套")
    XCTAssertEqual(item.note, "不要覆盖")
    XCTAssertEqual(item.category, .outerwear)
    XCTAssertEqual(item.suggestedCategory, .top)
    XCTAssertEqual(item.categoryConfidence, 0.98)
    XCTAssertEqual(item.sourceKind, .catalogImage)
    XCTAssertEqual(item.originSourceKind, .outfitObservation)
  }

  @MainActor
  func testDuplicateProductImageIsRejectedWithoutChangingItemOrFiles() async throws {
    let fixture = try makeFixture()
    defer { fixture.cleanup() }

    let targetFilename = try fixture.store.savePNG(
      WardrobeTestImageFactory.brownCatalogShirt(),
      filename: "target.png"
    )
    let existingFilename = try fixture.store.savePNG(
      WardrobeTestImageFactory.blueCatalogShirt(),
      filename: "existing.png"
    )
    let target = WardrobeItem(
      name: "棕色上装",
      category: .top,
      imageFilename: targetFilename,
      sourceKind: .outfitObservation,
      dominantColorName: "棕色"
    )
    let existing = WardrobeItem(
      name: "蓝色衬衫",
      category: .top,
      imageFilename: existingFilename,
      sourceKind: .catalogImage,
      imageFingerprint: "already-owned"
    )
    fixture.context.insert(target)
    fixture.context.insert(existing)
    try fixture.context.save()

    let analysis = makeAnalysis(
      fingerprint: "already-owned",
      colorName: "蓝色",
      colorHex: "#1F57B8",
      suggestedCategory: .top,
      categoryConfidence: 0.9
    )

    do {
      _ = try await WardrobeItemImageUpgradeService(
        mediaStore: fixture.store,
        analyze: { _ in analysis }
      ).upgrade(
        item: target,
        with: try XCTUnwrap(WardrobeTestImageFactory.blueCatalogShirt().pngData()),
        among: [target, existing],
        in: fixture.context
      )
      XCTFail("重复商品图不应自动合并或覆盖")
    } catch let error as WardrobeItemImageUpgradeError {
      XCTAssertEqual(error, .duplicateImage(itemName: "蓝色衬衫"))
    }

    XCTAssertEqual(try fixture.context.fetchCount(FetchDescriptor<WardrobeItem>()), 2)
    XCTAssertEqual(target.name, "棕色上装")
    XCTAssertEqual(target.imageFilename, targetFilename)
    XCTAssertEqual(target.sourceKind, .outfitObservation)
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: fixture.store.url(for: targetFilename).path)
    )
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: fixture.store.url(for: existingFilename).path)
    )
  }

  private func makeAnalysis(
    fingerprint: String,
    colorName: String,
    colorHex: String,
    suggestedCategory: WardrobeCategory,
    categoryConfidence: Double
  ) -> WardrobeImageAnalysis {
    WardrobeImageAnalysis(
      sourceKind: .catalogImage,
      dominantColorName: colorName,
      dominantColorHex: colorHex,
      suggestedCategory: suggestedCategory,
      categoryConfidence: categoryConfidence,
      cleanBackgroundScore: 0.94,
      imageWidth: 480,
      imageHeight: 640,
      imageFingerprint: fingerprint,
      processingMilliseconds: 12,
      analysisVersion: AdonisProcessingVersion.wardrobeAnalysis
    )
  }

  @MainActor
  private func makeFixture() throws -> Fixture {
    let schema = Schema([WardrobeItem.self])
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("adonis-upgrade-test-\(UUID().uuidString)", isDirectory: true)
    return Fixture(
      context: ModelContext(container),
      store: MediaStore(baseURL: directory),
      directory: directory
    )
  }
}

private struct Fixture {
  let context: ModelContext
  let store: MediaStore
  let directory: URL

  func cleanup() {
    try? FileManager.default.removeItem(at: directory)
  }
}
