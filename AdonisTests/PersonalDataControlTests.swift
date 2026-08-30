import SwiftData
import UIKit
import XCTest

@testable import Adonis

final class PersonalDataControlTests: XCTestCase {
  @MainActor
  func testExportContainsReadableManifestMediaAndPendingSharedImages() async throws {
    let fixture = try makeFixture()
    defer { fixture.cleanup() }
    let image = WardrobeTestImageFactory.brownCatalogShirt()
    let imageData = try XCTUnwrap(image.pngData())
    let sourceFilename = try fixture.store.savePNG(image, filename: "outfit-source.png")
    let stickerFilename = try fixture.store.savePNG(image, filename: "outfit-sticker.png")
    let cardFilename = try fixture.store.savePNG(image, filename: "outfit-card.png")
    let observationFilename = try fixture.store.savePNG(image, filename: "observation.png")
    let wardrobeFilename = try fixture.store.savePNG(image, filename: "wardrobe.png")

    let record = OutfitRecord(
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      title: "周末穿搭",
      sourceImageFilename: sourceFilename,
      stickerImageFilename: stickerFilename,
      cardImageFilename: cardFilename,
      bloomNumber: 7,
      note: "公园",
      generationCompletionMode: .basicStickerFallback,
      stickerQualityAssessment: StickerQualityAssessment(
        level: .reviewRecommended,
        issues: [.edgeMayIncludeBackground]
      )
    )
    let observation = GarmentObservation(
      createdAt: record.createdAt,
      slot: .upperBody,
      confidence: 0.72,
      previewImageFilename: observationFilename,
      outfit: record
    )
    record.garmentObservations.append(observation)
    let item = WardrobeItem(
      createdAt: Date(timeIntervalSince1970: 1_700_000_100),
      name: "棕色上装",
      category: .top,
      imageFilename: wardrobeFilename,
      sourceKind: .catalogImage,
      dominantColorName: "棕色"
    )
    let performanceTrace = GenerationPerformanceTrace(
      totalMilliseconds: 680,
      stageTimings: [
        GenerationStageTiming(stage: .subjectExtraction, milliseconds: 500),
        GenerationStageTiming(stage: .qualityAssessment, milliseconds: 180),
      ],
      usesPreparedSample: false
    )
    let event = AppEvent(
      createdAt: Date(timeIntervalSince1970: 1_700_000_200),
      kind: .generationSucceeded,
      inputSource: .photoLibrary,
      processingVersion: "test-v1",
      generationPerformanceTrace: performanceTrace
    )
    fixture.context.insert(record)
    fixture.context.insert(observation)
    fixture.context.insert(item)
    fixture.context.insert(event)
    try fixture.context.save()
    let pending = try fixture.inbox.enqueue(
      data: imageData,
      createdAt: Date(timeIntervalSince1970: 1_700_000_300)
    )

    let archive = try await fixture.archiveService.export(
      records: [record],
      items: [item],
      observations: [observation],
      events: [event],
      inbox: fixture.inbox,
      exportedAt: Date(timeIntervalSince1970: 1_700_000_400)
    )
    let entries = try TarTestInspector.entries(in: try Data(contentsOf: archive.url))

    XCTAssertEqual(entries["media/\(sourceFilename)"], imageData)
    XCTAssertEqual(entries["media/\(stickerFilename)"], imageData)
    XCTAssertEqual(entries["media/\(cardFilename)"], imageData)
    XCTAssertEqual(entries["media/\(observationFilename)"], imageData)
    XCTAssertEqual(entries["media/\(wardrobeFilename)"], imageData)
    XCTAssertEqual(entries["shared-inbox/\(pending.id)"], imageData)
    let manifestData = try XCTUnwrap(entries["manifest.json"])
    let manifest = try XCTUnwrap(
      try JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
    )
    XCTAssertEqual(manifest["formatVersion"] as? String, PersonalDataArchiveService.formatVersion)
    XCTAssertEqual(manifest["storage"] as? String, "local_app_storage")
    XCTAssertEqual(manifest["adonisAutomaticNetworkUpload"] as? Bool, false)
    XCTAssertEqual(manifest["systemBackupControlledByIOS"] as? Bool, true)
    let outfits = try XCTUnwrap(manifest["outfits"] as? [[String: Any]])
    XCTAssertEqual(outfits.first?["originalPhotoPath"] as? String, "media/\(sourceFilename)")
    XCTAssertEqual(outfits.first?["derivedStickerPath"] as? String, "media/\(stickerFilename)")
    XCTAssertEqual(outfits.first?["derivedShareCardPath"] as? String, "media/\(cardFilename)")
    XCTAssertEqual(
      outfits.first?["generationCompletionMode"] as? String,
      GenerationCompletionMode.basicStickerFallback.rawValue
    )
    XCTAssertEqual(
      outfits.first?["stickerQualityLevel"] as? String,
      StickerQualityLevel.reviewRecommended.rawValue
    )
    XCTAssertEqual(
      outfits.first?["stickerQualityIssues"] as? [String],
      [StickerQualityIssue.edgeMayIncludeBackground.rawValue]
    )
    XCTAssertEqual(outfits.first?["stickerQualityRequiresReview"] as? Bool, true)
    XCTAssertEqual(
      outfits.first?["stickerQualityVersion"] as? String,
      StickerQualityAssessor.version
    )
    let wardrobeItems = try XCTUnwrap(manifest["wardrobeItems"] as? [[String: Any]])
    XCTAssertEqual(
      wardrobeItems.first?["sourceImagePath"] as? String,
      "media/\(wardrobeFilename)"
    )
    let observations = try XCTUnwrap(manifest["garmentObservations"] as? [[String: Any]])
    XCTAssertEqual(
      observations.first?["derivedPreviewPath"] as? String,
      "media/\(observationFilename)"
    )
    let pendingSharedImages = try XCTUnwrap(manifest["pendingSharedImages"] as? [String])
    XCTAssertEqual(pendingSharedImages, ["shared-inbox/\(pending.id)"])
    let visualAssets = try XCTUnwrap(manifest["visualAssets"] as? [[String: Any]])
    XCTAssertEqual(visualAssets.count, 6)
    XCTAssertEqual(
      provenance(for: "media/\(sourceFilename)", in: visualAssets),
      VisualContentProvenance.userProvided.rawValue
    )
    XCTAssertEqual(
      provenance(for: "media/\(stickerFilename)", in: visualAssets),
      VisualContentProvenance.derivedFromOriginal.rawValue
    )
    XCTAssertEqual(
      provenance(for: "media/\(cardFilename)", in: visualAssets),
      VisualContentProvenance.programmaticComposition.rawValue
    )
    let stickerAsset = try XCTUnwrap(
      visualAssets.first { $0["path"] as? String == "media/\(stickerFilename)" }
    )
    XCTAssertEqual(
      stickerAsset["qualityLevel"] as? String,
      StickerQualityLevel.reviewRecommended.rawValue
    )
    XCTAssertEqual(stickerAsset["qualityRequiresReview"] as? Bool, true)
    XCTAssertEqual(
      stickerAsset["qualityAssessmentVersion"] as? String,
      StickerQualityAssessor.version
    )
    let sourceAsset = try XCTUnwrap(
      visualAssets.first { $0["path"] as? String == "media/\(sourceFilename)" }
    )
    XCTAssertNil(sourceAsset["qualityLevel"])
    XCTAssertEqual(
      provenance(for: "media/\(wardrobeFilename)", in: visualAssets),
      VisualContentProvenance.userProvided.rawValue
    )
    XCTAssertEqual(
      provenance(for: "media/\(observationFilename)", in: visualAssets),
      VisualContentProvenance.recognitionSuggestion.rawValue
    )
    XCTAssertEqual(
      provenance(for: "shared-inbox/\(pending.id)", in: visualAssets),
      VisualContentProvenance.userProvided.rawValue
    )
    XCTAssertTrue(
      visualAssets.allSatisfy { asset in
        asset["containsAIGeneratedPixels"] as? Bool == false
      }
    )
    let observationAsset = try XCTUnwrap(
      visualAssets.first { $0["path"] as? String == "media/\(observationFilename)" }
    )
    XCTAssertEqual(observationAsset["requiresUserConfirmation"] as? Bool, true)
    XCTAssertNil(manifest["imageDataBase64"])
    let processingEvents = try XCTUnwrap(manifest["processingEvents"] as? [[String: Any]])
    let exportedPerformance = try XCTUnwrap(
      processingEvents.first?["generationPerformance"] as? [String: Any]
    )
    XCTAssertEqual(
      exportedPerformance["version"] as? String,
      GenerationPerformanceTrace.currentVersion
    )
    XCTAssertEqual(exportedPerformance["totalMilliseconds"] as? Int, 680)
    XCTAssertEqual(exportedPerformance["targetMilliseconds"] as? Int, 45_000)
    XCTAssertEqual(
      exportedPerformance["budgetStatus"] as? String,
      GenerationBudgetStatus.withinTarget.rawValue
    )
    XCTAssertEqual(exportedPerformance["retryCount"] as? Int, 0)
    XCTAssertEqual(exportedPerformance["externalRequestCount"] as? Int, 0)
    let stageMilliseconds = try XCTUnwrap(
      exportedPerformance["stageMilliseconds"] as? [String: Int]
    )
    XCTAssertEqual(stageMilliseconds[GenerationPerformanceStage.subjectExtraction.rawValue], 500)
    XCTAssertEqual(stageMilliseconds[GenerationPerformanceStage.qualityAssessment.rawValue], 180)

    let attachment = XCTAttachment(contentsOfFile: archive.url)
    attachment.name = "Adonis-personal-data-export"
    attachment.lifetime = .keepAlways
    add(attachment)

    fixture.archiveService.removeTemporaryExport(at: archive.url)
    XCTAssertFalse(FileManager.default.fileExists(atPath: archive.url.path))
  }

