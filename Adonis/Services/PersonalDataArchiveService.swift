import Foundation
import SwiftData

struct PersonalDataArchive: Identifiable, Sendable {
  let url: URL

  var id: String { url.path }
}

struct PersonalDataArchiveService {
  static let formatVersion = "adonis-personal-data-v4"
  static let exportDirectoryName = "AdonisExports"

  private let mediaStore: MediaStore
  private let fileManager: FileManager
  private let exportDirectory: URL

  init(
    mediaStore: MediaStore = .shared,
    fileManager: FileManager = .default,
    exportDirectory: URL? = nil
  ) {
    self.mediaStore = mediaStore
    self.fileManager = fileManager
    self.exportDirectory =
      exportDirectory
      ?? fileManager.temporaryDirectory.appendingPathComponent(
        Self.exportDirectoryName,
        isDirectory: true
      )
  }

  @MainActor
  func export(
    records: [OutfitRecord],
    items: [WardrobeItem],
    observations: [GarmentObservation],
    events: [AppEvent],
    inbox: SharedImageInbox,
    exportedAt: Date = .now
  ) async throws -> PersonalDataArchive {
    try prepareExportDirectory()
    try removeAllTemporaryExports()

    let mediaURLs = try mediaStore.storedFileURLs()
    let pendingInboxItems = try inbox.pendingItems()
    let sources =
      mediaURLs.map {
        PersonalDataArchiveSource(
          archivePath: "media/\($0.lastPathComponent)",
          sourceURL: $0
        )
      }
      + pendingInboxItems.map {
        PersonalDataArchiveSource(
          archivePath: "shared-inbox/\($0.id)",
          sourceURL: $0.url
        )
      }
    let manifest = PersonalDataManifest(
      exportedAt: exportedAt,
      appVersion: Self.appVersion,
      records: records,
      items: items,
      observations: observations,
      events: events,
      mediaPaths: mediaURLs.map { "media/\($0.lastPathComponent)" },
      pendingSharedImagePaths: pendingInboxItems.map { "shared-inbox/\($0.id)" }
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let manifestData = try encoder.encode(manifest)
    let filename = "Adonis-data-\(Self.filenameTimestamp(exportedAt)).tar"
    let archiveURL = exportDirectory.appendingPathComponent(filename, isDirectory: false)

    do {
      try await Task.detached(priority: .userInitiated) {
        try TarArchiveWriter.write(
          manifestData: manifestData,
          sources: sources,
          to: archiveURL
        )
      }.value
      return PersonalDataArchive(url: archiveURL)
    } catch {
      try? fileManager.removeItem(at: archiveURL)
      throw PersonalDataControlError.exportFailed
    }
  }

  func removeTemporaryExport(at url: URL) {
    guard
      url.deletingLastPathComponent().standardizedFileURL == exportDirectory.standardizedFileURL,
      url.pathExtension == "tar"
    else { return }
    try? fileManager.removeItem(at: url)
  }

  func removeAllTemporaryExports() throws {
    guard fileManager.fileExists(atPath: exportDirectory.path) else { return }
    let urls = try fileManager.contentsOfDirectory(
      at: exportDirectory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
    for url in urls where url.pathExtension == "tar" {
      try fileManager.removeItem(at: url)
    }
  }

  private func prepareExportDirectory() throws {
    try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
    try? fileManager.setAttributes(
      [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
      ofItemAtPath: exportDirectory.path
    )
  }

  private static var appVersion: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    return [version, build].compactMap { $0 }.joined(separator: " (")
      + (version != nil && build != nil ? ")" : "")
  }

  private static func filenameTimestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    return formatter.string(from: date)
  }
}

struct PersonalDataDeletionService {
  private let mediaStore: MediaStore
  private let archiveService: PersonalDataArchiveService
  private let reminderCleaner: any RebloomReminderCleaning

  init(
    mediaStore: MediaStore = .shared,
    archiveService: PersonalDataArchiveService? = nil,
    reminderCleaner: any RebloomReminderCleaning = SystemRebloomReminderCleaner()
  ) {
    self.mediaStore = mediaStore
    self.archiveService = archiveService ?? PersonalDataArchiveService(mediaStore: mediaStore)
    self.reminderCleaner = reminderCleaner
  }

