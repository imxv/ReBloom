import Foundation

enum CreativeProviderIdentifier: String, Codable, Sendable {
  case adonisLocalRenderer = "adonis_local_renderer"
  case appleImagePlayground = "apple_image_playground"
  case uiTestFixture = "ui_test_fixture"
  case unknown
}

enum CreativeNetworkTransport: String, Codable, Sendable {
  case none
  case systemManaged = "system_managed"
  case unknown
}

enum CreativeExternalCost: String, Codable, Sendable {
  case notApplicable = "not_applicable"
  case notExposed = "not_exposed"
  case unknown
}

enum CreativeQualityStatus: String, Codable, Sendable {
  case sourcePixelsPreserved = "source_pixels_preserved"
  case userReviewRequired = "user_review_required"
  case unknown
}

struct CreativeExecutionMetadata: Codable, Equatable, Sendable {
  let provider: CreativeProviderIdentifier
  let providerRequestCount: Int
  let externalRequestCount: Int?
  let networkTransport: CreativeNetworkTransport
  let externalCost: CreativeExternalCost
  let quality: CreativeQualityStatus

  init(
    provider: CreativeProviderIdentifier,
    providerRequestCount: Int,
    externalRequestCount: Int?,
    networkTransport: CreativeNetworkTransport,
    externalCost: CreativeExternalCost,
    quality: CreativeQualityStatus
  ) {
    self.provider = provider
    self.providerRequestCount = max(0, providerRequestCount)
    self.externalRequestCount = externalRequestCount.map { max(0, $0) }
    self.networkTransport = networkTransport
    self.externalCost = externalCost
    self.quality = quality
  }

  static let botanicalPoster = CreativeExecutionMetadata(
    provider: .adonisLocalRenderer,
    providerRequestCount: 0,
    externalRequestCount: 0,
    networkTransport: .none,
    externalCost: .notApplicable,
    quality: .sourcePixelsPreserved
  )

  static let stickerTryOn = CreativeExecutionMetadata(
    provider: .adonisLocalRenderer,
    providerRequestCount: 0,
    externalRequestCount: 0,
    networkTransport: .none,
    externalCost: .notApplicable,
    quality: .userReviewRequired
  )

  static let appleImagePlayground = CreativeExecutionMetadata(
    provider: .appleImagePlayground,
    providerRequestCount: 1,
    externalRequestCount: nil,
    networkTransport: .systemManaged,
    externalCost: .notExposed,
    quality: .userReviewRequired
  )

  static let uiTestFixture = CreativeExecutionMetadata(
    provider: .uiTestFixture,
    providerRequestCount: 1,
    externalRequestCount: 0,
    networkTransport: .none,
    externalCost: .notApplicable,
    quality: .userReviewRequired
  )

  func eventDetail(for recipe: CreativeRecipe) -> String {
    let externalRequests = externalRequestCount.map(String.init) ?? "unknown"
    return [
      "recipe=\(recipe.rawValue)",
      "provenance=\(recipe.provenance.rawValue)",
      "ai_pixels=\(recipe.containsAIGeneratedPixels)",
      "provider=\(provider.rawValue)",
      "provider_requests=\(providerRequestCount)",
      "external_requests=\(externalRequests)",
      "network_transport=\(networkTransport.rawValue)",
      "external_cost=\(externalCost.rawValue)",
      "quality=\(quality.rawValue)",
    ].joined(separator: ";")
  }
}
