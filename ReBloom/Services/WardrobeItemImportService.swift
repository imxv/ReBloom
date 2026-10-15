import SwiftData
import UIKit

enum WardrobeItemImportDisposition: Equatable, Sendable {
  case added
  case reused
}

struct WardrobeItemImportOutcome {
  let item: WardrobeItem
  let disposition: WardrobeItemImportDisposition
  let analysis: WardrobeImageAnalysis

  var eventDetail: String {
    switch disposition {
    case .added:
      let color = item.dominantColorName ?? "unknown"
      return "source=\(item.sourceKind.rawValue);color=\(color);category=\(item.category.rawValue)"
    case .reused:
      return "duplicate_fingerprint"
    }
  }
}

struct WardrobeItemImportService {
  private let mediaStore: MediaStore

  init(mediaStore: MediaStore = .shared) {
    self.mediaStore = mediaStore
  }

  @MainActor
  func persist(
    data: Data,
    analysis: WardrobeImageAnalysis,
    in modelContext: ModelContext
  ) throws -> WardrobeItemImportOutcome {
    let existingItems = try modelContext.fetch(FetchDescriptor<WardrobeItem>())
    if let existingItem = existingItems.first(where: {
      $0.imageFingerprint == analysis.imageFingerprint
    }) {
      return WardrobeItemImportOutcome(
        item: existingItem,
        disposition: .reused,
        analysis: analysis
      )
    }

    guard let image = UIImage(data: data) else {
      throw MediaStoreError.encodingFailed
    }

    let id = UUID()
    var savedFilename: String?
    do {
      let filename = try mediaStore.savePNG(
        image,
        filename: "\(id.uuidString.lowercased())-wardrobe.png"
      )
      savedFilename = filename
      let item = WardrobeItem(
        id: id,
        name: analysis.suggestedName,
        category: analysis.automaticallyAssignedCategory,
        imageFilename: filename,
        sourceKind: analysis.sourceKind,
        dominantColorName: analysis.dominantColorName,
        dominantColorHex: analysis.dominantColorHex,
        suggestedCategory: analysis.suggestedCategory,
        categoryConfidence: analysis.categoryConfidence,
        cleanBackgroundScore: analysis.cleanBackgroundScore,
        imageWidth: analysis.imageWidth,
        imageHeight: analysis.imageHeight,
        imageFingerprint: analysis.imageFingerprint,
        visualSignatureRawValue: analysis.visualSignatureRawValue,
        analysisVersion: analysis.analysisVersion
      )
      modelContext.insert(item)
      try modelContext.save()
      return WardrobeItemImportOutcome(
        item: item,
        disposition: .added,
        analysis: analysis
      )
    } catch {
      modelContext.rollback()
      if let savedFilename {
        mediaStore.delete(filename: savedFilename)
      }
      throw error
    }
  }
}
