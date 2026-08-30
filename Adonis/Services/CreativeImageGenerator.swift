import Foundation
import UIKit

#if canImport(ImagePlayground)
  import ImagePlayground
#endif

enum CreativeGenerationAvailability: Equatable {
  case available
  case unavailable
}

struct CreativeProviderOutput {
  let image: UIImage
  let executionMetadata: CreativeExecutionMetadata
}

struct CreativeGenerationAttemptTimer {
  let startedAt: ContinuousClock.Instant

  func elapsedMilliseconds(at now: ContinuousClock.Instant = ContinuousClock.now) -> Int {
    let elapsed = startedAt.duration(to: now)
    return max(
      0,
      Int(elapsed.components.seconds * 1_000)
        + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
    )
  }
}

enum CreativeGenerationError: LocalizedError, Equatable {
  case unavailable
  case unsupportedSource
  case personTooSmall
  case unsupportedLanguage
  case cancelled
  case timedOut
  case noImage
  case failed

  var eventCode: String {
    switch self {
    case .unavailable: "unavailable"
    case .unsupportedSource: "unsupported_source"
    case .personTooSmall: "person_too_small"
    case .unsupportedLanguage: "unsupported_language"
    case .cancelled: "cancelled"
    case .timedOut: "timed_out"
    case .noImage: "no_image"
    case .failed: "failed"
    }
  }

  var errorDescription: String? {
    switch self {
    case .unavailable:
      "这台 iPhone 暂时没有准备好系统创作能力，可以继续使用花影海报。"
    case .unsupportedSource:
      "系统暂时读不懂这张照片，请换一张主体更清楚的照片。"
    case .personTooSmall:
      "照片里的人物有些小，请换一张人物更清楚的照片。"
    case .unsupportedLanguage:
      "系统创作暂时不支持当前语言环境，请稍后再试。"
    case .cancelled:
      "已经停止这次创作。"
    case .timedOut:
      "等了 90 秒仍没有完成，这次已经停止；原照片和贴纸没有改变。"
    case .noImage:
      "系统没有交付可用图片，请稍后再试。"
    case .failed:
      "系统这次没有完成创作，请稍后再试。"
    }
  }
}

@MainActor
protocol CreativeImageGenerating {
  var availability: CreativeGenerationAvailability { get }
  var executionMetadata: CreativeExecutionMetadata { get }

  func generate(
    sourceImage: UIImage,
    recipe: CreativeRecipe
  ) async throws -> CreativeProviderOutput
}

@MainActor
enum CreativeImageGeneratorFactory {
  static func make(arguments: [String] = ProcessInfo.processInfo.arguments)
    -> any CreativeImageGenerating
  {
    #if DEBUG
      if arguments.contains("-ui-testing-system-creative")
        || arguments.contains("-ui-testing-system-creative-unavailable")
        || arguments.contains("-ui-testing-ai-sticker-main-flow")
      {
        return UITestCreativeImageGenerator(arguments: arguments)
      }
    #endif
    return SystemCreativeImageGenerator()
  }
}

@MainActor
struct SystemCreativeImageGenerator: CreativeImageGenerating {
  let executionMetadata = CreativeExecutionMetadata.appleImagePlayground

  var availability: CreativeGenerationAvailability {
    #if canImport(ImagePlayground)
      if #available(iOS 18.4, *), ImagePlaygroundViewController.isAvailable {
        return .available
      }
    #endif
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

    #if canImport(ImagePlayground)
      if #available(iOS 18.4, *) {
        return try await generateWithImagePlayground(sourceImage: sourceImage, recipe: recipe)
      }
    #endif
    throw CreativeGenerationError.unavailable
  }

  #if canImport(ImagePlayground)
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
  #endif

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

