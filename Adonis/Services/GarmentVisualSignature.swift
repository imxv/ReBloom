import Foundation
import UIKit

struct GarmentVisualSimilarity: Equatable, Sendable {
  let overall: Double
  let color: Double
  let luminance: Double
  let texture: Double
}

struct GarmentVisualSignature: Codable, Equatable, Sendable {
  static let currentVersion = "garment-visual-signature-v1"

  let version: String
  let colorHistogram: [Double]
  let luminanceHistogram: [Double]
  let textureHistogram: [Double]
  let edgeDensity: Double
  let sampleCount: Int

  init(
    version: String = Self.currentVersion,
    colorHistogram: [Double],
    luminanceHistogram: [Double],
    textureHistogram: [Double],
    edgeDensity: Double,
    sampleCount: Int
  ) {
    self.version = version
    self.colorHistogram = Self.normalized(colorHistogram)
    self.luminanceHistogram = Self.normalized(luminanceHistogram)
    self.textureHistogram = Self.normalized(textureHistogram)
    self.edgeDensity = min(1, max(0, edgeDensity))
    self.sampleCount = max(0, sampleCount)
  }

  init?(encoded: String) {
    guard let data = Data(base64Encoded: encoded),
      let decoded = try? JSONDecoder().decode(Self.self, from: data),
      decoded.version == Self.currentVersion,
      !decoded.colorHistogram.isEmpty,
      !decoded.luminanceHistogram.isEmpty,
      !decoded.textureHistogram.isEmpty,
      decoded.sampleCount > 0
    else {
      return nil
    }
    self = decoded
  }

  func encoded() throws -> String {
    try JSONEncoder().encode(self).base64EncodedString()
  }

  func similarity(to other: Self) -> GarmentVisualSimilarity {
    guard version == other.version else {
      return GarmentVisualSimilarity(overall: 0, color: 0, luminance: 0, texture: 0)
    }

    let color = Self.histogramIntersection(colorHistogram, other.colorHistogram)
    let luminance = Self.histogramIntersection(
      luminanceHistogram,
      other.luminanceHistogram
    )
    let textureShape = Self.histogramIntersection(
      textureHistogram,
      other.textureHistogram
    )
    let edge = max(0, 1 - abs(edgeDensity - other.edgeDensity) / 0.45)
    let texture = textureShape * 0.72 + edge * 0.28
    let overall = color * 0.55 + luminance * 0.18 + texture * 0.27
    return GarmentVisualSimilarity(
      overall: min(1, max(0, overall)),
      color: color,
      luminance: luminance,
      texture: texture
    )
  }

  private static func normalized(_ values: [Double]) -> [Double] {
    let sanitized = values.map { value in
      value.isFinite ? max(0, value) : 0
    }
    let total = sanitized.reduce(0, +)
    guard total > 0 else { return sanitized }
    return sanitized.map { $0 / total }
  }

  private static func histogramIntersection(_ lhs: [Double], _ rhs: [Double]) -> Double {
    guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
    let left = normalized(lhs)
    let right = normalized(rhs)
    let leftTotal = left.reduce(0, +)
    let rightTotal = right.reduce(0, +)
    if leftTotal == 0, rightTotal == 0 { return 1 }
    guard leftTotal > 0, rightTotal > 0 else { return 0 }
    return zip(left, right).reduce(0) { $0 + min($1.0, $1.1) }
  }
}

enum GarmentVisualSignatureError: LocalizedError, Equatable {
  case unreadableImage
  case insufficientForeground

  var errorDescription: String? {
    switch self {
    case .unreadableImage:
      "图片无法读取。"
    case .insufficientForeground:
      "画面里的衣物线索太少，暂时不生成视觉指纹。"
    }
  }
}

struct GarmentVisualSignatureAnalyzer {
  private static let sampleSize = 64
  private static let minimumForegroundPixelCount = 96

  func signature(data: Data) async throws -> GarmentVisualSignature {
    try await Task.detached(priority: .utility) {
      guard let image = UIImage(data: data) else {
        throw GarmentVisualSignatureError.unreadableImage
      }
      return try Self().signature(for: image)
    }.value
  }

