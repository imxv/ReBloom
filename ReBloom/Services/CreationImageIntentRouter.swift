enum CreationImageIntentRoute: Equatable, Sendable {
  case wardrobe
  case creation(offersWardrobeFallback: Bool)
}

struct CreationImageIntentRouter {
  static let version = AdonisProcessingVersion.creationImageIntent

  private let minimumCleanBackgroundScore = 0.78
  private let minimumDirectRouteConfidence = 0.72

  func route(_ analysis: WardrobeImageAnalysis) -> CreationImageIntentRoute {
    guard analysis.sourceKind == .catalogImage,
      analysis.cleanBackgroundScore >= minimumCleanBackgroundScore
    else {
      return .creation(offersWardrobeFallback: false)
    }

    guard let suggestedCategory = analysis.suggestedCategory,
      suggestedCategory != .uncategorized,
      (analysis.categoryConfidence ?? 0) >= minimumDirectRouteConfidence
    else {
      return .creation(offersWardrobeFallback: true)
    }

    return .wardrobe
  }
}
