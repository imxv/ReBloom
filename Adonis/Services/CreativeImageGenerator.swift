import Foundation
import UIKit

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
      "当前设备或系统设置暂时无法使用系统图片生成。"
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

  #if canImport(ImagePlayground) && ADONIS_ENABLE_LEGACY_IMAGE_CREATOR
    private let legacyGenerator = LegacyImageCreatorGenerator()
  #endif

  var availability: CreativeGenerationAvailability {
    #if canImport(ImagePlayground) && ADONIS_ENABLE_LEGACY_IMAGE_CREATOR
      legacyGenerator.availability
    #else
      .unavailable
    #endif
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

    #if canImport(ImagePlayground) && ADONIS_ENABLE_LEGACY_IMAGE_CREATOR
      return try await legacyGenerator.generate(sourceImage: sourceImage, recipe: recipe)
    #else
      throw CreativeGenerationError.unavailable
    #endif
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
      guard let source = SampleCatalog.homepagePhotos.first?.homepageAISourceImage() else {
        return nil
      }
      return source
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
