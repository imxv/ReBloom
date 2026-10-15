import CoreImage
import UIKit

struct TransparentStickerInspection: Equatable, Sendable {
  let transparentRatio: Double
  let opaqueRatio: Double
  let semiTransparentRatio: Double
  let cornerTransparentRatio: Double
  let foregroundCoverage: Double
  let largestVisibleComponentRatio: Double
}

struct TransparentStickerInspector {
  private static let maximumLongEdge = 768

  static func inspect(_ image: UIImage) -> TransparentStickerInspection? {
    guard let sourceImage = image.cgImage else { return nil }
    let sourceWidth = sourceImage.width
    let sourceHeight = sourceImage.height
    guard sourceWidth > 0, sourceHeight > 0 else { return nil }

    let scale = min(
      1,
      Double(maximumLongEdge) / Double(max(sourceWidth, sourceHeight))
    )
    let width = max(1, Int((Double(sourceWidth) * scale).rounded()))
    let height = max(1, Int((Double(sourceHeight) * scale).rounded()))
    let pixelCount = width * height
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    guard
      let context = CGContext(
        data: &pixels,
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
    context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    func alpha(at index: Int) -> UInt8 {
      pixels[index * 4 + 3]
    }

    var transparent = 0
    var opaque = 0
    var semiTransparent = 0
    var visible = 0
    for index in 0..<pixelCount {
      let value = alpha(at: index)
      if value < 8 { transparent += 1 }
      if value > 247 { opaque += 1 }
      if value >= 8, value <= 247 { semiTransparent += 1 }
      if value > 16 { visible += 1 }
    }

    let cornerLength = min(32, min(width, height))
    let cornerStarts = [
      (0, 0),
      (width - cornerLength, 0),
      (0, height - cornerLength),
      (width - cornerLength, height - cornerLength),
    ]
    var cornerPixels = 0
    var transparentCorners = 0
    for (startX, startY) in cornerStarts {
      for y in startY..<(startY + cornerLength) {
        for x in startX..<(startX + cornerLength) {
          cornerPixels += 1
          if alpha(at: y * width + x) < 8 { transparentCorners += 1 }
        }
      }
    }

    let largestComponent = largestVisibleComponent(
      pixels: pixels,
      width: width,
      height: height
    )
    return TransparentStickerInspection(
      transparentRatio: Double(transparent) / Double(max(pixelCount, 1)),
      opaqueRatio: Double(opaque) / Double(max(pixelCount, 1)),
      semiTransparentRatio: Double(semiTransparent) / Double(max(pixelCount, 1)),
      cornerTransparentRatio: Double(transparentCorners) / Double(max(cornerPixels, 1)),
      foregroundCoverage: Double(visible) / Double(max(pixelCount, 1)),
      largestVisibleComponentRatio: Double(largestComponent) / Double(max(visible, 1))
    )
  }

  private static func largestVisibleComponent(
    pixels: [UInt8],
    width: Int,
    height: Int
  ) -> Int {
    let pixelCount = width * height
    var visited = [UInt8](repeating: 0, count: pixelCount)
    var queue: [Int] = []
    queue.reserveCapacity(pixelCount / 2)
    var largest = 0

    func isVisible(_ index: Int) -> Bool {
      pixels[index * 4 + 3] > 16
    }

    for start in 0..<pixelCount where visited[start] == 0 && isVisible(start) {
      visited[start] = 1
      queue.removeAll(keepingCapacity: true)
      queue.append(start)
      var head = 0
      while head < queue.count {
        let index = queue[head]
        head += 1
        let x = index % width
        let y = index / width

        func enqueue(_ neighbor: Int) {
          guard visited[neighbor] == 0, isVisible(neighbor) else { return }
          visited[neighbor] = 1
          queue.append(neighbor)
        }

        if x > 0 { enqueue(index - 1) }
        if x + 1 < width { enqueue(index + 1) }
        if y > 0 { enqueue(index - width) }
        if y + 1 < height { enqueue(index + width) }
      }
      largest = max(largest, queue.count)
    }
    return largest
  }
}

struct AITransparentStickerProcessor {
  private static let context = CIContext(options: [
    .cacheIntermediates: false,
    .priorityRequestLow: false,
  ])

  func process(_ image: UIImage) async throws -> StickerProcessingResult {
    try await Task.detached(priority: .userInitiated) {
      let start = ContinuousClock.now
      let result = try Self.processSynchronously(image)
      let elapsed = start.duration(to: .now)
      let milliseconds =
        Int(elapsed.components.seconds * 1_000)
        + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
      return StickerProcessingResult(
        image: result.image,
        elapsedMilliseconds: milliseconds,
        foregroundCoverage: result.inspection.foregroundCoverage,
        rawMatteAssessment: result.edgeAssessment,
        sourceFidelityAssessment: .acceptable
      )
    }.value
  }

