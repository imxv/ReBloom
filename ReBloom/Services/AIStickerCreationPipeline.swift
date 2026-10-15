import UIKit

@MainActor
protocol AIStickerSourceGenerating {
  var availability: CreativeGenerationAvailability { get }
  var executionMetadata: CreativeExecutionMetadata { get }

  func generateSource(from sourceImage: UIImage) async throws -> CreativeProviderOutput
}

@MainActor
struct CreativeAIStickerSourceGenerator: AIStickerSourceGenerating {
  let generator: any CreativeImageGenerating

  var availability: CreativeGenerationAvailability { generator.availability }
  var executionMetadata: CreativeExecutionMetadata { generator.executionMetadata }

  func generateSource(from sourceImage: UIImage) async throws -> CreativeProviderOutput {
    try await generator.generate(sourceImage: sourceImage, recipe: .aiStickerSource)
  }
}

struct AIStickerCreationResult {
  let generatedSourceImage: UIImage
  let stickerProcessingResult: StickerProcessingResult
  let executionMetadata: CreativeExecutionMetadata
}

@MainActor
struct AIStickerCreationPipeline {
  typealias StickerExtractor = @MainActor (UIImage) async throws -> StickerProcessingResult
  typealias GeneratedSourceObserver =
    @MainActor (
      UIImage,
      CreativeExecutionMetadata
    ) -> Void

  private let sourceGenerator: any AIStickerSourceGenerating
  private let extractSticker: StickerExtractor
  private let extractionExecutionMetadata: CreativeExecutionMetadata?

  init(
    sourceGenerator: any AIStickerSourceGenerating,
    extractSticker: @escaping StickerExtractor,
    extractionExecutionMetadata: CreativeExecutionMetadata? = nil
  ) {
    self.sourceGenerator = sourceGenerator
    self.extractSticker = extractSticker
    self.extractionExecutionMetadata = extractionExecutionMetadata
  }

  func createSticker(
    from sourceImage: UIImage,
    onGeneratedSource: GeneratedSourceObserver = { _, _ in }
  ) async throws -> AIStickerCreationResult {
    guard sourceGenerator.availability == .available else {
      throw CreativeGenerationError.unavailable
    }

    let providerOutput = try await sourceGenerator.generateSource(from: sourceImage)
    return try await createSticker(
      from: providerOutput,
      onGeneratedSource: onGeneratedSource
    )
  }

  func createSticker(
    from providerOutput: CreativeProviderOutput,
    onGeneratedSource: GeneratedSourceObserver = { _, _ in }
  ) async throws -> AIStickerCreationResult {
    let generatedSourceImage = try makeOpaque(providerOutput.image)
    onGeneratedSource(generatedSourceImage, providerOutput.executionMetadata)
    let sticker = try await extractSticker(generatedSourceImage)
    let executionMetadata =
      extractionExecutionMetadata.map {
        CreativeExecutionMetadata.aiStickerTwoPass(
          source: providerOutput.executionMetadata,
          extraction: $0
        )
      } ?? providerOutput.executionMetadata
    return AIStickerCreationResult(
      generatedSourceImage: generatedSourceImage,
      stickerProcessingResult: sticker,
      executionMetadata: executionMetadata
    )
  }

  private func makeOpaque(_ image: UIImage) throws -> UIImage {
    guard image.size.width.isFinite,
      image.size.height.isFinite,
      image.size.width > 0,
      image.size.height > 0
    else {
      throw CreativeGenerationError.noImage
    }

    let pixelSize: CGSize
    if let cgImage = image.cgImage {
      pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
    } else {
      pixelSize = CGSize(
        width: max(1, (image.size.width * image.scale).rounded()),
        height: max(1, (image.size.height * image.scale).rounded())
      )
    }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: pixelSize, format: format).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: pixelSize))
      image.draw(in: CGRect(origin: .zero, size: pixelSize))
    }
  }
}