  @MainActor
  func deleteAll(in modelContext: ModelContext, inbox: SharedImageInbox) throws {
    do {
      try modelContext.fetch(FetchDescriptor<GarmentObservation>()).forEach(modelContext.delete)
      try modelContext.fetch(FetchDescriptor<OutfitRecord>()).forEach(modelContext.delete)
      try modelContext.fetch(FetchDescriptor<WardrobeItem>()).forEach(modelContext.delete)
      try modelContext.fetch(FetchDescriptor<AppEvent>()).forEach(modelContext.delete)
      try modelContext.save()
    } catch {
      modelContext.rollback()
      throw PersonalDataControlError.deletionFailed
    }

    var cleanupFailed = false
    do {
      try mediaStore.removeAll()
    } catch {
      cleanupFailed = true
    }
    do {
      try inbox.removeAll()
    } catch {
      cleanupFailed = true
    }
    do {
      try archiveService.removeAllTemporaryExports()
    } catch {
      cleanupFailed = true
    }
    reminderCleaner.removeAllRebloomReminders()
    if cleanupFailed {
      throw PersonalDataControlError.partialDeletion
    }
  }
}

enum PersonalDataControlError: LocalizedError {
  case exportFailed
  case deletionFailed
  case partialDeletion
  case archivePathTooLong
  case archiveSourceChanged

  var errorDescription: String? {
    switch self {
    case .exportFailed:
      "导出包没有生成成功，请确认设备空间后再试。"
    case .deletionFailed:
      "本地记录没有删除，请稍后再试。"
    case .partialDeletion:
      "记录已经删除，但有少量本地文件暂时没清理干净，请再点一次全部删除。"
    case .archivePathTooLong, .archiveSourceChanged:
      "导出包没有生成成功，请稍后再试。"
    }
  }
}

private struct PersonalDataArchiveSource: Sendable {
  let archivePath: String
  let sourceURL: URL
}

private struct PersonalDataManifest: Encodable, Sendable {
  let formatVersion = PersonalDataArchiveService.formatVersion
  let exportedAt: Date
  let appVersion: String
  let storage = "local_app_storage"
  let adonisAutomaticNetworkUpload = false
  let systemBackupControlledByIOS = true
  let outfits: [ExportedOutfit]
  let wardrobeItems: [ExportedWardrobeItem]
  let garmentObservations: [ExportedGarmentObservation]
  let processingEvents: [ExportedAppEvent]
  let visualAssets: [ExportedVisualAsset]
  let mediaFiles: [String]
  let pendingSharedImages: [String]

  @MainActor
  init(
    exportedAt: Date,
    appVersion: String,
    records: [OutfitRecord],
    items: [WardrobeItem],
    observations: [GarmentObservation],
    events: [AppEvent],
    mediaPaths: [String],
    pendingSharedImagePaths: [String]
  ) {
    self.exportedAt = exportedAt
    self.appVersion = appVersion
    outfits = records.sorted { $0.createdAt < $1.createdAt }.map(ExportedOutfit.init)
    wardrobeItems = items.sorted { $0.createdAt < $1.createdAt }.map(ExportedWardrobeItem.init)
    garmentObservations = observations.sorted { $0.createdAt < $1.createdAt }.map(
      ExportedGarmentObservation.init
    )
    processingEvents = events.sorted { $0.createdAt < $1.createdAt }.map(ExportedAppEvent.init)
    visualAssets =
      (records.flatMap { record in
        [
          ExportedVisualAsset(
            path: "media/\(record.sourceImageFilename)",
            role: "outfit_original_photo",
            provenance: .userProvided,
            ownerID: record.id
          ),
          ExportedVisualAsset(
            path: "media/\(record.stickerImageFilename)",
            role: "outfit_sticker",
            provenance: .derivedFromOriginal,
            ownerID: record.id,
            qualityAssessment: record.stickerQualityAssessment,
            qualityAssessmentVersion: record.stickerQualityVersion
          ),
          ExportedVisualAsset(
            path: "media/\(record.cardImageFilename)",
            role: "outfit_share_card",
            provenance: .programmaticComposition,
            ownerID: record.id,
            qualityAssessment: record.stickerQualityAssessment,
            qualityAssessmentVersion: record.stickerQualityVersion
          ),
        ]
      }
      + items.map { item in
        ExportedVisualAsset(
          path: "media/\(item.imageFilename)",
          role: "wardrobe_item_image",
          provenance: item.sourceKind == .outfitObservation
            ? .derivedFromOriginal
            : .userProvided,
          ownerID: item.id
        )
      }
      + observations.map { observation in
        ExportedVisualAsset(
          path: "media/\(observation.previewImageFilename)",
          role: "garment_observation_preview",
          provenance: .recognitionSuggestion,
          ownerID: observation.id
        )
      }
      + pendingSharedImagePaths.map { path in
        ExportedVisualAsset(
          path: path,
          role: "pending_shared_image",
          provenance: .userProvided,
          ownerID: nil
        )
      }).sorted { lhs, rhs in
        lhs.path == rhs.path ? lhs.role < rhs.role : lhs.path < rhs.path
      }
    mediaFiles = mediaPaths.sorted()
    pendingSharedImages = pendingSharedImagePaths.sorted()
  }
}

private struct ExportedVisualAsset: Encodable, Sendable {
  let path: String
  let role: String
  let provenance: VisualContentProvenance
  let ownerID: UUID?
  let disclosure: String
  let containsAIGeneratedPixels: Bool
  let requiresUserConfirmation: Bool
  let qualityLevel: String?
  let qualityIssues: [String]?
  let qualityRequiresReview: Bool?
  let qualityAssessmentVersion: String?

