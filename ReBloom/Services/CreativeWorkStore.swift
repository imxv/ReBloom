import Foundation
import SwiftData

struct CreativeWorkStore {
  private let mediaStore: MediaStore

  init(mediaStore: MediaStore = .shared) {
    self.mediaStore = mediaStore
  }

  @MainActor
  func save(
    _ draft: CreativeWorkDraft,
    for outfit: OutfitRecord,
    in modelContext: ModelContext
  ) throws -> CreativeWork {
    if let existing = outfit.creativeWorks.first(where: { $0.id == draft.id }) {
      return existing
    }

    let filename =
      "\(draft.id.uuidString.lowercased())-creative-\(draft.recipe.rawValue).png"
    try mediaStore.savePNG(draft.image, filename: filename)

    let work = CreativeWork(
      id: draft.id,
      createdAt: draft.createdAt,
      recipe: draft.recipe,
      imageFilename: filename,
      processingMilliseconds: draft.processingMilliseconds,
      executionMetadata: draft.executionMetadata,
      provenance: draft.provenance,
      sourceOutfit: outfit
    )
    modelContext.insert(work)
    outfit.creativeWorks.append(work)

    do {
      try modelContext.save()
      return work
    } catch {
      modelContext.rollback()
      mediaStore.delete(filename: filename)
      throw error
    }
  }
}

enum CreativeWorkStoreError: LocalizedError {
  case missingSourceOutfit

  var errorDescription: String? {
    switch self {
    case .missingSourceOutfit:
      "原来的穿搭记录暂时无法读取，作品没有收藏。"
    }
  }
}
