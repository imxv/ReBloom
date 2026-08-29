import Foundation
import SwiftData

@Model
final class OutfitRecord {
  @Attribute(.unique) var id: UUID
  var createdAt: Date
  var title: String
  var sourceImageFilename: String
  var stickerImageFilename: String
  var cardImageFilename: String
  var bloomNumber: Int
  var note: String
  var stickerQualityLevelRawValue: String = StickerQualityLevel.acceptable.rawValue
  var stickerQualityIssueRawValues: String = ""
  var stickerQualityVersion: String = AdonisProcessingVersion.stickerQuality
  @Relationship(deleteRule: .cascade, inverse: \GarmentObservation.outfit)
  var garmentObservations: [GarmentObservation] = []

  var stickerQualityAssessment: StickerQualityAssessment {
    StickerQualityAssessment(
      levelRawValue: stickerQualityLevelRawValue,
      issueRawValues: stickerQualityIssueRawValues
    )
  }

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    title: String = "今日穿搭",
    sourceImageFilename: String,
    stickerImageFilename: String,
    cardImageFilename: String,
    bloomNumber: Int,
    note: String = "",
    stickerQualityAssessment: StickerQualityAssessment = .acceptable,
    stickerQualityVersion: String = AdonisProcessingVersion.stickerQuality,
    garmentObservations: [GarmentObservation] = []
  ) {
    self.id = id
    self.createdAt = createdAt
    self.title = title
    self.sourceImageFilename = sourceImageFilename
    self.stickerImageFilename = stickerImageFilename
    self.cardImageFilename = cardImageFilename
    self.bloomNumber = bloomNumber
    self.note = note
    self.stickerQualityLevelRawValue = stickerQualityAssessment.level.rawValue
    self.stickerQualityIssueRawValues = stickerQualityAssessment.issueRawValues
    self.stickerQualityVersion = stickerQualityVersion
    self.garmentObservations = garmentObservations
  }
}
