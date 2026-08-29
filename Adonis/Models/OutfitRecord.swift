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

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    title: String = "今日穿搭",
    sourceImageFilename: String,
    stickerImageFilename: String,
    cardImageFilename: String,
    bloomNumber: Int,
    note: String = ""
  ) {
    self.id = id
    self.createdAt = createdAt
    self.title = title
    self.sourceImageFilename = sourceImageFilename
    self.stickerImageFilename = stickerImageFilename
    self.cardImageFilename = cardImageFilename
    self.bloomNumber = bloomNumber
    self.note = note
  }
}