  init(
    path: String,
    role: String,
    provenance: VisualContentProvenance,
    ownerID: UUID?,
    qualityAssessment: StickerQualityAssessment? = nil,
    qualityAssessmentVersion: String? = nil
  ) {
    self.path = path
    self.role = role
    self.provenance = provenance
    self.ownerID = ownerID
    self.disclosure = provenance.detail
    self.containsAIGeneratedPixels = provenance.containsAIGeneratedPixels
    self.requiresUserConfirmation = provenance.requiresUserConfirmation
    self.qualityLevel = qualityAssessment?.level.rawValue
    self.qualityIssues = qualityAssessment?.issues.map(\.rawValue)
    self.qualityRequiresReview = qualityAssessment?.requiresReview
    self.qualityAssessmentVersion = qualityAssessmentVersion
  }
}

private struct ExportedOutfit: Encodable, Sendable {
  let id: UUID
  let createdAt: Date
  let title: String
  let originalPhotoPath: String
  let derivedStickerPath: String
  let derivedShareCardPath: String
  let bloomNumber: Int
  let note: String
  let generationCompletionMode: String
  let stickerQualityLevel: String
  let stickerQualityIssues: [String]
  let stickerQualityRequiresReview: Bool
  let stickerQualityVersion: String

  @MainActor
  init(_ record: OutfitRecord) {
    id = record.id
    createdAt = record.createdAt
    title = record.title
    originalPhotoPath = "media/\(record.sourceImageFilename)"
    derivedStickerPath = "media/\(record.stickerImageFilename)"
    derivedShareCardPath = "media/\(record.cardImageFilename)"
    bloomNumber = record.bloomNumber
    note = record.note
    generationCompletionMode = record.generationCompletionMode.rawValue
    stickerQualityLevel = record.stickerQualityAssessment.level.rawValue
    stickerQualityIssues = record.stickerQualityAssessment.issues.map(\.rawValue)
    stickerQualityRequiresReview = record.stickerQualityAssessment.requiresReview
    stickerQualityVersion = record.stickerQualityVersion
  }
}

private struct ExportedWardrobeItem: Encodable, Sendable {
  let id: UUID
  let createdAt: Date
  let name: String
  let category: String
  let sourceImagePath: String
  let note: String
  let sourceKind: String
  let originSourceKind: String
  let dominantColorName: String?
  let dominantColorHex: String?
  let suggestedCategory: String?
  let categoryConfidence: Double?
  let cleanBackgroundScore: Double?
  let imageWidth: Int
  let imageHeight: Int
  let imageFingerprint: String?
  let analysisVersion: String?

