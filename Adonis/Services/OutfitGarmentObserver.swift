import CoreImage
import Foundation
import UIKit

struct GarmentObservationDraft: Identifiable {
  let id: UUID
  let slot: GarmentObservationSlot
  let suggestedCategory: WardrobeCategory
  let dominantColorName: String?
  let dominantColorHex: String?
  let confidence: Double
  let previewImage: UIImage
  let visualSignatureRawValue: String?
  let observerVersion: String

  init(
    id: UUID = UUID(),
    slot: GarmentObservationSlot,
    suggestedCategory: WardrobeCategory? = nil,
    dominantColorName: String?,
    dominantColorHex: String?,
    confidence: Double,
    previewImage: UIImage,
    visualSignatureRawValue: String? = nil,
    observerVersion: String = AdonisProcessingVersion.outfitObservation
  ) {
    self.id = id
    self.slot = slot
    self.suggestedCategory = suggestedCategory ?? slot.suggestedCategory
    self.dominantColorName = dominantColorName
    self.dominantColorHex = dominantColorHex
    self.confidence = confidence
    self.previewImage = previewImage
    self.visualSignatureRawValue = visualSignatureRawValue
    self.observerVersion = observerVersion
  }
}

struct OutfitGarmentObserver {
  static let version = AdonisProcessingVersion.outfitObservation

  private static let context = CIContext(options: [
    .cacheIntermediates: false
  ])
  private static let sampleWidth = 120

  func observe(sticker: UIImage) async -> [GarmentObservationDraft] {
    guard let data = sticker.pngData() else { return [] }
    return await Task.detached(priority: .userInitiated) {
      (try? Self.observeSynchronously(data: data)) ?? []
    }.value
  }

  private static func observeSynchronously(data: Data) throws -> [GarmentObservationDraft] {
    guard
      let source = CIImage(
        data: data,
        options: [.applyOrientationProperty: true]
      )
    else {
      return []
    }
    let extent = source.extent.integral
    guard extent.width >= 64, extent.height >= 64,
      let original = context.createCGImage(
        source,
        from: extent,
        format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
      )
    else {
      return []
    }

    let sampleHeight = max(
      96,
      Int((CGFloat(sampleWidth) * CGFloat(original.height) / CGFloat(original.width)).rounded())
    )
    guard let sample = makeSample(from: original, width: sampleWidth, height: sampleHeight),
      let foregroundBounds = sample.alphaBounds(threshold: 36),
      foregroundBounds.width >= 24,
      foregroundBounds.height >= 48
    else {
      return []
    }

    let regions: [(slot: GarmentObservationSlot, start: Double, end: Double)] = [
      (.upperBody, 0.22, 0.55),
      (.lowerBody, 0.51, 0.84),
    ]

    return regions.compactMap { region in
      let zone = CGRect(
        x: foregroundBounds.minX + foregroundBounds.width * 0.18,
        y: foregroundBounds.minY + foregroundBounds.height * region.start,
        width: foregroundBounds.width * 0.64,
        height: foregroundBounds.height * (region.end - region.start)
      ).integral

      guard let facts = facts(in: zone, sample: sample), facts.confidence >= 0.28 else {
        return nil
      }

      let previewZone = CGRect(
        x: foregroundBounds.minX + foregroundBounds.width * 0.08,
        y: foregroundBounds.minY + foregroundBounds.height * max(0, region.start - 0.04),
        width: foregroundBounds.width * 0.84,
        height: foregroundBounds.height * min(1, region.end - region.start + 0.08)
      ).integral
      guard let preview = crop(original: original, sample: sample, rect: previewZone) else {
        return nil
      }

      return GarmentObservationDraft(
        slot: region.slot,
        dominantColorName: facts.colorName,
        dominantColorHex: facts.colorHex,
        confidence: facts.confidence,
        previewImage: preview,
        visualSignatureRawValue: try? GarmentVisualSignatureAnalyzer()
          .signature(for: preview)
          .encoded()
      )
    }
  }