  func signature(for image: UIImage) throws -> GarmentVisualSignature {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    let rendered = UIGraphicsImageRenderer(
      size: CGSize(width: Self.sampleSize, height: Self.sampleSize),
      format: format
    ).image { _ in
      image.draw(in: CGRect(x: 0, y: 0, width: Self.sampleSize, height: Self.sampleSize))
    }
    guard let cgImage = rendered.cgImage else {
      throw GarmentVisualSignatureError.unreadableImage
    }
    return try signature(for: cgImage)
  }

  func signature(for image: CGImage) throws -> GarmentVisualSignature {
    let sample = try PixelSample(image: image, size: Self.sampleSize)
    let mask = foregroundMask(for: sample)
    let foregroundCount = mask.reduce(0) { $0 + ($1 ? 1 : 0) }
    guard foregroundCount >= Self.minimumForegroundPixelCount else {
      throw GarmentVisualSignatureError.insufficientForeground
    }

    var colorHistogram = [Double](repeating: 0, count: 18)
    var luminanceHistogram = [Double](repeating: 0, count: 8)
    var textureHistogram = [Double](repeating: 0, count: 8)

    for index in mask.indices where mask[index] {
      let pixel = sample.pixels[index]
      let hsv = Self.hsv(pixel)
      if hsv.saturation < 0.18 {
        let neutralIndex = min(5, Int(hsv.brightness * 6))
        colorHistogram[12 + neutralIndex] += 1
      } else {
        let hueIndex = min(11, Int(hsv.hue * 12))
        colorHistogram[hueIndex] += 1
      }
      let luminanceIndex = min(7, Int(Self.luminance(pixel) * 8))
      luminanceHistogram[luminanceIndex] += 1
    }

    var eligibleTexturePixels = 0
    var edgePixels = 0
    for y in 1..<(sample.height - 1) {
      for x in 1..<(sample.width - 1) {
        let index = sample.index(x: x, y: y)
        guard mask[index],
          mask[sample.index(x: x - 1, y: y)],
          mask[sample.index(x: x + 1, y: y)],
          mask[sample.index(x: x, y: y - 1)],
          mask[sample.index(x: x, y: y + 1)]
        else {
          continue
        }

        eligibleTexturePixels += 1
        let left = Self.luminance(sample.pixel(x: x - 1, y: y))
        let right = Self.luminance(sample.pixel(x: x + 1, y: y))
        let above = Self.luminance(sample.pixel(x: x, y: y - 1))
        let below = Self.luminance(sample.pixel(x: x, y: y + 1))
        let horizontal = right - left
        let vertical = below - above
        let magnitude = sqrt(horizontal * horizontal + vertical * vertical)
        guard magnitude >= 0.045 else { continue }
        if magnitude >= 0.1 { edgePixels += 1 }

        var angle = atan2(vertical, horizontal)
        if angle < 0 { angle += .pi }
        if angle >= .pi { angle -= .pi }
        let orientation = min(7, Int(angle / .pi * 8))
        textureHistogram[orientation] += magnitude
      }
    }

    let edgeDensity = Double(edgePixels) / Double(max(eligibleTexturePixels, 1))
    return GarmentVisualSignature(
      colorHistogram: colorHistogram,
      luminanceHistogram: luminanceHistogram,
      textureHistogram: textureHistogram,
      edgeDensity: edgeDensity,
      sampleCount: foregroundCount
    )
  }

