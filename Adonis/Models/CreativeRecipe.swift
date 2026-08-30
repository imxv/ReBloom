import Foundation

enum CreativeRecipe: String, CaseIterable, Codable, Identifiable, Sendable {
  case botanicalPoster = "botanical_poster"
  case mythicGarden = "mythic_garden"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .botanicalPoster: "花影海报"
    case .mythicGarden: "永生花园"
    }
  }

  var subtitle: String {
    switch self {
    case .botanicalPoster: "把今天放进一片会再次盛开的花影里"
    case .mythicGarden: "把这一刻重绘成阿多尼斯的永生花园"
    }
  }

  var version: String {
    switch self {
    case .botanicalPoster: AdonisProcessingVersion.botanicalPoster
    case .mythicGarden: AdonisProcessingVersion.mythicGarden
    }
  }

  var provenance: VisualContentProvenance {
    switch self {
    case .botanicalPoster: .programmaticComposition
    case .mythicGarden: .aiGenerated
    }
  }

  var preservedElements: String {
    switch self {
    case .botanicalPoster: "保留人物与衣物、姿势和纯白贴纸边"
    case .mythicGarden: "原始照片只作为创作参考"
    }
  }

  var changedElements: String {
    switch self {
    case .botanicalPoster: "改变背景、花影、文字和版式"
    case .mythicGarden: "人物、衣物、背景和画风都可能改变"
    }
  }

  var containsAIGeneratedPixels: Bool {
    provenance.containsAIGeneratedPixels
  }

  var requiresSystemImageGeneration: Bool {
    self == .mythicGarden
  }

  var systemConcept: String {
    switch self {
    case .botanicalPoster:
      ""
    case .mythicGarden:
      "A youthful botanical myth in an editorial illustration, pomegranate blossoms, evergreen leaves, rich burgundy, butter yellow, and a full fashion portrait"
    }
  }
}
