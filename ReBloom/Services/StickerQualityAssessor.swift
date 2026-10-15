import UIKit

struct StickerQualityAssessor {
  static let version = AdonisProcessingVersion.stickerQuality

  func assess(
    sticker: UIImage,
    foregroundCoverage: Double,
    rawMatteAssessment: StickerQualityAssessment = .acceptable,
    sourceFidelityAssessment: StickerQualityAssessment = .acceptable
  ) async -> StickerQualityAssessment {
    await Task.detached(priority: .userInitiated) {
      Self.assessSynchronously(
        sticker: sticker,
        foregroundCoverage: foregroundCoverage,
        rawMatteAssessment: rawMatteAssessment,
        sourceFidelityAssessment: sourceFidelityAssessment
      )
    }.value
  }

  static func assessSynchronously(
    sticker: UIImage,
    foregroundCoverage: Double,
    rawMatteAssessment: StickerQualityAssessment = .acceptable,
    sourceFidelityAssessment: StickerQualityAssessment = .acceptable
  ) -> StickerQualityAssessment {
    if rawMatteAssessment.isRejected {
      return rawMatteAssessment
    }
    if sourceFidelityAssessment.isRejected {
      return sourceFidelityAssessment
    }
    guard let measurement = StickerQualityMeasurement(image: sticker) else {
      return StickerQualityAssessment(level: .rejected, issues: [.subjectMissing])
    }

    var rejectedIssues: [StickerQualityIssue] = []
    if measurement.transparentRatio < 0.08
      || measurement.cornerTransparentRatio < 0.75
    {
      rejectedIssues.append(.backgroundNotSeparated)
    }
    if measurement.opaqueRatio < 0.025
      || measurement.nonWhiteOpaqueRatio < 0.012
    {
      rejectedIssues.append(.subjectMissing)
    }
    if measurement.largestComponentRatio < 0.80 {
      rejectedIssues.append(.subjectFragmented)
    }
    if !rejectedIssues.isEmpty {
      return StickerQualityAssessment(level: .rejected, issues: rejectedIssues)
    }

    var reviewIssues: [StickerQualityIssue] = []
    if measurement.semiTransparentRatio > 0.10
      || measurement.cornerTransparentRatio < 0.95
    {
      reviewIssues.append(.edgeMayIncludeBackground)
    }
    if measurement.largestComponentRatio < 0.97 {
      reviewIssues.append(.subjectFragmented)
    }
    if measurement.whiteBoundaryRatio < 0.78 {
      reviewIssues.append(.outlineMayBeBroken)
    }
    if foregroundCoverage > 0, foregroundCoverage < 0.04 {
      reviewIssues.append(.subjectTooSmall)
    }

    guard !reviewIssues.isEmpty else {
      return rawMatteAssessment.requiresReview ? rawMatteAssessment : .acceptable
    }
    return StickerQualityAssessment(
      level: .reviewRecommended,
      issues: rawMatteAssessment.issues + reviewIssues
    )
  }
}

private struct StickerQualityMeasurement {
  private static let maximumLongEdge = 768

  let transparentRatio: Double
  let opaqueRatio: Double
  let semiTransparentRatio: Double
  let cornerTransparentRatio: Double
  let largestComponentRatio: Double
  let whiteBoundaryRatio: Double
  let nonWhiteOpaqueRatio: Double

