import CoreImage
import CryptoKit
import Foundation
import UIKit
import Vision

struct WardrobeImageAnalysis: Equatable, Sendable {
  let sourceKind: WardrobeSourceKind
  let dominantColorName: String?
  let dominantColorHex: String?
  let suggestedCategory: WardrobeCategory?
  let categoryConfidence: Double?
  let cleanBackgroundScore: Double
  let imageWidth: Int
  let imageHeight: Int
  let imageFingerprint: String
  let visualSignatureRawValue: String?
  let processingMilliseconds: Int
  let analysisVersion: String

  var automaticallyAssignedCategory: WardrobeCategory {
    guard let suggestedCategory, (categoryConfidence ?? 0) >= 0.62 else {
      return .uncategorized
    }
    return suggestedCategory
  }

  var suggestedName: String {
    WardrobeItemNaming.generatedName(
      colorName: dominantColorName,
      category: automaticallyAssignedCategory
    )
  }
}

struct WardrobeCategorySuggestion: Equatable, Sendable {
  let category: WardrobeCategory
  let confidence: Double
}

struct WardrobeImageAnalyzer {
  static let version = AdonisProcessingVersion.wardrobeAnalysis

  private static let context = CIContext(options: [
    .cacheIntermediates: false
  ])

  func analyze(data: Data) async throws -> WardrobeImageAnalysis {
    try await Task.detached(priority: .userInitiated) {
      try Self.analyzeSynchronously(data: data)
    }.value
  }

  static func categorySuggestion(
    for labels: [(identifier: String, confidence: Float)]
  ) -> WardrobeCategorySuggestion? {
    let mappings: [(category: WardrobeCategory, keywords: [String])] = [
      (.dress, ["dress", "gown", "frock"]),
      (.outerwear, ["coat", "jacket", "parka", "cardigan", "blazer", "poncho"]),
      (.bottom, ["skirt", "jean", "trouser", "pants", "shorts", "culottes"]),
      (.top, ["shirt", "t-shirt", "tee shirt", "sweater", "jersey", "blouse", "hoodie"]),
      (.shoes, ["shoe", "sneaker", "loafer", "sandal", "boot", "slipper"]),
      (.bag, ["handbag", "purse", "backpack", "tote bag", "shoulder bag"]),
      (.accessory, ["sunglasses", "hat", "cap", "scarf", "tie", "belt", "necklace"]),
    ]

    var best: WardrobeCategorySuggestion?
    for label in labels {
      let identifier = label.identifier.lowercased()
      guard
        let category = mappings.first(where: { mapping in
          mapping.keywords.contains(where: identifier.contains)
        })?.category
      else {
        continue
      }

      let candidate = WardrobeCategorySuggestion(
        category: category,
        confidence: Double(label.confidence)
      )
      if candidate.confidence > (best?.confidence ?? 0) {
        best = candidate
      }
    }
    return best
  }

  private static func analyzeSynchronously(data: Data) throws -> WardrobeImageAnalysis {
    let start = ContinuousClock.now
    guard
      let source = CIImage(
        data: data,
        options: [.applyOrientationProperty: true]
      )
    else {
      throw WardrobeImageAnalysisError.unreadableImage
    }

    let extent = source.extent.integral
    guard extent.width >= 64, extent.height >= 64 else {
      throw WardrobeImageAnalysisError.imageTooSmall
    }
    guard
      let image = context.createCGImage(
        source,
        from: extent,
        format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
      )
    else {
      throw WardrobeImageAnalysisError.unreadableImage
    }

    let pixels = try samplePixels(from: image)
    let background = backgroundFacts(from: pixels)
    let color = dominantColor(
      from: pixels,
      excludingWhiteBackground: background.sourceKind == .catalogImage
    )
    let category = bestEffortCategory(for: image)
    let visualSignatureRawValue = try? GarmentVisualSignatureAnalyzer()
      .signature(for: image)
      .encoded()
    let elapsed = start.duration(to: .now)
    let milliseconds =
      Int(elapsed.components.seconds * 1_000)
      + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)

