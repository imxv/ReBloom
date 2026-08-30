import UIKit
import XCTest

@testable import Adonis

@MainActor
final class AIStickerCreationPipelineTests: XCTestCase {
  func testAIGeneratedOpaqueImageBecomesTheMattingInput() async throws {
    let sourceImage = solidImage(color: .red)
    let generatedImage = halfTransparentImage()
    var capturedMattingInput: UIImage?
    var stageOrder: [String] = []
    let metadata = CreativeExecutionMetadata.appleImagePlayground
    let pipeline = AIStickerCreationPipeline(
      sourceGenerator: AIStickerSourceGeneratorStub(
        output: CreativeProviderOutput(
          image: generatedImage,
          executionMetadata: metadata
        )
      ),
      extractSticker: { input in
        stageOrder.append("matting")
        capturedMattingInput = input
        return StickerProcessingResult(
          image: input,
          elapsedMilliseconds: 12,
          foregroundCoverage: 0.42,
          rawMatteAssessment: .acceptable,
          sourceFidelityAssessment: .acceptable
        )
      }
    )

    let result = try await pipeline.createSticker(from: sourceImage) { _, _ in
      stageOrder.append("ai_source_ready")
    }
    let mattingInput = try XCTUnwrap(capturedMattingInput)

    XCTAssertEqual(pixel(in: mattingInput, x: 0, y: 0), [255, 255, 255, 255])
    XCTAssertEqual(pixel(in: mattingInput, x: 1, y: 1), [0, 255, 0, 255])
    XCTAssertEqual(pixel(in: result.generatedSourceImage, x: 1, y: 1), [0, 255, 0, 255])
    XCTAssertEqual(result.executionMetadata, metadata)
    XCTAssertEqual(stageOrder, ["ai_source_ready", "matting"])
    XCTAssertNotEqual(pixel(in: mattingInput, x: 1, y: 1), pixel(in: sourceImage, x: 1, y: 1))
  }

  func testCreativeAdapterUsesTheHiddenAIStickerSourceRecipe() async throws {
    let provider = RecordingCreativeImageGenerator()
    let generator = CreativeAIStickerSourceGenerator(generator: provider)
    let sourceImage = solidImage(color: .red)

    let output = try await generator.generateSource(from: sourceImage)

    XCTAssertEqual(provider.receivedRecipe, .aiStickerSource)
    XCTAssertTrue(provider.receivedSourceImage === sourceImage)
    XCTAssertEqual(output.executionMetadata, .appleImagePlayground)
  }

  func testUnavailableAIGenerationNeverFallsBackToMattingTheOriginal() async {
    let sourceImage = solidImage(color: .red)
    var extractorWasCalled = false
    let pipeline = AIStickerCreationPipeline(
      sourceGenerator: AIStickerSourceGeneratorStub(
        output: CreativeProviderOutput(
          image: solidImage(color: .green),
          executionMetadata: .appleImagePlayground
        ),
        availability: .unavailable
      ),
      extractSticker: { _ in
        extractorWasCalled = true
        throw CreativeGenerationError.failed
      }
    )

    do {
      _ = try await pipeline.createSticker(from: sourceImage)
      XCTFail("Expected unavailable AI generation to stop before matting")
    } catch {
      XCTAssertEqual(error as? CreativeGenerationError, .unavailable)
    }
    XCTAssertFalse(extractorWasCalled)
  }

  func testAIGeneratedStickerProvenanceSurvivesIntoTheOutfitRecord() {
    let source = solidImage(color: .red)
    let generatedSource = solidImage(color: .white)
    let sticker = solidImage(color: .green)
    let card = solidImage(color: .blue)
    let metadata = CreativeExecutionMetadata.appleImagePlayground
    let draft = GenerationDraft(
      sourceImage: source,
      aiStickerSourceImage: generatedSource,
      stickerImage: sticker,
      cardImage: card,
      bloomNumber: 7,
      processingMilliseconds: 800,
      foregroundCoverage: 0.5,
      inputSource: .camera,
      stickerProvenance: .aiGenerated,
      stickerExecutionMetadata: metadata
    )

    XCTAssertEqual(draft.provenance(for: .originalPhoto), .userProvided)
    XCTAssertEqual(draft.provenance(for: .sticker), .aiGenerated)
    XCTAssertEqual(draft.provenance(for: .shareCard), .aiGenerated)

    let record = OutfitRecord(
      sourceImageFilename: "source.png",
      aiStickerSourceImageFilename: "ai-source.png",
      stickerImageFilename: "sticker.png",
      cardImageFilename: "card.png",
      bloomNumber: 7,
      stickerProvenance: draft.stickerProvenance,
      stickerExecutionMetadata: draft.stickerExecutionMetadata
    )

    XCTAssertEqual(record.aiStickerSourceImageFilename, "ai-source.png")
    XCTAssertEqual(record.provenance(for: .sticker), .aiGenerated)
    XCTAssertEqual(record.provenance(for: .shareCard), .aiGenerated)
    XCTAssertEqual(record.stickerExecutionMetadata, metadata)
  }

  private func solidImage(color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2), format: format).image {
      context in
      color.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }
  }

  private func halfTransparentImage() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    return UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2), format: format).image {
      context in
      UIColor.clear.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
      UIColor.green.setFill()
      context.fill(CGRect(x: 1, y: 1, width: 1, height: 1))
    }
  }

  private func pixel(in image: UIImage, x: Int, y: Int) -> [UInt8] {
    guard let cgImage = image.cgImage else { return [] }
    var bytes = [UInt8](repeating: 0, count: 4)
    guard
      let context = CGContext(
        data: &bytes,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          | CGBitmapInfo.byteOrder32Big.rawValue
      )
    else {
      return []
    }
    context.interpolationQuality = .none
    context.translateBy(x: CGFloat(-x), y: CGFloat(y - cgImage.height + 1))
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    return bytes
  }
}

@MainActor
private final class RecordingCreativeImageGenerator: CreativeImageGenerating {
  let availability = CreativeGenerationAvailability.available
  let executionMetadata = CreativeExecutionMetadata.appleImagePlayground
  var receivedRecipe: CreativeRecipe?
  var receivedSourceImage: UIImage?

  func generate(
    sourceImage: UIImage,
    recipe: CreativeRecipe
  ) async throws -> CreativeProviderOutput {
    receivedSourceImage = sourceImage
    receivedRecipe = recipe
    return CreativeProviderOutput(
      image: sourceImage,
      executionMetadata: executionMetadata
    )
  }
}

@MainActor
private struct AIStickerSourceGeneratorStub: AIStickerSourceGenerating {
  let output: CreativeProviderOutput
  var availability: CreativeGenerationAvailability = .available

  var executionMetadata: CreativeExecutionMetadata { output.executionMetadata }

  func generateSource(from _: UIImage) async throws -> CreativeProviderOutput {
    output
  }
}