  @MainActor
  func testDeleteAllClearsModelsMediaSharedInboxAndTemporaryExports() throws {
    let fixture = try makeFixture()
    defer { fixture.cleanup() }
    let image = WardrobeTestImageFactory.blueCatalogShirt()
    let imageData = try XCTUnwrap(image.pngData())
    let sourceFilename = try fixture.store.savePNG(image, filename: "source.png")
    let stickerFilename = try fixture.store.savePNG(image, filename: "sticker.png")
    let cardFilename = try fixture.store.savePNG(image, filename: "card.png")
    let previewFilename = try fixture.store.savePNG(image, filename: "preview.png")
    let wardrobeFilename = try fixture.store.savePNG(image, filename: "wardrobe.png")
    let record = OutfitRecord(
      sourceImageFilename: sourceFilename,
      stickerImageFilename: stickerFilename,
      cardImageFilename: cardFilename,
      bloomNumber: 1
    )
    let observation = GarmentObservation(
      slot: .upperBody,
      confidence: 0.8,
      previewImageFilename: previewFilename,
      outfit: record
    )
    record.garmentObservations.append(observation)
    fixture.context.insert(record)
    fixture.context.insert(observation)
    fixture.context.insert(
      WardrobeItem(name: "蓝色上装", imageFilename: wardrobeFilename)
    )
    fixture.context.insert(AppEvent(kind: .generationSucceeded))
    try fixture.context.save()
    try fixture.inbox.enqueue(data: imageData)
    try FileManager.default.createDirectory(
      at: fixture.exportDirectory,
      withIntermediateDirectories: true
    )
    let staleExport = fixture.exportDirectory.appendingPathComponent("stale.tar")
    try Data("stale".utf8).write(to: staleExport)

    try fixture.deletionService.deleteAll(in: fixture.context, inbox: fixture.inbox)

    XCTAssertEqual(try fixture.context.fetchCount(FetchDescriptor<OutfitRecord>()), 0)
    XCTAssertEqual(try fixture.context.fetchCount(FetchDescriptor<GarmentObservation>()), 0)
    XCTAssertEqual(try fixture.context.fetchCount(FetchDescriptor<WardrobeItem>()), 0)
    XCTAssertEqual(try fixture.context.fetchCount(FetchDescriptor<AppEvent>()), 0)
    XCTAssertTrue(try fixture.store.storedFileURLs().isEmpty)
    XCTAssertTrue(try fixture.inbox.pendingItems().isEmpty)
    XCTAssertFalse(FileManager.default.fileExists(atPath: staleExport.path))
    XCTAssertEqual(fixture.reminderCleaner.removeCount, 1)
  }