#if DEBUG
  @MainActor
  private struct UITestCreativeImageGenerator: CreativeImageGenerating {
    let arguments: [String]

    var availability: CreativeGenerationAvailability {
      arguments.contains("-ui-testing-system-creative-unavailable") ? .unavailable : .available
    }
    let executionMetadata = CreativeExecutionMetadata.uiTestFixture

    func generate(
      sourceImage _: UIImage,
      recipe: CreativeRecipe
    ) async throws -> CreativeProviderOutput {
      if arguments.contains("-ui-testing-system-creative-never-finishes") {
        try await Task.sleep(for: .seconds(120))
      } else {
        try await Task.sleep(for: .seconds(3))
      }
      try Task.checkCancellation()

      if arguments.contains("-ui-testing-ai-sticker-main-flow"),
        recipe == .aiStickerSource,
        let fixture = aiStickerSourceFixture()
      {
        return CreativeProviderOutput(image: fixture, executionMetadata: .uiTestFixture)
      }

      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      format.opaque = true
      let image = UIGraphicsImageRenderer(
        size: CGSize(width: 1_024, height: 1_024),
        format: format
      ).image { context in
        let palette = palette(for: recipe)
        palette.background.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1_024, height: 1_024))
        palette.sun.setFill()
        context.cgContext.fillEllipse(in: CGRect(x: 544, y: 112, width: 390, height: 390))
        palette.figure.setFill()
        UIBezierPath(
          roundedRect: CGRect(x: 180, y: 168, width: 460, height: 742),
          cornerRadius: 220
        ).fill()
        palette.line.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 130, y: 860))
        path.addCurve(
          to: CGPoint(x: 890, y: 590),
          controlPoint1: CGPoint(x: 420, y: 690),
          controlPoint2: CGPoint(x: 650, y: 900)
        )
        path.lineWidth = 32
        path.stroke()
      }
      return CreativeProviderOutput(image: image, executionMetadata: .uiTestFixture)
    }

    private func aiStickerSourceFixture() -> UIImage? {
      guard let sticker = SampleCatalog.showcasePhotos.first?.preparedStickerImage() else {
        return nil
      }
      let canvasSize = CGSize(width: 1_080, height: 1_440)
      let inset = CGRect(x: 90, y: 54, width: 900, height: 1_332)
      let scale = min(
        inset.width / sticker.size.width,
        inset.height / sticker.size.height
      )
      let stickerSize = CGSize(
        width: sticker.size.width * scale,
        height: sticker.size.height * scale
      )
      let stickerFrame = CGRect(
        x: inset.midX - stickerSize.width / 2,
        y: inset.midY - stickerSize.height / 2,
        width: stickerSize.width,
        height: stickerSize.height
      )
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      format.opaque = true
      return UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
        UIColor(red: 0.965, green: 0.949, blue: 0.925, alpha: 1).setFill()
        context.fill(CGRect(origin: .zero, size: canvasSize))
        sticker.draw(in: stickerFrame)
      }
    }

    private func palette(for recipe: CreativeRecipe) -> (
      background: UIColor, sun: UIColor, figure: UIColor, line: UIColor
    ) {
      switch recipe {
      case .aiStickerSource:
        (
          UIColor(red: 0.98, green: 0.97, blue: 0.93, alpha: 1),
          UIColor(red: 0.91, green: 0.34, blue: 0.42, alpha: 1),
          UIColor(red: 0.22, green: 0.18, blue: 0.20, alpha: 1),
          UIColor(red: 0.53, green: 0.70, blue: 0.47, alpha: 1)
        )
      case .floralSketch:
        (
          UIColor(red: 0.94, green: 0.88, blue: 0.76, alpha: 1),
          UIColor(red: 0.82, green: 0.22, blue: 0.22, alpha: 1),
          UIColor(red: 0.20, green: 0.17, blue: 0.14, alpha: 1),
          UIColor(red: 0.36, green: 0.51, blue: 0.31, alpha: 1)
        )
      case .moonlitTheater:
        (
          UIColor(red: 0.035, green: 0.08, blue: 0.25, alpha: 1),
          UIColor(red: 1, green: 0.37, blue: 0.43, alpha: 1),
          UIColor(red: 0.30, green: 0.68, blue: 0.82, alpha: 1),
          UIColor(red: 1, green: 0.84, blue: 0.46, alpha: 1)
        )
      case .mythicGarden, .botanicalPoster, .stickerTryOn:
        (
          UIColor(red: 0.18, green: 0.09, blue: 0.16, alpha: 1),
          UIColor(red: 0.91, green: 0.34, blue: 0.42, alpha: 1),
          UIColor(red: 0.53, green: 0.70, blue: 0.47, alpha: 1),
          UIColor(red: 1, green: 0.89, blue: 0.62, alpha: 1)
        )
      }
    }
  }
#endif