  private func foregroundMask(for sample: PixelSample) -> [Bool] {
    var visible = sample.pixels.map { $0.alpha > 32 }
    let borderIndices = sample.borderIndices
    let visibleBorder = borderIndices.filter { visible[$0] }
    let nearWhiteBorder = visibleBorder.filter { Self.isNearWhite(sample.pixels[$0]) }
    let hasWhiteBackground =
      Double(nearWhiteBorder.count) / Double(max(visibleBorder.count, 1)) >= 0.58

    if hasWhiteBackground {
      var queue = nearWhiteBorder
      var cursor = 0
      var background = Set(queue)
      while cursor < queue.count {
        let index = queue[cursor]
        cursor += 1
        for neighbor in sample.neighbors(of: index) {
          guard visible[neighbor],
            !background.contains(neighbor),
            Self.isNearWhite(sample.pixels[neighbor])
          else {
            continue
          }
          background.insert(neighbor)
          queue.append(neighbor)
        }
      }
      for index in background {
        visible[index] = false
      }
    }

    return visible
  }

  private static func hsv(_ pixel: SignaturePixel) -> (
    hue: Double, saturation: Double, brightness: Double
  ) {
    let red = Double(pixel.red) / 255
    let green = Double(pixel.green) / 255
    let blue = Double(pixel.blue) / 255
    let maximum = max(red, green, blue)
    let minimum = min(red, green, blue)
    let delta = maximum - minimum
    let saturation = maximum == 0 ? 0 : delta / maximum
    guard delta > 0 else { return (0, saturation, maximum) }

    let rawHue: Double
    if maximum == red {
      rawHue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
    } else if maximum == green {
      rawHue = (blue - red) / delta + 2
    } else {
      rawHue = (red - green) / delta + 4
    }
    let hue = (rawHue / 6 + 1).truncatingRemainder(dividingBy: 1)
    return (hue, saturation, maximum)
  }

  private static func luminance(_ pixel: SignaturePixel) -> Double {
    (0.2126 * Double(pixel.red) + 0.7152 * Double(pixel.green)
      + 0.0722 * Double(pixel.blue)) / 255
  }

  private static func isNearWhite(_ pixel: SignaturePixel) -> Bool {
    let values = [Int(pixel.red), Int(pixel.green), Int(pixel.blue)]
    return values.min() ?? 0 >= 232
      && (values.max() ?? 0) - (values.min() ?? 0) <= 20
  }

}

private struct SignaturePixel {
  let red: UInt8
  let green: UInt8
  let blue: UInt8
  let alpha: UInt8
}

private struct PixelSample {
  let width: Int
  let height: Int
  let pixels: [SignaturePixel]

  init(image: CGImage, size: Int) throws {
    let bytesPerPixel = 4
    let bytesPerRow = size * bytesPerPixel
    var bytes = [UInt8](repeating: 0, count: size * bytesPerRow)
    guard
      let context = CGContext(
        data: &bytes,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          | CGBitmapInfo.byteOrder32Big.rawValue
      )
    else {
      throw GarmentVisualSignatureError.unreadableImage
    }
    context.interpolationQuality = .medium
    context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))

    width = size
    height = size
    pixels = stride(from: 0, to: bytes.count, by: bytesPerPixel).map { offset in
      SignaturePixel(
        red: bytes[offset],
        green: bytes[offset + 1],
        blue: bytes[offset + 2],
        alpha: bytes[offset + 3]
      )
    }
  }

  var borderIndices: [Int] {
    var indices: [Int] = []
    indices.reserveCapacity(width * 2 + height * 2)
    for x in 0..<width {
      indices.append(index(x: x, y: 0))
      indices.append(index(x: x, y: height - 1))
    }
    for y in 1..<(height - 1) {
      indices.append(index(x: 0, y: y))
      indices.append(index(x: width - 1, y: y))
    }
    return indices
  }

  func pixel(x: Int, y: Int) -> SignaturePixel {
    pixels[index(x: x, y: y)]
  }

  func index(x: Int, y: Int) -> Int {
    y * width + x
  }

  func neighbors(of index: Int) -> [Int] {
    let x = index % width
    let y = index / width
    var result: [Int] = []
    if x > 0 { result.append(self.index(x: x - 1, y: y)) }
    if x + 1 < width { result.append(self.index(x: x + 1, y: y)) }
    if y > 0 { result.append(self.index(x: x, y: y - 1)) }
    if y + 1 < height { result.append(self.index(x: x, y: y + 1)) }
    return result
  }
}