  @MainActor
  private func makeFixture() throws -> Fixture {
    let schema = Schema([
      OutfitRecord.self,
      GarmentObservation.self,
      WardrobeItem.self,
      AppEvent.self,
    ])
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("adonis-personal-data-test-\(UUID().uuidString)", isDirectory: true)
    let mediaDirectory = root.appendingPathComponent("media", isDirectory: true)
    let inboxDirectory = root.appendingPathComponent("inbox", isDirectory: true)
    let exportDirectory = root.appendingPathComponent("exports", isDirectory: true)
    let store = MediaStore(baseURL: mediaDirectory)
    let archiveService = PersonalDataArchiveService(
      mediaStore: store,
      exportDirectory: exportDirectory
    )
    let reminderCleaner = ReminderCleanerSpy()
    return try Fixture(
      context: ModelContext(container),
      store: store,
      inbox: SharedImageInbox(baseURL: inboxDirectory),
      archiveService: archiveService,
      deletionService: PersonalDataDeletionService(
        mediaStore: store,
        archiveService: archiveService,
        reminderCleaner: reminderCleaner
      ),
      reminderCleaner: reminderCleaner,
      root: root,
      exportDirectory: exportDirectory
    )
  }

  private func provenance(for path: String, in assets: [[String: Any]]) -> String? {
    assets.first { $0["path"] as? String == path }?["provenance"] as? String
  }
}

