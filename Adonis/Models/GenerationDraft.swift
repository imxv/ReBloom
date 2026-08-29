import Foundation
import UIKit

enum GenerationCompletionMode: String, Codable, Sendable {
  case complete
  case basicStickerFallback = "basic_sticker_fallback"

  var resultTitle: String {
    switch self {
    case .complete: "今天开了一朵花"
    case .basicStickerFallback: "先收下这张贴纸"
    }
  }
}

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
  let completionMode: GenerationCompletionMode
  let qualityAssessment: StickerQualityAssessment
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
    completionMode: GenerationCompletionMode = .complete,
    qualityAssessment: StickerQualityAssessment = .acceptable,
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
    self.completionMode = completionMode
    self.qualityAssessment = qualityAssessment
    self.garmentObservations = garmentObservations
  }
}

enum ProcessingStage: String, CaseIterable {
  case reading = "正在读取照片"
  case separating = "正在沿轮廓裁出你"
  case checking = "正在检查贴纸边缘"
  case outlining = "正在加上纯白贴纸边"
  case composing = "正在装进收藏卡"
  case observing = "正在看看今天穿了什么"
}
