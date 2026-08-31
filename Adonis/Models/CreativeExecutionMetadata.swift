import Foundation

enum CreativeProviderIdentifier: String, Codable, Sendable {
  case adonisLocalRenderer = "adonis_local_renderer"
  case aiStickerTwoPass = "ai_sticker_two_pass"
  case appleImagePlayground = "apple_image_playground"
  case appleImagePlaygroundSheet = "apple_image_playground_sheet"
  case openAIGPTImage = "openai_gpt_image"
  case uiTestFixture = "ui_test_fixture"
  case unknown
}

enum CreativeNetworkTransport: String, Codable, Sendable {
  case none
  case developerProxy = "developer_proxy"
  case mixedSystemAndDeveloperProxy = "mixed_system_and_developer_proxy"
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
  let sourceProvider: CreativeProviderIdentifier?
  let extractionProvider: CreativeProviderIdentifier?

  init(
    provider: CreativeProviderIdentifier,
    providerRequestCount: Int,
    externalRequestCount: Int?,
    networkTransport: CreativeNetworkTransport,
    externalCost: CreativeExternalCost,
    quality: CreativeQualityStatus,
    sourceProvider: CreativeProviderIdentifier? = nil,
    extractionProvider: CreativeProviderIdentifier? = nil
  ) {
    self.provider = provider
    self.providerRequestCount = max(0, providerRequestCount)
    self.externalRequestCount = externalRequestCount.map { max(0, $0) }
    self.networkTransport = networkTransport
    self.externalCost = externalCost
    self.quality = quality
    self.sourceProvider = sourceProvider
    self.extractionProvider = extractionProvider
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

  static let appleImagePlaygroundSheet = CreativeExecutionMetadata(
    provider: .appleImagePlaygroundSheet,
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

  static let openAIGPTImageExtraction = CreativeExecutionMetadata(
    provider: .openAIGPTImage,
    providerRequestCount: 1,
    externalRequestCount: 1,
    networkTransport: .developerProxy,
    externalCost: .unknown,
    quality: .userReviewRequired
  )

  static func aiStickerTwoPass(
    source: CreativeExecutionMetadata,
    extraction: CreativeExecutionMetadata
  ) -> CreativeExecutionMetadata {
    let transport: CreativeNetworkTransport
    if source.networkTransport == .none {
      transport = extraction.networkTransport
    } else if extraction.networkTransport == .none {
      transport = source.networkTransport
    } else if source.networkTransport == extraction.networkTransport {
      transport = source.networkTransport
    } else {
      transport = .mixedSystemAndDeveloperProxy
    }
    return CreativeExecutionMetadata(
      provider: .aiStickerTwoPass,
      providerRequestCount: source.providerRequestCount + extraction.providerRequestCount,
      externalRequestCount: source.externalRequestCount.flatMap { sourceCount in
        extraction.externalRequestCount.map { sourceCount + $0 }
      },
      networkTransport: transport,
      externalCost: source.externalCost == .notApplicable
        ? extraction.externalCost : .unknown,
      quality: .userReviewRequired,
      sourceProvider: source.provider,
      extractionProvider: extraction.provider
    )
  }

  func eventDetail(for recipe: CreativeRecipe) -> String {
    let externalRequests = externalRequestCount.map(String.init) ?? "unknown"
    var fields = [
      "recipe=\(recipe.rawValue)",
      "provenance=\(recipe.provenance.rawValue)",
      "ai_pixels=\(recipe.containsAIGeneratedPixels)",
      "provider=\(provider.rawValue)",
      "provider_requests=\(providerRequestCount)",
      "external_requests=\(externalRequests)",
      "network_transport=\(networkTransport.rawValue)",
      "external_cost=\(externalCost.rawValue)",
      "quality=\(quality.rawValue)",
    ]
    if let sourceProvider {
      fields.append("source_provider=\(sourceProvider.rawValue)")
    }
    if let extractionProvider {
      fields.append("extraction_provider=\(extractionProvider.rawValue)")
    }
    return fields.joined(separator: ";")
  }
}