  @MainActor
  init(_ item: WardrobeItem) {
    id = item.id
    createdAt = item.createdAt
    name = item.name
    category = item.category.rawValue
    sourceImagePath = "media/\(item.imageFilename)"
    note = item.note
    sourceKind = item.sourceKind.rawValue
    originSourceKind = item.originSourceKind.rawValue
    dominantColorName = item.dominantColorName
    dominantColorHex = item.dominantColorHex
    suggestedCategory = item.suggestedCategory?.rawValue
    categoryConfidence = item.categoryConfidence
    cleanBackgroundScore = item.cleanBackgroundScore
    imageWidth = item.imageWidth
    imageHeight = item.imageHeight
    imageFingerprint = item.imageFingerprint
    analysisVersion = item.analysisVersion
  }
}

private struct ExportedGarmentObservation: Encodable, Sendable {
  let id: UUID
  let createdAt: Date
  let outfitID: UUID?
  let slot: String
  let suggestedCategory: String
  let dominantColorName: String?
  let dominantColorHex: String?
  let confidence: Double
  let derivedPreviewPath: String
  let state: String
  let matchedWardrobeItemID: UUID?
  let rejectedWardrobeItemIDs: [UUID]
  let observerVersion: String

  @MainActor
  init(_ observation: GarmentObservation) {
    id = observation.id
    createdAt = observation.createdAt
    outfitID = observation.outfit?.id
    slot = observation.slot.rawValue
    suggestedCategory = observation.suggestedCategory.rawValue
    dominantColorName = observation.dominantColorName
    dominantColorHex = observation.dominantColorHex
    confidence = observation.confidence
    derivedPreviewPath = "media/\(observation.previewImageFilename)"
    state = observation.state.rawValue
    matchedWardrobeItemID = observation.matchedWardrobeItemID
    rejectedWardrobeItemIDs = observation.rejectedWardrobeItemIDs.sorted {
      $0.uuidString < $1.uuidString
    }
    observerVersion = observation.observerVersion
  }
}

private struct ExportedAppEvent: Encodable, Sendable {
  let id: UUID
  let createdAt: Date
  let kind: String
  let durationMilliseconds: Int?
  let detail: String?
  let inputSource: String?
  let processingVersion: String?
  let generationPerformance: ExportedGenerationPerformance?

  @MainActor
  init(_ event: AppEvent) {
    id = event.id
    createdAt = event.createdAt
    kind = event.kindRawValue
    durationMilliseconds = event.durationMilliseconds
    detail = event.detail
    inputSource = event.inputSourceRawValue
    processingVersion = event.processingVersion
    generationPerformance = event.generationPerformanceTrace.map(
      ExportedGenerationPerformance.init
    )
  }
}

private struct ExportedGenerationPerformance: Encodable, Sendable {
  let version: String
  let totalMilliseconds: Int
  let targetMilliseconds: Int
  let budgetStatus: String
  let stageMilliseconds: [String: Int]
  let slowestStage: String?
  let interruptedStage: String?
  let retryCount: Int
  let externalRequestCount: Int
  let usesPreparedSample: Bool

  init(_ trace: GenerationPerformanceTrace) {
    version = trace.version
    totalMilliseconds = trace.totalMilliseconds
    targetMilliseconds = trace.targetMilliseconds
    budgetStatus = trace.budgetStatus.rawValue
    stageMilliseconds = Dictionary(
      uniqueKeysWithValues: GenerationPerformanceStage.allCases.compactMap { stage in
        trace.milliseconds(for: stage).map { (stage.rawValue, $0) }
      }
    )
    slowestStage = trace.slowestStage?.stage.rawValue
    interruptedStage = trace.interruptedStage?.rawValue
    retryCount = trace.retryCount
    externalRequestCount = trace.externalRequestCount
    usesPreparedSample = trace.usesPreparedSample
  }
}

private enum TarArchiveWriter {
  private static let blockSize = 512

  static func write(
    manifestData: Data,
    sources: [PersonalDataArchiveSource],
    to archiveURL: URL
  ) throws {
    try Data().write(
      to: archiveURL,
      options: [.atomic, .completeFileProtectionUnlessOpen]
    )
    let handle = try FileHandle(forWritingTo: archiveURL)
    do {
      try append(data: manifestData, archivePath: "manifest.json", to: handle)
      for source in sources.sorted(by: { $0.archivePath < $1.archivePath }) {
        try append(source: source, to: handle)
      }
      try handle.write(contentsOf: Data(count: blockSize * 2))
      try handle.synchronize()
      try handle.close()
    } catch {
      try? handle.close()
      throw error
    }
  }

