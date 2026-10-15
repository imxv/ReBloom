import Foundation
import SwiftData

struct WardrobeVisualSignatureBackfillSummary: Equatable, Sendable {
  let itemCount: Int
  let observationCount: Int
  let skippedCount: Int

  var updatedCount: Int {
    itemCount + observationCount
  }
}

@MainActor
struct WardrobeVisualSignatureBackfillService {
  typealias GenerateSignature = (Data) async -> String?

  private let mediaStore: MediaStore
  private let generateSignature: GenerateSignature

  init(
    mediaStore: MediaStore = .shared,
    generateSignature: @escaping GenerateSignature = { data in
      guard
        let signature = try? await GarmentVisualSignatureAnalyzer().signature(data: data),
        let encoded = try? signature.encoded()
      else {
        return nil
      }
      return encoded
    }
  ) {
    self.mediaStore = mediaStore
    self.generateSignature = generateSignature
  }

  func backfill(in modelContext: ModelContext) async throws
    -> WardrobeVisualSignatureBackfillSummary
  {
    let items = try modelContext.fetch(FetchDescriptor<WardrobeItem>())
    let observations = try modelContext.fetch(FetchDescriptor<GarmentObservation>())
    var itemCount = 0
    var observationCount = 0
    var skippedCount = 0

    for item in items where Self.needsBackfill(item.visualSignatureRawValue) {
      guard let data = mediaStore.data(filename: item.imageFilename),
        let encoded = await generateSignature(data)
      else {
        skippedCount += 1
        continue
      }
      item.visualSignatureRawValue = encoded
      itemCount += 1
    }

    for observation in observations
    where Self.needsBackfill(observation.visualSignatureRawValue) {
      guard let data = mediaStore.data(filename: observation.previewImageFilename),
        let encoded = await generateSignature(data)
      else {
        skippedCount += 1
        continue
      }
      observation.visualSignatureRawValue = encoded
      observationCount += 1
    }

    if itemCount + observationCount > 0 {
      do {
        try modelContext.save()
      } catch {
        modelContext.rollback()
        throw error
      }
    }
    return WardrobeVisualSignatureBackfillSummary(
      itemCount: itemCount,
      observationCount: observationCount,
      skippedCount: skippedCount
    )
  }

  private static func needsBackfill(_ rawValue: String?) -> Bool {
    guard let rawValue else { return true }
    return GarmentVisualSignature(encoded: rawValue) == nil
  }
}
