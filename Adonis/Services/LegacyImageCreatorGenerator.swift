#if canImport(ImagePlayground) && ADONIS_ENABLE_LEGACY_IMAGE_CREATOR
  import ImagePlayground
  import UIKit

  @MainActor
  struct LegacyImageCreatorGenerator {
    var availability: CreativeGenerationAvailability {
      if #available(iOS 27.0, *) {
        return .unavailable
      }
      if #available(iOS 18.4, *), ImagePlaygroundViewController.isAvailable {
        return .available
      }
      return .unavailable
    }

    func generate(
      sourceImage: UIImage,
      recipe: CreativeRecipe
    ) async throws -> CreativeProviderOutput {
      guard recipe.requiresSystemImageGeneration else {
        throw CreativeGenerationError.failed
      }
      guard availability == .available else {
        throw CreativeGenerationError.unavailable
      }
      if #available(iOS 18.4, *) {
        return try await generateWithImagePlayground(sourceImage: sourceImage, recipe: recipe)
      }
      throw CreativeGenerationError.unavailable
    }

    @available(iOS 18.4, *)
    private func generateWithImagePlayground(
      sourceImage: UIImage,
      recipe: CreativeRecipe
    ) async throws -> CreativeProviderOutput {
      try Task.checkCancellation()
      guard let source = preparedCGImage(from: sourceImage) else {
        throw CreativeGenerationError.unsupportedSource
      }

      do {
        let creator = try await ImageCreator()
        guard let requestedStyle = playgroundStyle(for: recipe),
          creator.availableStyles.contains(requestedStyle)
        else {
          throw CreativeGenerationError.unavailable
        }
        let concepts: [ImagePlaygroundConcept] = [
          .image(source),
          .text(recipe.systemConcept),
        ]
        for try await createdImage in creator.images(
          for: concepts,
          style: requestedStyle,
          limit: 1
        ) {
          try Task.checkCancellation()
          return CreativeProviderOutput(
            image: UIImage(cgImage: createdImage.cgImage),
            executionMetadata: .appleImagePlayground
          )
        }
        throw CreativeGenerationError.noImage
      } catch is CancellationError {
        throw CreativeGenerationError.cancelled
      } catch let error as CreativeGenerationError {
        throw error
      } catch let error as ImageCreator.Error {
        throw map(error)
      } catch {
        throw CreativeGenerationError.failed
      }
    }

    @available(iOS 18.4, *)
    private func map(_ error: ImageCreator.Error) -> CreativeGenerationError {
      switch error {
      case .notSupported, .unavailable, .backgroundCreationForbidden:
        .unavailable
      case .creationCancelled:
        .cancelled
      case .faceInImageTooSmall:
        .personTooSmall
      case .unsupportedLanguage:
        .unsupportedLanguage
      case .unsupportedInputImage:
        .unsupportedSource
      case .creationFailed:
        .failed
      case .conceptsRequirePersonIdentity:
        .unsupportedSource
      @unknown default:
        .failed
      }
    }

    @available(iOS 18.4, *)
    private func playgroundStyle(for recipe: CreativeRecipe) -> ImagePlaygroundStyle? {
      switch recipe.systemImageStyle {
      case .illustration: .illustration
      case .sketch: .sketch
      case .animation: .animation
      case nil: nil
      }
    }

    private func preparedCGImage(from image: UIImage) -> CGImage? {
      guard image.size.width.isFinite,
        image.size.height.isFinite,
        image.size.width > 0,
        image.size.height > 0
      else {
        return nil
      }

      let maximumDimension: CGFloat = 2_048
      let scale = min(1, maximumDimension / max(image.size.width, image.size.height))
      let targetSize = CGSize(
        width: max(1, (image.size.width * scale).rounded()),
        height: max(1, (image.size.height * scale).rounded())
      )
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      format.opaque = true
      return UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: targetSize))
        image.draw(in: CGRect(origin: .zero, size: targetSize))
      }.cgImage
    }
  }
#endif