    return WardrobeImageAnalysis(
      sourceKind: background.sourceKind,
      dominantColorName: color?.name,
      dominantColorHex: color?.hex,
      suggestedCategory: category?.category,
      categoryConfidence: category?.confidence,
      cleanBackgroundScore: background.cleanBackgroundScore,
      imageWidth: image.width,
      imageHeight: image.height,
      imageFingerprint: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
      visualSignatureRawValue: visualSignatureRawValue,
      processingMilliseconds: milliseconds,
      analysisVersion: version
    )
  }

  private static func bestEffortCategory(for image: CGImage) -> WardrobeCategorySuggestion? {
    #if targetEnvironment(simulator)
      // The current iOS simulator cannot create a Vision inference context.
      // Pixel-based source and color analysis still runs; category remains optional.
      return nil
    #else
      do {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        try handler.perform([request])
        let labels = (request.results ?? []).prefix(12).map {
          (identifier: $0.identifier, confidence: $0.confidence)
        }
        return categorySuggestion(for: labels)
      } catch {
        return nil
      }
    #endif
  }

  private static func samplePixels(from image: CGImage) throws -> PixelSample {
    let width = 64
    let height = 64
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)

    guard
      let context = CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          | CGBitmapInfo.byteOrder32Big.rawValue
      )
    else {
      throw WardrobeImageAnalysisError.unreadableImage
    }
    context.interpolationQuality = .medium
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    return PixelSample(width: width, height: height, bytes: bytes)
  }

  private static func backgroundFacts(from sample: PixelSample) -> (
    sourceKind: WardrobeSourceKind, cleanBackgroundScore: Double
  ) {
    var visible = 0
    var white = 0
    var borderVisible = 0
    var borderWhite = 0
    let borderInset = 7

    sample.forEachPixel { x, y, red, green, blue, alpha in
      guard alpha > 16 else { return }
      visible += 1
      let isWhite = isNearWhite(red: red, green: green, blue: blue)
      if isWhite { white += 1 }

      let isBorder =
        x < borderInset || x >= sample.width - borderInset
        || y < borderInset || y >= sample.height - borderInset
      if isBorder {
        borderVisible += 1
        if isWhite { borderWhite += 1 }
      }
    }

    let overallWhiteRatio = Double(white) / Double(max(visible, 1))
    let borderWhiteRatio = Double(borderWhite) / Double(max(borderVisible, 1))
    let score = min(1, borderWhiteRatio * 0.72 + overallWhiteRatio * 0.28)
    let sourceKind: WardrobeSourceKind =
      borderWhiteRatio >= 0.62 && overallWhiteRatio >= 0.24
      ? .catalogImage
      : .flatLay
    return (sourceKind, score)
  }

  private static func dominantColor(
    from sample: PixelSample,
    excludingWhiteBackground: Bool
  ) -> (name: String, hex: String)? {
    struct Bucket {
      var count = 0
      var red = 0
      var green = 0
      var blue = 0
    }

    var buckets: [Int: Bucket] = [:]
    let centerInset = 6
    sample.forEachPixel { x, y, red, green, blue, alpha in
      guard alpha > 32 else { return }
      if excludingWhiteBackground && isNearWhite(red: red, green: green, blue: blue) {
        return
      }
      if !excludingWhiteBackground {
        guard
          x >= centerInset, x < sample.width - centerInset,
          y >= centerInset, y < sample.height - centerInset
        else {
          return
        }
      }

      let key = (Int(red) / 32) << 6 | (Int(green) / 32) << 3 | Int(blue) / 32
      var bucket = buckets[key] ?? Bucket()
      bucket.count += 1
      bucket.red += Int(red)
      bucket.green += Int(green)
      bucket.blue += Int(blue)
      buckets[key] = bucket
    }

    guard let bucket = buckets.values.max(by: { $0.count < $1.count }), bucket.count >= 8 else {
      return nil
    }
    let red = bucket.red / bucket.count
    let green = bucket.green / bucket.count
    let blue = bucket.blue / bucket.count
    return (
      colorName(red: red, green: green, blue: blue),
      String(format: "#%02X%02X%02X", red, green, blue)
    )
  }

  private static func isNearWhite(red: UInt8, green: UInt8, blue: UInt8) -> Bool {
    let values = [Int(red), Int(green), Int(blue)]
    return values.min() ?? 0 >= 232 && (values.max() ?? 0) - (values.min() ?? 0) <= 18
  }

  static func colorName(red: Int, green: Int, blue: Int) -> String {
    let color = UIColor(
      red: CGFloat(red) / 255,
      green: CGFloat(green) / 255,
      blue: CGFloat(blue) / 255,
      alpha: 1
    )
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

    if brightness < 0.16 { return "黑色" }
    if saturation < 0.12 {
      if brightness > 0.88 { return "白色" }
      if brightness > 0.64 { return "浅灰色" }
      if brightness > 0.3 { return "灰色" }
      return "黑色"
    }
    if saturation < 0.28, hue >= 0.04, hue <= 0.17 {
      return brightness > 0.72 ? "米色" : "棕色"
    }

    switch hue {
    case 0..<0.04, 0.96...1:
      return brightness > 0.72 && saturation < 0.45 ? "粉色" : "红色"
    case 0.04..<0.12:
      return brightness < 0.63 ? "棕色" : "橙色"
    case 0.12..<0.2:
      return brightness < 0.55 ? "橄榄色" : "黄色"
    case 0.2..<0.46:
      return "绿色"
    case 0.46..<0.56:
      return "青色"
    case 0.56..<0.72:
      return "蓝色"
    case 0.72..<0.86:
      return "紫色"
    default:
      return "粉色"
    }
  }
}

private struct PixelSample {
  let width: Int
  let height: Int
  let bytes: [UInt8]

  func forEachPixel(
    _ body: (_ x: Int, _ y: Int, _ red: UInt8, _ green: UInt8, _ blue: UInt8, _ alpha: UInt8) ->
      Void
  ) {
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    for y in 0..<height {
      for x in 0..<width {
        let offset = y * bytesPerRow + x * bytesPerPixel
        body(x, y, bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
      }
    }
  }
}

enum WardrobeImageAnalysisError: LocalizedError {
  case unreadableImage
  case imageTooSmall

  var errorDescription: String? {
    switch self {
    case .unreadableImage:
      "这张衣服图片暂时无法读取，请换一张试试。"
    case .imageTooSmall:
      "这张衣服图片太小了，换一张更清楚的图片吧。"
    }
  }
}
