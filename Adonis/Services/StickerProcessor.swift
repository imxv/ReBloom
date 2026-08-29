import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

struct StickerProcessingResult {
  let image: UIImage
  let elapsedMilliseconds: Int
  let foregroundCoverage: Double
}

struct StickerProcessor {
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
        foregroundCoverage: result.coverage
      )
    }.value
  }

  private static func processSynchronously(_ image: UIImage) throws -> (
    image: UIImage, coverage: Double
  ) {
    guard
      let source = CIImage(
        image: image,
        options: [.applyOrientationProperty: true]
      )
    else {
      throw StickerProcessingError.unreadableImage
    }

    let sourceExtent = source.extent.integral
    guard sourceExtent.width >= 64, sourceExtent.height >= 64 else {
      throw StickerProcessingError.imageTooSmall
    }

    #if targetEnvironment(simulator)
      // The iOS 26 simulator currently rejects the stateful person
      // segmentation model with an E5RT backend error. Person instance masks
      // use a separate Vision pipeline and still return a real, image-derived
      // alpha mask, so the local demo remains fully testable.
      let request = VNGeneratePersonInstanceMaskRequest()
      let handler = VNImageRequestHandler(ciImage: source, options: [:])
      do {
        try handler.perform([request])
      } catch {
        throw StickerProcessingError.simulatorVisionUnavailable
      }

      guard let observation = request.results?.first,
        !observation.allInstances.isEmpty
      else {
        throw StickerProcessingError.personNotFound
      }

      let maskBuffer = try observation.generateScaledMaskForImage(
        forInstances: observation.allInstances,
        from: handler
      )
    #else
      let request = VNGeneratePersonSegmentationRequest()
      request.qualityLevel = .accurate
      request.outputPixelFormat = kCVPixelFormatType_OneComponent8

      let handler = VNImageRequestHandler(ciImage: source, options: [:])
      try handler.perform([request])

      guard let observation = request.results?.first else {
        throw StickerProcessingError.personNotFound
      }
      let maskBuffer = observation.pixelBuffer
    #endif

    let coverage = foregroundCoverage(of: maskBuffer)
    guard coverage > 0.015 else {
      throw StickerProcessingError.personNotFound
    }

    var mask = CIImage(cvPixelBuffer: maskBuffer)
    let scaleX = sourceExtent.width / mask.extent.width
    let scaleY = sourceExtent.height / mask.extent.height
    mask =
      mask
      .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
      .cropped(to: sourceExtent)

    let outlineRadius = max(12, min(sourceExtent.width, sourceExtent.height) * 0.014)
    let padding = ceil(outlineRadius * 2.25)
    let translation = CGAffineTransform(
      translationX: padding - sourceExtent.minX,
      y: padding - sourceExtent.minY
    )
    let translatedSource = source.transformed(by: translation)
    let translatedMask = mask.transformed(by: translation)
    let canvas = CGRect(
      x: 0,
      y: 0,
      width: sourceExtent.width + padding * 2,
      height: sourceExtent.height + padding * 2
    ).integral

    let clear = CIImage(color: .clear).cropped(to: canvas)
    let white = CIImage(color: CIColor.white).cropped(to: canvas)
    let expandedMask =
      translatedMask
      .applyingFilter(
        "CIMorphologyMaximum",
        parameters: [kCIInputRadiusKey: outlineRadius]
      )
      .cropped(to: canvas)

    let outline = white.applyingFilter(
      "CIBlendWithMask",
      parameters: [
        kCIInputBackgroundImageKey: clear,
        kCIInputMaskImageKey: expandedMask,
      ]
    )
    let subject = translatedSource.applyingFilter(
      "CIBlendWithMask",
      parameters: [
        kCIInputBackgroundImageKey: clear,
        kCIInputMaskImageKey: translatedMask,
      ]
    )
    let composited = subject.composited(over: outline).cropped(to: canvas)

    guard
      let fullCGImage = context.createCGImage(
        composited,
        from: canvas,
        format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
      )
    else {
      throw StickerProcessingError.renderFailed
    }

    let cropped =
      cropToLargestVisibleComponent(
        fullCGImage,
        extraMargin: Int(padding * 0.35)
      ) ?? fullCGImage
    let deliveryImage = ensureMinimumLongEdge(cropped, minimum: 1_536) ?? cropped
    return (UIImage(cgImage: deliveryImage, scale: image.scale, orientation: .up), coverage)
  }

  private static func foregroundCoverage(of pixelBuffer: CVPixelBuffer) -> Double {
    let image = CIImage(cvPixelBuffer: pixelBuffer)
    let extent = image.extent.integral
    let sampleSize: CGFloat = 96
    let scale = min(sampleSize / extent.width, sampleSize / extent.height, 1)
    let sampled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

    guard
      let cgImage = context.createCGImage(
        sampled,
        from: sampled.extent.integral,
        format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
      )
    else {
      return 0
    }

    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

    guard
      let bitmap = CGContext(
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
      return 0
    }
    bitmap.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    var foregroundPixels = 0
    for y in 0..<height {
      for x in 0..<width where pixels[y * bytesPerRow + x * bytesPerPixel] > 24 {
        foregroundPixels += 1
      }
    }

    return Double(foregroundPixels) / Double(max(width * height, 1))
  }

  private static func cropToLargestVisibleComponent(
    _ image: CGImage,
    extraMargin: Int
  ) -> CGImage? {
    let width = image.width
    let height = image.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
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

    var visited = [UInt8](repeating: 0, count: width * height)
    var queue: [Int] = []
    queue.reserveCapacity(width * height / 4)
    var bestCount = 0
    var bestBounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)?

    for start in 0..<(width * height) {
      guard visited[start] == 0,
        pixels[start * bytesPerPixel + 3] > 16
      else {
        continue
      }

      visited[start] = 1
      queue.removeAll(keepingCapacity: true)
      queue.append(start)
      var head = 0
      var minX = start % width
      var maxX = minX
      var minY = start / width
      var maxY = minY

      while head < queue.count {
        let index = queue[head]
        head += 1
        let x = index % width
        let y = index / width
        minX = min(minX, x)
        maxX = max(maxX, x)
        minY = min(minY, y)
        maxY = max(maxY, y)

        func enqueue(_ neighbor: Int) {
          guard visited[neighbor] == 0,
            pixels[neighbor * bytesPerPixel + 3] > 16
          else {
            return
          }
          visited[neighbor] = 1
          queue.append(neighbor)
        }

        if x > 0 { enqueue(index - 1) }
        if x + 1 < width { enqueue(index + 1) }
        if y > 0 { enqueue(index - width) }
        if y + 1 < height { enqueue(index + width) }
      }

      if queue.count > bestCount {
        bestCount = queue.count
        bestBounds = (minX, minY, maxX, maxY)
      }
    }

    guard var bounds = bestBounds else { return nil }
    bounds.minX = max(0, bounds.minX - extraMargin)
    bounds.minY = max(0, bounds.minY - extraMargin)
    bounds.maxX = min(width - 1, bounds.maxX + extraMargin)
    bounds.maxY = min(height - 1, bounds.maxY + extraMargin)

    return image.cropping(
      to: CGRect(
        x: bounds.minX,
        y: bounds.minY,
        width: bounds.maxX - bounds.minX + 1,
        height: bounds.maxY - bounds.minY + 1
      ))
  }

  private static func ensureMinimumLongEdge(
    _ image: CGImage,
    minimum: CGFloat
  ) -> CGImage? {
    let longEdge = CGFloat(max(image.width, image.height))
    guard longEdge > 0, longEdge < minimum else { return image }

    let scale = minimum / longEdge
    let source = CIImage(cgImage: image)
    let filter = CIFilter.lanczosScaleTransform()
    filter.inputImage = source
    filter.scale = Float(scale)
    filter.aspectRatio = 1
    guard let output = filter.outputImage else { return nil }

    return context.createCGImage(
      output,
      from: output.extent.integral,
      format: .RGBA8,
      colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
    )
  }
}

enum StickerProcessingError: LocalizedError {
  case unreadableImage
  case imageTooSmall
  case personNotFound
  case renderFailed
  case simulatorVisionUnavailable

  var errorDescription: String? {
    switch self {
    case .unreadableImage:
      "这张照片暂时无法读取，请换一张试试。"
    case .imageTooSmall:
      "照片尺寸太小了，换一张更清楚的照片吧。"
    case .personNotFound:
      "没有找到足够清楚的人像。试试人物更完整、光线更明亮的照片。"
    case .renderFailed:
      "贴纸生成到最后一步时失败了，请再试一次。"
    case .simulatorVisionUnavailable:
      "当前模拟器无法运行本机人像模型。请先用内置样片体验完整流程，或在 iPhone 上选择自己的照片。"
    }
  }
}
