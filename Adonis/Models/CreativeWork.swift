import Foundation
import SwiftData
import UIKit

struct CreativeWorkDraft: Identifiable {
  let id: UUID
  let createdAt: Date
  let recipe: CreativeRecipe
  let image: UIImage
  let processingMilliseconds: Int
  let executionMetadata: CreativeExecutionMetadata
  let provenance: VisualContentProvenance

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    recipe: CreativeRecipe,
    image: UIImage,
    processingMilliseconds: Int,
    executionMetadata: CreativeExecutionMetadata,
    provenance: VisualContentProvenance? = nil
  ) {
    self.id = id
    self.createdAt = createdAt
    self.recipe = recipe
    self.image = image
    self.processingMilliseconds = max(0, processingMilliseconds)
    self.executionMetadata = executionMetadata
    self.provenance = provenance ?? recipe.provenance
  }

  var eventDetail: String {
    let base = executionMetadata.eventDetail(for: recipe)
    guard provenance != recipe.provenance else { return base }
    return "\(base);output_provenance=\(provenance.rawValue)"
  }
}

@Model
final class CreativeWork {
  @Attribute(.unique) var id: UUID
  var createdAt: Date
  var recipeRawValue: String
  var recipeVersion: String
  var imageFilename: String
  var provenanceRawValue: String
  var processingMilliseconds: Int
  var providerRawValue: String = CreativeProviderIdentifier.adonisLocalRenderer.rawValue
  var providerRequestCount: Int = 0
  var externalRequestCount: Int? = 0
  var networkTransportRawValue: String = CreativeNetworkTransport.none.rawValue
  var externalCostRawValue: String = CreativeExternalCost.notApplicable.rawValue
  var qualityRawValue: String = CreativeQualityStatus.sourcePixelsPreserved.rawValue
  var sourceOutfit: OutfitRecord?

  var recipe: CreativeRecipe {
    CreativeRecipe(rawValue: recipeRawValue) ?? .botanicalPoster
  }

  var provenance: VisualContentProvenance {
    VisualContentProvenance(rawValue: provenanceRawValue) ?? .programmaticComposition
  }

  var containsAIGeneratedPixels: Bool {
    provenance.containsAIGeneratedPixels
  }

  var executionMetadata: CreativeExecutionMetadata {
    CreativeExecutionMetadata(
      provider: CreativeProviderIdentifier(rawValue: providerRawValue) ?? .unknown,
      providerRequestCount: providerRequestCount,
      externalRequestCount: externalRequestCount,
      networkTransport: CreativeNetworkTransport(rawValue: networkTransportRawValue) ?? .unknown,
      externalCost: CreativeExternalCost(rawValue: externalCostRawValue) ?? .unknown,
      quality: CreativeQualityStatus(rawValue: qualityRawValue) ?? .unknown
    )
  }

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    recipe: CreativeRecipe,
    imageFilename: String,
    processingMilliseconds: Int,
    executionMetadata: CreativeExecutionMetadata,
    provenance: VisualContentProvenance? = nil,
    sourceOutfit: OutfitRecord? = nil
  ) {
    self.id = id
    self.createdAt = createdAt
    self.recipeRawValue = recipe.rawValue
    self.recipeVersion = recipe.version
    self.imageFilename = imageFilename
    self.provenanceRawValue = (provenance ?? recipe.provenance).rawValue
    self.processingMilliseconds = max(0, processingMilliseconds)
    self.providerRawValue = executionMetadata.provider.rawValue
    self.providerRequestCount = executionMetadata.providerRequestCount
    self.externalRequestCount = executionMetadata.externalRequestCount
    self.networkTransportRawValue = executionMetadata.networkTransport.rawValue
    self.externalCostRawValue = executionMetadata.externalCost.rawValue
    self.qualityRawValue = executionMetadata.quality.rawValue
    self.sourceOutfit = sourceOutfit
  }
}
