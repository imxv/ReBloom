import UIKit

enum StickerTryOnDeliveryIssue: String, Equatable, Sendable {
  case garmentClipped = "garment_clipped"
  case garmentTooSmall = "garment_too_small"
  case protectedPixelsChanged = "protected_pixels_changed"
  case outsidePlacementChanged = "outside_placement_changed"
  case garmentAppearanceChanged = "garment_appearance_changed"
}

struct StickerTryOnDeliveryQuality: Equatable, Sendable {
  let issues: [StickerTryOnDeliveryIssue]
  let placementRetention: Double
  let visibleGarmentCoverage: Double
  let protectedPixelMismatchRatio: Double
  let outsidePlacementMismatchRatio: Double
  let opaqueGarmentColorDelta: Double

  var isDeliverable: Bool { issues.isEmpty }
}

struct StickerTryOnDeliveryQualityGate {
  private struct PixelBuffer {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    func offset(x: Int, y: Int) -> Int {
      (y * width + x) * 4
    }
  }

  func assess(
    person: UIImage,
    output: UIImage,
    garment: UIImage,
    targetRect: CGRect,
    protectedRegion: CGRect,
    placementRetention: Double,
    outlineRadius: CGFloat
  ) throws -> StickerTryOnDeliveryQuality {
    guard person.size.width > 0, person.size.height > 0 else {
      throw StickerTryOnError.renderFailed
    }

    let analysisSize = Self.analysisSize(for: person.size)
    guard
      let sourcePixels = Self.pixelBuffer(for: person, size: analysisSize),
      let outputPixels = Self.pixelBuffer(for: output, size: analysisSize)
    else {
      throw StickerTryOnError.renderFailed
    }

    let scaleX = analysisSize.width / person.size.width
    let scaleY = analysisSize.height / person.size.height
    let scaledTarget = targetRect.tryOnScaled(x: scaleX, y: scaleY)
    let layer = Self.transparentImage(size: analysisSize) {
      garment.draw(in: scaledTarget)
    }
    guard let garmentPixels = Self.pixelBuffer(for: layer, size: analysisSize) else {
      throw StickerTryOnError.renderFailed
    }

    let scaledProtected = protectedRegion.tryOnScaled(x: scaleX, y: scaleY)
    let allowedPlacement =
      targetRect
      .insetBy(dx: -(outlineRadius + 2), dy: -(outlineRadius + 2))
      .tryOnScaled(x: scaleX, y: scaleY)
    let totalPixels = max(sourcePixels.width * sourcePixels.height, 1)

    var visibleGarmentPixels = 0
    var opaqueGarmentPixels = 0
    var opaqueColorDelta = 0.0
    var protectedPixels = 0
    var changedProtectedPixels = 0
    var outsidePixels = 0
    var changedOutsidePixels = 0

    for y in 0..<sourcePixels.height {
      for x in 0..<sourcePixels.width {
        let offset = sourcePixels.offset(x: x, y: y)
        let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
        let layerAlpha = garmentPixels.bytes[offset + 3]
        if layerAlpha >= 20 {
          visibleGarmentPixels += 1
        }
        if layerAlpha >= 245 {
          opaqueGarmentPixels += 1
          opaqueColorDelta += Self.normalizedColorDelta(
            lhs: outputPixels.bytes,
            rhs: garmentPixels.bytes,
            offset: offset
          )
        }

        let changed = Self.hasVisibleDifference(
          lhs: sourcePixels.bytes,
          rhs: outputPixels.bytes,
          offset: offset
        )
        if scaledProtected.contains(point) {
          protectedPixels += 1
          if changed { changedProtectedPixels += 1 }
        }
        if !allowedPlacement.contains(point) {
          outsidePixels += 1
          if changed { changedOutsidePixels += 1 }
        }
      }
    }

    let visibleGarmentCoverage = Double(visibleGarmentPixels) / Double(totalPixels)
    let protectedMismatch = Double(changedProtectedPixels) / Double(max(protectedPixels, 1))
    let outsideMismatch = Double(changedOutsidePixels) / Double(max(outsidePixels, 1))
    let colorDelta =
      opaqueGarmentPixels > 0
      ? opaqueColorDelta / Double(opaqueGarmentPixels)
      : 1

    var issues: [StickerTryOnDeliveryIssue] = []
    if placementRetention < 0.96 { issues.append(.garmentClipped) }
    if visibleGarmentCoverage < 0.012 { issues.append(.garmentTooSmall) }
    if protectedMismatch > 0.000_5 { issues.append(.protectedPixelsChanged) }
    if outsideMismatch > 0.000_5 { issues.append(.outsidePlacementChanged) }
    if colorDelta > 0.06 { issues.append(.garmentAppearanceChanged) }

    return StickerTryOnDeliveryQuality(
      issues: issues,
      placementRetention: min(max(placementRetention, 0), 1),
      visibleGarmentCoverage: visibleGarmentCoverage,
      protectedPixelMismatchRatio: protectedMismatch,
      outsidePlacementMismatchRatio: outsideMismatch,
      opaqueGarmentColorDelta: colorDelta
    )
  }

  private static func analysisSize(for size: CGSize) -> CGSize {
    let maximumDimension: CGFloat = 384
    let largest = max(size.width, size.height)
    let scale = min(maximumDimension / max(largest, 1), 1)
    return CGSize(
      width: max(1, (size.width * scale).rounded()),
      height: max(1, (size.height * scale).rounded())
    )
  }

  private static func transparentImage(
    size: CGSize,
    drawing: () -> Void
  ) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      drawing()
    }
  }

  private static func pixelBuffer(for image: UIImage, size: CGSize) -> PixelBuffer? {
    let width = max(Int(size.width.rounded()), 1)
    let height = max(Int(size.height.rounded()), 1)
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    guard
      let context = CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          | CGBitmapInfo.byteOrder32Big.rawValue
      )
    else {
      return nil
    }
    context.interpolationQuality = .high
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    UIGraphicsPushContext(context)
    image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
    UIGraphicsPopContext()
    return PixelBuffer(width: width, height: height, bytes: bytes)
  }

  private static func hasVisibleDifference(
    lhs: [UInt8],
    rhs: [UInt8],
    offset: Int
  ) -> Bool {
    (0..<3).contains { channel in
      abs(Int(lhs[offset + channel]) - Int(rhs[offset + channel])) > 6
    }
  }

  private static func normalizedColorDelta(
    lhs: [UInt8],
    rhs: [UInt8],
    offset: Int
  ) -> Double {
    let difference = (0..<3).reduce(0) { total, channel in
      total + abs(Int(lhs[offset + channel]) - Int(rhs[offset + channel]))
    }
    return Double(difference) / (3 * 255)
  }
}

extension CGRect {
  fileprivate func tryOnScaled(x scaleX: CGFloat, y scaleY: CGFloat) -> CGRect {
    CGRect(
      x: minX * scaleX,
      y: minY * scaleY,
      width: width * scaleX,
      height: height * scaleY
    )
  }
}