  init?(image: UIImage) {
    guard let sourceImage = image.cgImage else { return nil }
    let sourceWidth = sourceImage.width
    let sourceHeight = sourceImage.height
    guard sourceWidth > 0, sourceHeight > 0 else { return nil }

    let measurementScale = min(
      1,
      Double(Self.maximumLongEdge) / Double(max(sourceWidth, sourceHeight))
    )
    let width = max(1, Int((Double(sourceWidth) * measurementScale).rounded()))
    let height = max(1, Int((Double(sourceHeight) * measurementScale).rounded()))

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
    var visible = 0
    var nonWhiteOpaque = 0
    var boundary = 0
    var whiteBoundary = 0

    for index in 0..<pixelCount {
      let pixelAlpha = alpha(at: index)
      if pixelAlpha < 8 { transparent += 1 }
      if pixelAlpha > 247 { opaque += 1 }
      if pixelAlpha > 16 { visible += 1 }
      if pixelAlpha > 247 && !Self.isWhitePixel(pixels, index: index, alpha: pixelAlpha) {
        nonWhiteOpaque += 1
      }

      guard pixelAlpha > 16 else { continue }
      let x = index % width
      let y = index / width
      let touchesTransparency =
        (x == 0 || alpha(at: index - 1) <= 8)
        || (x == width - 1 || alpha(at: index + 1) <= 8)
        || (y == 0 || alpha(at: index - width) <= 8)
        || (y == height - 1 || alpha(at: index + width) <= 8)
      if touchesTransparency {
        boundary += 1
        if Self.isWhitePixel(pixels, index: index, alpha: pixelAlpha) {
          whiteBoundary += 1
        }
      }
    }

    let cornerLength = min(32, min(width, height))
    let cornerStarts = [
      (0, 0),
      (width - cornerLength, 0),
      (0, height - cornerLength),
      (width - cornerLength, height - cornerLength),
    ]
    var cornerPixels = 0
    var cornerTransparent = 0
    for (startX, startY) in cornerStarts {
      for y in startY..<(startY + cornerLength) {
        for x in startX..<(startX + cornerLength) {
          cornerPixels += 1
          if alpha(at: y * width + x) < 8 { cornerTransparent += 1 }
        }
      }
    }

    let largestComponent = Self.largestVisibleComponent(
      width: width,
      height: height,
      alpha: alpha
    )
    let total = Double(pixelCount)
    transparentRatio = Double(transparent) / total
    opaqueRatio = Double(opaque) / total
    semiTransparentRatio = Double(pixelCount - transparent - opaque) / total
    cornerTransparentRatio = Double(cornerTransparent) / Double(max(cornerPixels, 1))
    largestComponentRatio = Double(largestComponent) / Double(max(visible, 1))
    whiteBoundaryRatio = Double(whiteBoundary) / Double(max(boundary, 1))
    nonWhiteOpaqueRatio = Double(nonWhiteOpaque) / total
  }

  private static func isWhitePixel(
    _ pixels: [UInt8],
    index: Int,
    alpha: UInt8
  ) -> Bool {
    guard alpha > 0 else { return false }
    let offset = index * 4
    let scale = 255.0 / Double(alpha)
    let red = min(255, Double(pixels[offset]) * scale)
    let green = min(255, Double(pixels[offset + 1]) * scale)
    let blue = min(255, Double(pixels[offset + 2]) * scale)
    let minimumComponent = min(red, min(green, blue))
    let maximumComponent = max(red, max(green, blue))
    return minimumComponent >= 235 && maximumComponent - minimumComponent <= 25
  }

  private static func largestVisibleComponent(
    width: Int,
    height: Int,
    alpha: (Int) -> UInt8
  ) -> Int {
    let pixelCount = width * height
    var visited = [UInt8](repeating: 0, count: pixelCount)
    var queue: [Int] = []
    queue.reserveCapacity(pixelCount / 2)
    var largest = 0

    for start in 0..<pixelCount where visited[start] == 0 && alpha(start) > 16 {
      visited[start] = 1
      queue.removeAll(keepingCapacity: true)
      queue.append(start)
      var head = 0

      while head < queue.count {
        let index = queue[head]
        head += 1
        let x = index % width
        let y = index / width

        if x > 0 { appendIfVisible(index - 1, alpha: alpha, visited: &visited, queue: &queue) }
        if x + 1 < width {
          appendIfVisible(index + 1, alpha: alpha, visited: &visited, queue: &queue)
        }
        if y > 0 {
          appendIfVisible(index - width, alpha: alpha, visited: &visited, queue: &queue)
        }
        if y + 1 < height {
          appendIfVisible(index + width, alpha: alpha, visited: &visited, queue: &queue)
        }
      }

      largest = max(largest, queue.count)
    }
    return largest
  }

  private static func appendIfVisible(
    _ index: Int,
    alpha: (Int) -> UInt8,
    visited: inout [UInt8],
    queue: inout [Int]
  ) {
    guard visited[index] == 0, alpha(index) > 16 else { return }
    visited[index] = 1
    queue.append(index)
  }
}
