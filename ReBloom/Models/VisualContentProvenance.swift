import Foundation

enum VisualContentProvenance: String, CaseIterable, Codable, Sendable {
  case userProvided = "user_provided"
  case derivedFromOriginal = "derived_from_original"
  case programmaticComposition = "programmatic_composition"
  case recognitionSuggestion = "recognition_suggestion"
  case aiFilled = "ai_filled"
  case aiGenerated = "ai_generated"

  var title: String {
    switch self {
    case .userProvided: "原始图片"
    case .derivedFromOriginal: "原图处理"
    case .programmaticComposition: "程序排版"
    case .recognitionSuggestion: "识别建议"
    case .aiFilled: "AI 补全"
    case .aiGenerated: "AI 生成"
    }
  }

  var summary: String {
    switch self {
    case .userProvided: "你提供的图片"
    case .derivedFromOriginal: "人物与衣物来自原图"
    case .programmaticComposition: "人物与衣物来自原图"
    case .recognitionSuggestion: "本机分析得到，等待你确认"
    case .aiFilled: "部分画面由 AI 补充"
    case .aiGenerated: "画面包含 AI 生成或重绘"
    }
  }

  var detail: String {
    switch self {
    case .userProvided:
      "这是你选择或拍摄的图片，ReBloom 没有改动画面内容。"
    case .derivedFromOriginal:
      "只做裁切、背景移除、透明通道或纯白贴纸边；人物、衣物与配饰没有被重绘。"
    case .programmaticComposition:
      "人物来自透明贴纸；日期、花朵和版式由 ReBloom 程序排版，没有补画人物或衣物。"
    case .recognitionSuggestion:
      "颜色、类别或衣物区域来自本机画面分析；确认前只是一条建议，不会当作事实。"
    case .aiFilled:
      "原图中缺失、遮挡或画面边缘的部分由 AI 补充，需要和原始内容区分。"
    case .aiGenerated:
      "画面包含 AI 新生成或重绘的内容，不代表真实拍摄结果。"
    }
  }

  var symbol: String {
    switch self {
    case .userProvided: "camera.fill"
    case .derivedFromOriginal: "person.crop.rectangle"
    case .programmaticComposition: "rectangle.portrait.on.rectangle.portrait"
    case .recognitionSuggestion: "sparkles"
    case .aiFilled: "wand.and.stars"
    case .aiGenerated: "sparkles.rectangle.stack"
    }
  }

  var containsAIGeneratedPixels: Bool {
    self == .aiFilled || self == .aiGenerated
  }

  var requiresUserConfirmation: Bool {
    self == .recognitionSuggestion
  }

  var shareCardFooter: String? {
    guard self == .programmaticComposition else { return nil }
    return "人物与衣物来自原图 · 卡面由 REBLOOM 排版"
  }
}

enum OutfitVisualAsset: String, CaseIterable, Codable, Identifiable, Sendable {
  case shareCard = "share_card"
  case sticker
  case originalPhoto = "original_photo"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .shareCard: "收藏卡"
    case .sticker: "透明贴纸"
    case .originalPhoto: "原始照片"
    }
  }

  var provenance: VisualContentProvenance {
    switch self {
    case .shareCard: .programmaticComposition
    case .sticker: .derivedFromOriginal
    case .originalPhoto: .userProvided
    }
  }
}
