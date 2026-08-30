import XCTest

@testable import Adonis

final class CreativeRecipeTests: XCTestCase {
  func testBotanicalPosterIsAOneTapNonAIRecipeWithExplicitBoundaries() {
    let recipe = CreativeRecipe.botanicalPoster

    XCTAssertEqual(recipe.rawValue, "botanical_poster")
    XCTAssertEqual(recipe.title, "花影海报")
    XCTAssertEqual(recipe.version, "botanical-poster-v1")
    XCTAssertEqual(recipe.provenance, .programmaticComposition)
    XCTAssertFalse(recipe.containsAIGeneratedPixels)
    XCTAssertTrue(recipe.preservedElements.contains("人物与衣物"))
    XCTAssertTrue(recipe.changedElements.contains("背景"))

    let userFacingCopy = [
      recipe.title,
      recipe.subtitle,
      recipe.preservedElements,
      recipe.changedElements,
    ].joined(separator: " ")
    for hiddenTerm in ["Prompt", "Skill", "模型", "工作流"] {
      XCTAssertFalse(userFacingCopy.localizedCaseInsensitiveContains(hiddenTerm))
    }
  }

  func testLocalRecipeTraceDistinguishesPixelOriginRequestsAndCostWithoutUserContent() {
    XCTAssertEqual(
      CreativeExecutionMetadata.botanicalPoster.eventDetail(for: .botanicalPoster),
      "recipe=botanical_poster;provenance=programmatic_composition;ai_pixels=false;provider=adonis_local_renderer;provider_requests=0;external_requests=0;network_transport=none;external_cost=not_applicable;quality=source_pixels_preserved"
    )
  }

  func testMythicGardenIsOneCuratedAIResultWithHonestChangeBoundary() {
    let recipe = CreativeRecipe.mythicGarden

    XCTAssertEqual(recipe.rawValue, "mythic_garden")
    XCTAssertEqual(recipe.title, "永生花园")
    XCTAssertEqual(recipe.version, "mythic-garden-v1")
    XCTAssertEqual(recipe.provenance, .aiGenerated)
    XCTAssertTrue(recipe.containsAIGeneratedPixels)
    XCTAssertTrue(recipe.preservedElements.contains("创作参考"))
    XCTAssertTrue(recipe.changedElements.contains("人物"))
    XCTAssertTrue(recipe.changedElements.contains("衣物"))
    XCTAssertTrue(recipe.requiresSystemImageGeneration)

    let userFacingCopy = [
      recipe.title,
      recipe.subtitle,
      recipe.preservedElements,
      recipe.changedElements,
    ].joined(separator: " ")
    for hiddenTerm in ["Prompt", "Skill", "模型", "工作流"] {
      XCTAssertFalse(userFacingCopy.localizedCaseInsensitiveContains(hiddenTerm))
    }
  }
}
