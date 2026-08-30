import Foundation
import SwiftData
import UIKit

struct CreativeWorkDraft: Identifiable {
  let id: UUID
  let createdAt: Date
  let recipe: CreativeRecipe
  let image: UIImage
  let processingMilliseconds: Int

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    recipe: CreativeRecipe,
    image: UIImage,
    processingMilliseconds: Int
  ) {
    self.id = id
    self.createdAt = createdAt
    self.recipe = recipe
    self.image = image
    self.processingMilliseconds = max(0, processingMilliseconds)
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

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    recipe: CreativeRecipe,
    imageFilename: String,
    processingMilliseconds: Int,
    sourceOutfit: OutfitRecord? = nil
  ) {
    self.id = id
    self.createdAt = createdAt
    self.recipeRawValue = recipe.rawValue
    self.recipeVersion = recipe.version
    self.imageFilename = imageFilename
    self.provenanceRawValue = recipe.provenance.rawValue
    self.processingMilliseconds = max(0, processingMilliseconds)
    self.sourceOutfit = sourceOutfit
  }
}
