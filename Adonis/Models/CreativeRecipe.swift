import Foundation

enum CreativeSystemImageStyle: String, Codable, Sendable {
  case illustration
  case sketch
  case animation
}

enum CreativeRecipe: String, CaseIterable, Codable, Identifiable, Sendable {
  case aiStickerSource = "ai_sticker_source"
  case botanicalPoster = "botanical_poster"
  case floralSketch = "floral_sketch"
  case mythicGarden = "mythic_garden"
  case moonlitTheater = "moonlit_theater"
  case stickerTryOn = "sticker_try_on"

  var id: String { rawValue }

  static let curatedSystemRecipes: [CreativeRecipe] = [
    .mythicGarden,
    .floralSketch,
    .moonlitTheater,
  ]

  var title: String {
    switch self {
    case .aiStickerSource: "AI 贴纸形象"
    case .botanicalPoster: "花影海报"
    case .floralSketch: "花神速写"
    case .mythicGarden: "永生花园"
    case .moonlitTheater: "月光剧场"
    case .stickerTryOn: "贴纸试搭"
    }
  }

  var subtitle: String {
    switch self {
    case .aiStickerSource: "先生成背景干净的贴纸形象，再做透明抠图"
    case .botanicalPoster: "把今天放进一片会再次盛开的花影里"
    case .floralSketch: "把这一刻画成纸上的时装手稿"
    case .mythicGarden: "把这一刻重绘成阿多尼斯的永生花园"
    case .moonlitTheater: "走进一帧蓝夜与花火交织的动画"
    case .stickerTryOn: "把衣橱商品图轻轻贴到最近一次 OOTD 上"
    }
  }

  var version: String {
    switch self {
    case .aiStickerSource: AdonisProcessingVersion.aiStickerSource
    case .botanicalPoster: AdonisProcessingVersion.botanicalPoster
    case .floralSketch: AdonisProcessingVersion.floralSketch
    case .mythicGarden: AdonisProcessingVersion.mythicGarden
    case .moonlitTheater: AdonisProcessingVersion.moonlitTheater
    case .stickerTryOn: AdonisProcessingVersion.stickerTryOn
    }
  }

  var provenance: VisualContentProvenance {
    switch self {
    case .botanicalPoster, .stickerTryOn: .programmaticComposition
    case .aiStickerSource, .floralSketch, .mythicGarden, .moonlitTheater: .aiGenerated
    }
  }

  var preservedElements: String {
    switch self {
    case .aiStickerSource: "以原始照片中的人物、姿势、衣物和配饰为参考"
    case .botanicalPoster: "保留人物与衣物、姿势和纯白贴纸边"
    case .floralSketch, .mythicGarden, .moonlitTheater: "原始照片只作为创作参考"
    case .stickerTryOn: "保留原始照片的脸、身体、姿势和背景像素"
    }
  }

  var changedElements: String {
    switch self {
    case .aiStickerSource: "人物与衣物会由 AI 重绘，再移除生成背景"
    case .botanicalPoster: "改变背景、花影、文字和版式"
    case .floralSketch, .mythicGarden, .moonlitTheater: "人物、衣物、背景和画风都可能改变"
    case .stickerTryOn: "裁切、缩放并覆盖衣物图；不计算真实尺码、垂坠和遮挡"
    }
  }

  var containsAIGeneratedPixels: Bool {
    provenance.containsAIGeneratedPixels
  }

  var requiresSystemImageGeneration: Bool {
    systemImageStyle != nil
  }

  var systemImageStyle: CreativeSystemImageStyle? {
    switch self {
    case .botanicalPoster, .stickerTryOn: nil
    case .aiStickerSource: .animation
    case .floralSketch: .sketch
    case .mythicGarden: .illustration
    case .moonlitTheater: .animation
    }
  }

  var systemConcept: String {
    switch self {
    case .botanicalPoster, .stickerTryOn:
      ""
    case .aiStickerSource:
      "A clean high-fidelity full-body fashion sticker portrait of the same person, preserving the pose, outfit colors, garment details, shoes, bag, accessories, hair, and body proportions from the reference image, centered as one complete figure on a plain warm-white background, crisp separation, no text, no frame, no extra people, no cropped limbs"
    case .floralSketch:
      "A fashion deity sketched in expressive graphite and colored pencil on warm cream paper, pressed pomegranate petals and evergreen leaves, full fashion portrait"
    case .mythicGarden:
      "A youthful botanical myth in an editorial illustration, pomegranate blossoms, evergreen leaves, rich burgundy, butter yellow, and a full fashion portrait"
    case .moonlitTheater:
      "A dreamlike cel animation still in a moonlit greenhouse, cobalt blue, coral flower sparks, pale gold light, and a youthful full fashion portrait"
    }
  }
}