private struct Fixture {
  let context: ModelContext
  let store: MediaStore
  let inbox: SharedImageInbox
  let archiveService: PersonalDataArchiveService
  let deletionService: PersonalDataDeletionService
  let reminderCleaner: ReminderCleanerSpy
  let root: URL
  let exportDirectory: URL

  func cleanup() {
    try? FileManager.default.removeItem(at: root)
  }
}

private final class ReminderCleanerSpy: RebloomReminderCleaning {
  private(set) var removeCount = 0

  func removeAllRebloomReminders() {
    removeCount += 1
  }
}

private enum TarTestInspector {
  static func entries(in archive: Data) throws -> [String: Data] {
    var result: [String: Data] = [:]
    var offset = 0
    while offset + 512 <= archive.count {
      let header = archive.subdata(in: offset..<(offset + 512))
      if header.allSatisfy({ $0 == 0 }) { break }
      let name = string(in: header, range: 0..<100)
      let sizeText = string(in: header, range: 124..<136)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard let size = Int(sizeText, radix: 8) else {
        throw PersonalDataControlError.exportFailed
      }
      let dataStart = offset + 512
      let dataEnd = dataStart + size
      guard dataEnd <= archive.count else {
        throw PersonalDataControlError.exportFailed
      }
      result[name] = archive.subdata(in: dataStart..<dataEnd)
      offset = dataStart + ((size + 511) / 512) * 512
    }
    return result
  }

  private static func string(in data: Data, range: Range<Int>) -> String {
    let bytes = data[range].prefix { $0 != 0 }
    return String(decoding: bytes, as: UTF8.self)
  }
}
