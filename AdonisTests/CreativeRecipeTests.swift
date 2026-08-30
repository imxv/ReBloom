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
      CreativeRecipe.botanicalPoster.traceDetail,
      "recipe=botanical_poster;provenance=programmatic_composition;ai_pixels=false;external_requests=0;external_cost=not_applicable"
    )
  }
}
