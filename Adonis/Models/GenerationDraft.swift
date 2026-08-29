import Foundation
import UIKit

struct GenerationDraft: Identifiable {
  let id: UUID
  let createdAt: Date
  let sourceImage: UIImage
  let stickerImage: UIImage
  let cardImage: UIImage
  let bloomNumber: Int
  let processingMilliseconds: Int
  let foregroundCoverage: Double
  let usesPreparedSample: Bool
  let inputSource: EventInputSource
  let garmentObservations: [GarmentObservationDraft]

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    sourceImage: UIImage,
    stickerImage: UIImage,
    cardImage: UIImage,
    bloomNumber: Int,
    processingMilliseconds: Int,
    foregroundCoverage: Double,
    usesPreparedSample: Bool = false,
    inputSource: EventInputSource,
    garmentObservations: [GarmentObservationDraft] = []
  ) {
    self.id = id
    self.createdAt = createdAt
    self.sourceImage = sourceImage
    self.stickerImage = stickerImage
    self.cardImage = cardImage
    self.bloomNumber = bloomNumber
    self.processingMilliseconds = processingMilliseconds
    self.foregroundCoverage = foregroundCoverage
    self.usesPreparedSample = usesPreparedSample
    self.inputSource = inputSource
    self.garmentObservations = garmentObservations
  }
}

enum ProcessingStage: String, CaseIterable {
  case reading = "正在读取照片"
  case separating = "正在沿轮廓裁出你"
  case outlining = "正在加上纯白贴纸边"
  case composing = "正在装进收藏卡"
  case observing = "正在看看今天穿了什么"
}
