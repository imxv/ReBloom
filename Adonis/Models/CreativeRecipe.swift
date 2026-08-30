import Foundation

enum CreativeRecipe: String, CaseIterable, Codable, Identifiable, Sendable {
  case botanicalPoster = "botanical_poster"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .botanicalPoster: "花影海报"
    }
  }

  var subtitle: String {
    switch self {
    case .botanicalPoster: "把今天放进一片会再次盛开的花影里"
    }
  }

  var version: String {
    switch self {
    case .botanicalPoster: AdonisProcessingVersion.botanicalPoster
    }
  }

  var provenance: VisualContentProvenance {
    switch self {
    case .botanicalPoster: .programmaticComposition
    }
  }

  var preservedElements: String {
    switch self {
    case .botanicalPoster: "保留人物与衣物、姿势和纯白贴纸边"
    }
  }

  var changedElements: String {
    switch self {
    case .botanicalPoster: "改变背景、花影、文字和版式"
    }
  }

  var containsAIGeneratedPixels: Bool {
    provenance.containsAIGeneratedPixels
  }

  var traceDetail: String {
    "recipe=\(rawValue);provenance=\(provenance.rawValue);ai_pixels=\(containsAIGeneratedPixels);external_requests=0;external_cost=not_applicable"
  }
}