  private static func append(
    data: Data,
    archivePath: String,
    to handle: FileHandle
  ) throws {
    try handle.write(
      contentsOf: header(
        archivePath: archivePath,
        size: Int64(data.count),
        modifiedAt: .now
      ))
    try handle.write(contentsOf: data)
    try appendPadding(for: Int64(data.count), to: handle)
  }

  private static func append(
    source: PersonalDataArchiveSource,
    to handle: FileHandle
  ) throws {
    let values = try source.sourceURL.resourceValues(forKeys: [
      .fileSizeKey, .contentModificationDateKey,
    ])
    let expectedSize = Int64(values.fileSize ?? 0)
    try handle.write(
      contentsOf: header(
        archivePath: source.archivePath,
        size: expectedSize,
        modifiedAt: values.contentModificationDate ?? .now
      ))

    let sourceHandle = try FileHandle(forReadingFrom: source.sourceURL)
    var writtenBytes: Int64 = 0
    do {
      while let chunk = try sourceHandle.read(upToCount: 64 * 1_024), !chunk.isEmpty {
        try handle.write(contentsOf: chunk)
        writtenBytes += Int64(chunk.count)
      }
      try sourceHandle.close()
    } catch {
      try? sourceHandle.close()
      throw error
    }
    guard writtenBytes == expectedSize else {
      throw PersonalDataControlError.archiveSourceChanged
    }
    try appendPadding(for: writtenBytes, to: handle)
  }

  private static func header(
    archivePath: String,
    size: Int64,
    modifiedAt: Date
  ) throws -> Data {
    guard let pathData = archivePath.data(using: .utf8), pathData.count <= 100 else {
      throw PersonalDataControlError.archivePathTooLong
    }
    var header = Data(count: blockSize)
    header.replaceSubrange(0..<pathData.count, with: pathData)
    try writeOctal(0o600, at: 100, length: 8, in: &header)
    try writeOctal(0, at: 108, length: 8, in: &header)
    try writeOctal(0, at: 116, length: 8, in: &header)
    try writeOctal(size, at: 124, length: 12, in: &header)
    try writeOctal(Int64(modifiedAt.timeIntervalSince1970), at: 136, length: 12, in: &header)
    header.replaceSubrange(148..<156, with: Data(repeating: 0x20, count: 8))
    header[156] = Character("0").asciiValue ?? 0x30
    write("ustar", at: 257, length: 6, in: &header)
    write("00", at: 263, length: 2, in: &header)
    write("adonis", at: 265, length: 32, in: &header)
    write("adonis", at: 297, length: 32, in: &header)

    let checksum = header.reduce(0) { $0 + Int64($1) }
    let checksumText = String(checksum, radix: 8)
    guard checksumText.count <= 6 else {
      throw PersonalDataControlError.exportFailed
    }
    let paddedChecksum = String(repeating: "0", count: 6 - checksumText.count) + checksumText
    let checksumData = Data((paddedChecksum + "\0 ").utf8)
    header.replaceSubrange(148..<156, with: checksumData)
    return header
  }

  private static func writeOctal(
    _ value: Int64,
    at offset: Int,
    length: Int,
    in data: inout Data
  ) throws {
    let text = String(value, radix: 8)
    guard text.count <= length - 1 else {
      throw PersonalDataControlError.exportFailed
    }
    let padded = String(repeating: "0", count: length - 1 - text.count) + text + "\0"
    data.replaceSubrange(offset..<(offset + length), with: Data(padded.utf8))
  }

  private static func write(
    _ value: String,
    at offset: Int,
    length: Int,
    in data: inout Data
  ) {
    let valueData = Data(value.utf8.prefix(length))
    data.replaceSubrange(offset..<(offset + valueData.count), with: valueData)
  }

  private static func appendPadding(for size: Int64, to handle: FileHandle) throws {
    let remainder = Int(size % Int64(blockSize))
    guard remainder != 0 else { return }
    try handle.write(contentsOf: Data(count: blockSize - remainder))
  }
}