  private static func processSynchronously(_ image: UIImage) throws -> (
    image: UIImage,
    inspection: TransparentStickerInspection,
    edgeAssessment: StickerQualityAssessment
  ) {
    guard let source = CIImage(image: image, options: [.applyOrientationProperty: true]) else {
      throw StickerProcessingError.unreadableImage
    }
    let sourceExtent = source.extent.integral
    guard sourceExtent.width >= 64, sourceExtent.height >= 64 else {
      throw StickerProcessingError.imageTooSmall
    }
    guard let inspection = TransparentStickerInspector.inspect(image) else {
      throw StickerProcessingError.unreadableImage
    }
    guard inspection.transparentRatio >= 0.08,
      inspection.cornerTransparentRatio >= 0.75
    else {
      throw StickerProcessingError.aiOutputMissingTransparency
    }
    guard inspection.foregroundCoverage >= 0.025,
      inspection.opaqueRatio >= 0.012
    else {
      throw StickerProcessingError.personNotFound
    }
    guard inspection.largestVisibleComponentRatio >= 0.80 else {
      throw StickerProcessingError.outputQualityTooLow(
        StickerQualityAssessment(level: .rejected, issues: [.subjectFragmented])
      )
    }

    let edgeAssessment: StickerQualityAssessment =
      inspection.semiTransparentRatio > 0.12
      ? StickerQualityAssessment(level: .reviewRecommended, issues: [.edgeMayIncludeBackground])
      : .acceptable

    let outlineRadius = max(12, min(sourceExtent.width, sourceExtent.height) * 0.014)
    let padding = ceil(outlineRadius * 2.25)
    let translation = CGAffineTransform(
      translationX: padding - sourceExtent.minX,
      y: padding - sourceExtent.minY
    )
    let translatedSubject = source.transformed(by: translation)
    let alphaMask = source.applyingFilter(
      "CIColorMatrix",
      parameters: [
        "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
      ]
    ).transformed(by: translation)
    let canvas = CGRect(
      x: 0,
      y: 0,
      width: sourceExtent.width + padding * 2,
      height: sourceExtent.height + padding * 2
    ).integral
    let expandedMask =
      alphaMask
      .applyingFilter(
        "CIMorphologyMaximum",
        parameters: [kCIInputRadiusKey: outlineRadius]
      )
      .cropped(to: canvas)
    let clear = CIImage(color: .clear).cropped(to: canvas)
    let white = CIImage(color: .white).cropped(to: canvas)
    let outline = white.applyingFilter(
      "CIBlendWithMask",
      parameters: [
        kCIInputBackgroundImageKey: clear,
        kCIInputMaskImageKey: expandedMask,
      ]
    )
    let composited =
      translatedSubject
      .cropped(to: canvas)
      .composited(over: outline)
      .cropped(to: canvas)
    guard
      let fullImage = context.createCGImage(
        composited,
        from: canvas,
        format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
      )
    else {
      throw StickerProcessingError.renderFailed
    }

    let cropped =
      cropToAllVisiblePixels(
        fullImage,
        extraMargin: Int(padding * 0.35)
      ) ?? fullImage
    let deliveryImage = ensureMinimumLongEdge(cropped, minimum: 1_536) ?? cropped
    return (
      UIImage(cgImage: deliveryImage, scale: 1, orientation: .up),
      inspection,
      edgeAssessment
    )
  }

  private static func cropToAllVisiblePixels(
    _ image: CGImage,
    extraMargin: Int
  ) -> CGImage? {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    guard
      let context = CGContext(
        data: &pixels,
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
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var minimumX = width
    var minimumY = height
    var maximumX = -1
    var maximumY = -1
    for y in 0..<height {
      for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 16 {
        minimumX = min(minimumX, x)
        minimumY = min(minimumY, y)
        maximumX = max(maximumX, x)
        maximumY = max(maximumY, y)
      }
    }
    guard maximumX >= minimumX, maximumY >= minimumY else { return nil }
    minimumX = max(0, minimumX - extraMargin)
    minimumY = max(0, minimumY - extraMargin)
    maximumX = min(width - 1, maximumX + extraMargin)
    maximumY = min(height - 1, maximumY + extraMargin)
    return image.cropping(
      to: CGRect(
        x: minimumX,
        y: minimumY,
        width: maximumX - minimumX + 1,
        height: maximumY - minimumY + 1
      )
    )
  }

  private static func ensureMinimumLongEdge(
    _ image: CGImage,
    minimum: CGFloat
  ) -> CGImage? {
    let longEdge = CGFloat(max(image.width, image.height))
    guard longEdge > 0, longEdge < minimum else { return image }
    let scale = minimum / longEdge
    let filter = CIFilter(name: "CILanczosScaleTransform")
    filter?.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
    filter?.setValue(scale, forKey: kCIInputScaleKey)
    filter?.setValue(1, forKey: kCIInputAspectRatioKey)
    guard let output = filter?.outputImage else { return nil }
    return context.createCGImage(
      output,
      from: output.extent.integral,
      format: .RGBA8,
      colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
    )
  }
}
