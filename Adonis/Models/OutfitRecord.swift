import Foundation
import SwiftData

@Model
final class OutfitRecord {
  @Attribute(.unique) var id: UUID
  var createdAt: Date
  var title: String
  var sourceImageFilename: String
  var aiStickerSourceImageFilename: String?
  var stickerImageFilename: String
  var cardImageFilename: String
  var bloomNumber: Int
  var note: String
  var stickerProvenanceRawValue: String = VisualContentProvenance.derivedFromOriginal.rawValue
  var stickerExecutionMetadataData: Data?
  var generationCompletionModeRawValue: String = GenerationCompletionMode.complete.rawValue
  var stickerQualityLevelRawValue: String = StickerQualityLevel.acceptable.rawValue
  var stickerQualityIssueRawValues: String = ""
  var stickerQualityVersion: String = AdonisProcessingVersion.stickerQuality
  @Relationship(deleteRule: .cascade, inverse: \GarmentObservation.outfit)
  var garmentObservations: [GarmentObservation] = []
  @Relationship(deleteRule: .cascade, inverse: \CreativeWork.sourceOutfit)
  var creativeWorks: [CreativeWork] = []

  var stickerQualityAssessment: StickerQualityAssessment {
    StickerQualityAssessment(
      levelRawValue: stickerQualityLevelRawValue,
      issueRawValues: stickerQualityIssueRawValues
    )
  }

  var generationCompletionMode: GenerationCompletionMode {
    GenerationCompletionMode(rawValue: generationCompletionModeRawValue) ?? .complete
  }

  var stickerProvenance: VisualContentProvenance {
    VisualContentProvenance(rawValue: stickerProvenanceRawValue) ?? .derivedFromOriginal
  }

  var stickerExecutionMetadata: CreativeExecutionMetadata? {
    guard let stickerExecutionMetadataData else { return nil }
    return try? JSONDecoder().decode(
      CreativeExecutionMetadata.self,
      from: stickerExecutionMetadataData
    )
  }

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    title: String = "今日穿搭",
    sourceImageFilename: String,
    aiStickerSourceImageFilename: String? = nil,
    stickerImageFilename: String,
    cardImageFilename: String,
    bloomNumber: Int,
    stickerProvenance: VisualContentProvenance = .derivedFromOriginal,
    stickerExecutionMetadata: CreativeExecutionMetadata? = nil,
    note: String = "",
    generationCompletionMode: GenerationCompletionMode = .complete,
    stickerQualityAssessment: StickerQualityAssessment = .acceptable,
    stickerQualityVersion: String = AdonisProcessingVersion.stickerQuality,
    garmentObservations: [GarmentObservation] = [],
    creativeWorks: [CreativeWork] = []
  ) {
    self.id = id
    self.createdAt = createdAt
    self.title = title
    self.sourceImageFilename = sourceImageFilename
    self.aiStickerSourceImageFilename = aiStickerSourceImageFilename
    self.stickerImageFilename = stickerImageFilename
    self.cardImageFilename = cardImageFilename
    self.bloomNumber = bloomNumber
    self.stickerProvenanceRawValue = stickerProvenance.rawValue
    self.stickerExecutionMetadataData = stickerExecutionMetadata.flatMap {
      try? JSONEncoder().encode($0)
    }
    self.note = note
    self.generationCompletionModeRawValue = generationCompletionMode.rawValue
    self.stickerQualityLevelRawValue = stickerQualityAssessment.level.rawValue
    self.stickerQualityIssueRawValues = stickerQualityAssessment.issueRawValues
    self.stickerQualityVersion = stickerQualityVersion
    self.garmentObservations = garmentObservations
    self.creativeWorks = creativeWorks
  }

  func provenance(for asset: OutfitVisualAsset) -> VisualContentProvenance {
    switch asset {
    case .originalPhoto:
      .userProvided
    case .sticker:
      stickerProvenance
    case .shareCard:
      stickerProvenance.containsAIGeneratedPixels ? .aiGenerated : .programmaticComposition
    }
  }
}
