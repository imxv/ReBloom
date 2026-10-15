import UIKit
import XCTest

@testable import Adonis

final class CreativeExecutionMetadataTests: XCTestCase {
  #if ADONIS_LEGACY_PROVIDER_DISABLED
    @MainActor
    func testSystemGeneratorIsHonestlyUnavailableWithoutLegacyImageCreator() async {
      let generator = SystemCreativeImageGenerator()

      XCTAssertEqual(generator.availability, .unavailable)
      do {
        _ = try await generator.generate(sourceImage: UIImage(), recipe: .aiStickerSource)
        XCTFail("A build without the legacy provider must not generate an image.")
      } catch CreativeGenerationError.unavailable {
        // Expected: the existing recovery UI can now offer retry or the labelled sample.
      } catch {
        XCTFail("Expected unavailable, received \(error).")
      }
    }
  #endif

  func testStickerTryOnTraceIsLocalZeroRequestAndRequiresVisualReview() {
    let metadata = CreativeExecutionMetadata.stickerTryOn

    XCTAssertEqual(metadata.provider, .adonisLocalRenderer)
    XCTAssertEqual(metadata.providerRequestCount, 0)
    XCTAssertEqual(metadata.externalRequestCount, 0)
    XCTAssertEqual(metadata.networkTransport, .none)
    XCTAssertEqual(metadata.externalCost, .notApplicable)
    XCTAssertEqual(metadata.quality, .userReviewRequired)
    XCTAssertEqual(
      metadata.eventDetail(for: .stickerTryOn),
      "recipe=sticker_try_on;provenance=programmatic_composition;ai_pixels=false;provider=adonis_local_renderer;provider_requests=0;external_requests=0;network_transport=none;external_cost=not_applicable;quality=user_review_required"
    )
  }

  func testCreativeAttemptTimerReportsMillisecondsAndNeverGoesNegative() {
    let clock = ContinuousClock()
    let startedAt = clock.now
    let timer = CreativeGenerationAttemptTimer(startedAt: startedAt)

    XCTAssertEqual(
      timer.elapsedMilliseconds(at: startedAt.advanced(by: .milliseconds(275))),
      275
    )
    XCTAssertEqual(
      timer.elapsedMilliseconds(at: startedAt.advanced(by: .milliseconds(-20))),
      0
    )
  }

  @MainActor
  func testDebugFactoryExposesDeterministicAvailableSystemCreationFixture() {
    let generator = CreativeImageGeneratorFactory.make(
      arguments: ["-ui-testing-system-creative"]
    )

    XCTAssertEqual(generator.availability, .available)
    XCTAssertEqual(generator.executionMetadata, .uiTestFixture)
  }

  @MainActor
  func testDebugFactoryCanProveUnavailableCapabilityHidesTheEntry() {
    let generator = CreativeImageGeneratorFactory.make(
      arguments: ["-ui-testing-system-creative-unavailable"]
    )

    XCTAssertEqual(generator.availability, .unavailable)
    XCTAssertEqual(generator.executionMetadata, .uiTestFixture)
  }

  func testAppleSystemGenerationKeepsUnknownTransportAndCostHonest() {
    let metadata = CreativeExecutionMetadata.appleImagePlayground

    XCTAssertEqual(metadata.provider, .appleImagePlayground)
    XCTAssertEqual(metadata.providerRequestCount, 1)
    XCTAssertNil(metadata.externalRequestCount)
    XCTAssertEqual(metadata.networkTransport, .systemManaged)
    XCTAssertEqual(metadata.externalCost, .notExposed)
    XCTAssertEqual(metadata.quality, .userReviewRequired)
    XCTAssertEqual(
      metadata.eventDetail(for: .mythicGarden),
      "recipe=mythic_garden;provenance=ai_generated;ai_pixels=true;provider=apple_image_playground;provider_requests=1;external_requests=unknown;network_transport=system_managed;external_cost=not_exposed;quality=user_review_required"
    )
  }

  func testAppleSystemSheetHasDistinctTraceAndKeepsSystemBoundaryHonest() {
    let metadata = CreativeExecutionMetadata.appleImagePlaygroundSheet

    XCTAssertEqual(metadata.provider, .appleImagePlaygroundSheet)
    XCTAssertNotEqual(metadata.provider, .appleImagePlayground)
    XCTAssertEqual(metadata.providerRequestCount, 1)
    XCTAssertNil(metadata.externalRequestCount)
    XCTAssertEqual(metadata.networkTransport, .systemManaged)
    XCTAssertEqual(metadata.externalCost, .notExposed)
    XCTAssertEqual(metadata.quality, .userReviewRequired)
    XCTAssertEqual(
      metadata.eventDetail(for: .aiStickerSource),
      "recipe=ai_sticker_source;provenance=ai_generated;ai_pixels=true;provider=apple_image_playground_sheet;provider_requests=1;external_requests=unknown;network_transport=system_managed;external_cost=not_exposed;quality=user_review_required"
    )
  }

  func testTwoPassStickerMetadataKeepsSourceAndTransparentEditProvidersDistinct() {
    let metadata = CreativeExecutionMetadata.aiStickerTwoPass(
      source: .appleImagePlaygroundSheet,
      extraction: .openAIGPTImageExtraction
    )

    XCTAssertEqual(metadata.provider, .aiStickerTwoPass)
    XCTAssertEqual(metadata.providerRequestCount, 2)
    XCTAssertNil(metadata.externalRequestCount)
    XCTAssertEqual(metadata.networkTransport, .mixedSystemAndDeveloperProxy)
    XCTAssertEqual(metadata.externalCost, .unknown)
    XCTAssertEqual(metadata.sourceProvider, .appleImagePlaygroundSheet)
    XCTAssertEqual(metadata.extractionProvider, .openAIGPTImage)
    XCTAssertTrue(
      metadata.eventDetail(for: .aiStickerSource).contains(
        "source_provider=apple_image_playground_sheet;extraction_provider=openai_gpt_image"
      )
    )
  }

  func testOlderExecutionMetadataStillDecodesWithoutTwoPassProviderFields() throws {
    let data = Data(
      """
      {
        "provider": "apple_image_playground",
        "providerRequestCount": 1,
        "externalRequestCount": null,
        "networkTransport": "system_managed",
        "externalCost": "not_exposed",
        "quality": "user_review_required"
      }
      """.utf8
    )

    let metadata = try JSONDecoder().decode(CreativeExecutionMetadata.self, from: data)

    XCTAssertNil(metadata.sourceProvider)
    XCTAssertNil(metadata.extractionProvider)
    XCTAssertEqual(metadata.provider, .appleImagePlayground)
  }

  func testCreativeGenerationErrorsUseStableCodesAndPlainRecoveryCopy() {
    XCTAssertEqual(CreativeGenerationError.unavailable.eventCode, "unavailable")
    XCTAssertEqual(CreativeGenerationError.unsupportedSource.eventCode, "unsupported_source")
    XCTAssertEqual(CreativeGenerationError.personTooSmall.eventCode, "person_too_small")
    XCTAssertEqual(CreativeGenerationError.timedOut.eventCode, "timed_out")
    XCTAssertEqual(CreativeGenerationError.noImage.eventCode, "no_image")
    let unavailableDescription = CreativeGenerationError.unavailable.localizedDescription
    XCTAssertTrue(unavailableDescription.contains("当前设备或系统设置"))
    XCTAssertFalse(unavailableDescription.contains("花影海报"))
    XCTAssertTrue(
      CreativeGenerationError.personTooSmall.localizedDescription.contains("换一张")
    )
  }
}
