import Foundation

enum EventInputSource: String, Sendable {
  case photoLibrary
  case camera
  case preparedSample
  case shareExtension
  case testFixture

  var title: String {
    switch self {
    case .photoLibrary: "相册"
    case .camera: "相机"
    case .preparedSample: "内置样片"
    case .shareExtension: "其他 App"
    case .testFixture: "测试样片"
    }
  }
}

enum AdonisProcessingVersion {
  static let sticker = "sticker-vision-v1"
  static let stickerQuality = "sticker-quality-structural-v1"
  static let shareCard = "share-card-v1"
  static let wardrobeAnalysis = "wardrobe-local-v1"
  static let wardrobeImageUpgrade = "wardrobe-image-upgrade-v1"
  static let outfitObservation = "ootd-observation-local-v1"
  static let candidateMatching = "wardrobe-candidate-local-v1"
  static let wardrobeHistoryMatching = "wardrobe-history-backfill-v1"
  static let sharedWardrobeInbox = SharedImageInbox.version
  static let generationPipeline =
    "\(sticker)+\(stickerQuality)+\(shareCard)+\(outfitObservation)"
}