  private static func makeSample(from image: CGImage, width: Int, height: Int) -> PixelBuffer? {
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
      return nil
    }
    context.interpolationQuality = .medium
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return PixelBuffer(width: width, height: height, bytes: bytes)
  }

  private static func facts(in rect: CGRect, sample: PixelBuffer) -> RegionFacts? {
    struct Bucket {
      var count = 0
      var red = 0
      var green = 0
      var blue = 0
    }

    let bounds = rect.intersection(CGRect(x: 0, y: 0, width: sample.width, height: sample.height))
    guard !bounds.isNull, bounds.width >= 4, bounds.height >= 4 else { return nil }

    var buckets: [Int: Bucket] = [:]
    var considered = 0
    var visible = 0
    let minX = max(0, Int(bounds.minX))
    let maxX = min(sample.width, Int(bounds.maxX))
    let minY = max(0, Int(bounds.minY))
    let maxY = min(sample.height, Int(bounds.maxY))

    for y in minY..<maxY {
      for x in minX..<maxX {
        let pixel = sample.pixel(x: x, y: y)
        guard pixel.alpha > 48 else { continue }
        visible += 1
        if isStickerEdgeWhite(pixel, x: x, y: y, sample: sample) { continue }
        if isLikelySkin(pixel) { continue }

        considered += 1
        let key =
          (Int(pixel.red) / 32) << 6 | (Int(pixel.green) / 32) << 3
          | Int(pixel.blue) / 32
        var bucket = buckets[key] ?? Bucket()
        bucket.count += 1
        bucket.red += Int(pixel.red)
        bucket.green += Int(pixel.green)
        bucket.blue += Int(pixel.blue)
        buckets[key] = bucket
      }
    }

    let area = max(1, (maxX - minX) * (maxY - minY))
    guard considered >= max(18, Int(Double(area) * 0.035)),
      let bucket = buckets.values.max(by: { $0.count < $1.count })
    else {
      return nil
    }

    let red = bucket.red / bucket.count
    let green = bucket.green / bucket.count
    let blue = bucket.blue / bucket.count
    let coverage = Double(visible) / Double(area)
    let dominantShare = Double(bucket.count) / Double(max(considered, 1))
    let confidence = min(0.78, 0.22 + coverage * 0.24 + dominantShare * 0.5)
    return RegionFacts(
      colorName: WardrobeImageAnalyzer.colorName(red: red, green: green, blue: blue),
      colorHex: String(format: "#%02X%02X%02X", red, green, blue),
      confidence: confidence
    )
  }

  private static func isStickerEdgeWhite(
    _ pixel: Pixel,
    x: Int,
    y: Int,
    sample: PixelBuffer
  ) -> Bool {
    let values = [Int(pixel.red), Int(pixel.green), Int(pixel.blue)]
    guard values.min() ?? 0 >= 238, (values.max() ?? 0) - (values.min() ?? 0) <= 12 else {
      return false
    }

    for offsetY in -2...2 {
      for offsetX in -2...2 {
        let neighborX = x + offsetX
        let neighborY = y + offsetY
        guard neighborX >= 0, neighborX < sample.width,
          neighborY >= 0, neighborY < sample.height
        else {
          return true
        }
        if sample.pixel(x: neighborX, y: neighborY).alpha < 24 {
          return true
        }
      }
    }
    return false
  }

  private static func isLikelySkin(_ pixel: Pixel) -> Bool {
    let red = Int(pixel.red)
    let green = Int(pixel.green)
    let blue = Int(pixel.blue)
    return red > 140
      && green > 70
      && blue > 45
      && red > green + 14
      && red > blue + 20
      && max(red, green, blue) - min(red, green, blue) > 18
  }

  private static func crop(original: CGImage, sample: PixelBuffer, rect: CGRect) -> UIImage? {
    let scaleX = CGFloat(original.width) / CGFloat(sample.width)
    let scaleY = CGFloat(original.height) / CGFloat(sample.height)
    let scaled = CGRect(
      x: max(0, rect.minX * scaleX),
      y: max(0, rect.minY * scaleY),
      width: min(CGFloat(original.width), rect.width * scaleX),
      height: min(CGFloat(original.height), rect.height * scaleY)
    ).integral.intersection(
      CGRect(x: 0, y: 0, width: original.width, height: original.height)
    )
    guard !scaled.isNull, scaled.width >= 8, scaled.height >= 8,
      let cropped = original.cropping(to: scaled)
    else {
      return nil
    }
    return UIImage(cgImage: cropped)
  }
}

private struct RegionFacts {
  let colorName: String
  let colorHex: String
  let confidence: Double
}

private struct Pixel {
  let red: UInt8
  let green: UInt8
  let blue: UInt8
  let alpha: UInt8
}

private struct PixelBuffer {
  let width: Int
  let height: Int
  let bytes: [UInt8]

  func pixel(x: Int, y: Int) -> Pixel {
    let offset = (y * width + x) * 4
    return Pixel(
      red: bytes[offset],
      green: bytes[offset + 1],
      blue: bytes[offset + 2],
      alpha: bytes[offset + 3]
    )
  }

  func alphaBounds(threshold: UInt8) -> CGRect? {
    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1
    for y in 0..<height {
      for x in 0..<width where pixel(x: x, y: y).alpha > threshold {
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
      }
    }
    guard maxX >= minX, maxY >= minY else { return nil }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
  }
}
