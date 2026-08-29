import SwiftData
import UIKit

struct WardrobeItemImageUpgradeResult: Equatable, Sendable {
  let previousFilename: String
  let newFilename: String
  let analysis: WardrobeImageAnalysis
}

enum WardrobeItemImageUpgradeError: LocalizedError, Equatable {
  case sameImage
  case duplicateImage(itemName: String)

  var errorDescription: String? {
    switch self {
    case .sameImage:
      "这就是这件衣服现在使用的图片，不需要重复更新。"
    case .duplicateImage(let itemName):
      "这张图已经属于「\(itemName)」。为避免合错衣服，这次没有自动更新。"
    }
  }
}

enum WardrobeItemImageUpdater {
  static func apply(
    analysis: WardrobeImageAnalysis,
    newFilename: String,
    to item: WardrobeItem
  ) {
    let previousColorName = item.dominantColorName
    let previousCategory = item.category
    let shouldRefreshName = WardrobeItemNaming.isGeneratedName(
      item.name,
      colorName: previousColorName,
      category: previousCategory
    )

    item.imageFilename = newFilename
    item.sourceKind = analysis.sourceKind
    item.dominantColorName = analysis.dominantColorName
    item.dominantColorHex = analysis.dominantColorHex
    item.suggestedCategoryRawValue = analysis.suggestedCategory?.rawValue
    item.categoryConfidence = analysis.categoryConfidence
    item.cleanBackgroundScore = analysis.cleanBackgroundScore
    item.imageWidth = analysis.imageWidth
    item.imageHeight = analysis.imageHeight
    item.imageFingerprint = analysis.imageFingerprint
    item.analysisVersion = analysis.analysisVersion

    if previousCategory == .uncategorized {
      item.category = analysis.automaticallyAssignedCategory
    }
    if shouldRefreshName {
      item.name = WardrobeItemNaming.generatedName(
        colorName: item.dominantColorName,
        category: item.category
      )
    }
  }
}

@MainActor
struct WardrobeItemImageUpgradeService {
  typealias Analyze = (Data) async throws -> WardrobeImageAnalysis

  private let mediaStore: MediaStore
  private let analyze: Analyze

  init(
    mediaStore: MediaStore = .shared,
    analyze: @escaping Analyze = { data in
      try await WardrobeImageAnalyzer().analyze(data: data)
    }
  ) {
    self.mediaStore = mediaStore
    self.analyze = analyze
  }

  func upgrade(
    item: WardrobeItem,
    with data: Data,
    among wardrobeItems: [WardrobeItem],
    in modelContext: ModelContext
  ) async throws -> WardrobeItemImageUpgradeResult {
    // Preserve any name, note, or category edits made just before opening the picker.
    try modelContext.save()

    let analysis = try await analyze(data)
    if item.imageFingerprint == analysis.imageFingerprint {
      throw WardrobeItemImageUpgradeError.sameImage
    }
    if let duplicate = wardrobeItems.first(where: {
      $0.id != item.id && $0.imageFingerprint == analysis.imageFingerprint
    }) {
      throw WardrobeItemImageUpgradeError.duplicateImage(itemName: duplicate.name)
    }
    guard let image = UIImage(data: data) else {
      throw WardrobeImageAnalysisError.unreadableImage
    }

    let previousFilename = item.imageFilename
    let newFilename =
      "\(item.id.uuidString.lowercased())-upgrade-\(UUID().uuidString.lowercased()).png"
    try mediaStore.savePNG(image, filename: newFilename)

    do {
      WardrobeItemImageUpdater.apply(
        analysis: analysis,
        newFilename: newFilename,
        to: item
      )
      try modelContext.save()
    } catch {
      modelContext.rollback()
      mediaStore.delete(filename: newFilename)
      throw error
    }

    mediaStore.delete(filename: previousFilename)
    return WardrobeItemImageUpgradeResult(
      previousFilename: previousFilename,
      newFilename: newFilename,
      analysis: analysis
    )
  }
}
