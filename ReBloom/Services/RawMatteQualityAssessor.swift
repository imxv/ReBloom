import CoreImage

struct RawMatteQualityReport: Equatable, Sendable {
  let assessment: StickerQualityAssessment
  let foregroundCoverage: Double
}

struct RawMatteQualityAssessor {
  private static let context = CIContext(options: [.cacheIntermediates: false])
  private static let maximumLongEdge: CGFloat = 256

  static func assessSynchronously(mask: CIImage) -> RawMatteQualityReport {
    guard let measurement = RawMatteMeasurement(mask: mask) else {
      return RawMatteQualityReport(
        assessment: StickerQualityAssessment(level: .rejected, issues: [.subjectMissing]),
        foregroundCoverage: 0
      )
    }
    if measurement.foregroundCoverage < 0.015 {
      return RawMatteQualityReport(
        assessment: StickerQualityAssessment(level: .rejected, issues: [.subjectMissing]),
        foregroundCoverage: measurement.foregroundCoverage
      )
    }
    if measurement.largestComponentRatio < 0.80 {
      return RawMatteQualityReport(
        assessment: StickerQualityAssessment(
          level: .rejected,
          issues: [.subjectFragmented]
        ),
        foregroundCoverage: measurement.foregroundCoverage
      )
    }
    if measurement.uncertainForegroundRatio >= 0.25,
      measurement.maximumRowSpanRatio >= 0.75,
      measurement.broadRowRatio >= 0.12
    {
      return RawMatteQualityReport(
        assessment: StickerQualityAssessment(
          level: .rejected,
          issues: [.backgroundAdhesionSuspected]
        ),
        foregroundCoverage: measurement.foregroundCoverage
      )
    }
    if measurement.uncertainForegroundRatio >= 0.18 {
      return RawMatteQualityReport(
        assessment: StickerQualityAssessment(
          level: .reviewRecommended,
          issues: [.edgeMayIncludeBackground]
        ),
        foregroundCoverage: measurement.foregroundCoverage
      )
    }
    return RawMatteQualityReport(
      assessment: .acceptable,
      foregroundCoverage: measurement.foregroundCoverage
    )
  }

  private struct RawMatteMeasurement {
    let foregroundCoverage: Double
    let uncertainForegroundRatio: Double
    let maximumRowSpanRatio: Double
    let broadRowRatio: Double
    let largestComponentRatio: Double

    init?(mask: CIImage) {
      let sourceExtent = mask.extent.integral
      guard sourceExtent.width > 0, sourceExtent.height > 0 else { return nil }

      let scale = min(
        1,
        maximumLongEdge / max(sourceExtent.width, sourceExtent.height)
      )
      let sampled =
        mask
        .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        .transformed(
          by: CGAffineTransform(
            translationX: -sourceExtent.minX * scale,
            y: -sourceExtent.minY * scale
          ))
      let extent = sampled.extent.integral
      let width = Int(extent.width)
      let height = Int(extent.height)
      guard width > 0, height > 0 else { return nil }

      let bytesPerRow = width * 4
      var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
      context.render(
        sampled,
        toBitmap: &pixels,
        rowBytes: bytesPerRow,
        bounds: extent,
        format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
      )

      var foregroundPixels = 0
      var uncertainPixels = 0
      var rowSpans: [Int] = []
      rowSpans.reserveCapacity(height)
      for row in 0..<height {
        var minimumX = width
        var maximumX = -1
        for column in 0..<width {
          let value = pixels[row * bytesPerRow + column * 4]
          guard value > 24 else { continue }
          foregroundPixels += 1
          if value < 230 { uncertainPixels += 1 }
          minimumX = min(minimumX, column)
          maximumX = max(maximumX, column)
        }
        if maximumX >= minimumX {
          rowSpans.append(maximumX - minimumX + 1)
        }
      }
      foregroundCoverage = Double(foregroundPixels) / Double(max(width * height, 1))
      uncertainForegroundRatio = Double(uncertainPixels) / Double(max(foregroundPixels, 1))
      let largestComponent = Self.largestVisibleComponent(
        pixels: pixels,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow
      )
      largestComponentRatio = Double(largestComponent) / Double(max(foregroundPixels, 1))

      let sortedSpans = rowSpans.sorted()
      let medianSpan = sortedSpans.isEmpty ? 0 : sortedSpans[sortedSpans.count / 2]
      let broadThreshold = max(Double(medianSpan) * 2, Double(width) * 0.65)
      let broadRows = rowSpans.filter { Double($0) >= broadThreshold }.count
      maximumRowSpanRatio = Double(rowSpans.max() ?? 0) / Double(max(width, 1))
      broadRowRatio = Double(broadRows) / Double(max(rowSpans.count, 1))
    }

    private static func largestVisibleComponent(
      pixels: [UInt8],
      width: Int,
      height: Int,
      bytesPerRow: Int
    ) -> Int {
      let pixelCount = width * height
      var visited = [UInt8](repeating: 0, count: pixelCount)
      var queue: [Int] = []
      queue.reserveCapacity(pixelCount / 2)
      var largest = 0

      func isVisible(_ index: Int) -> Bool {
        let row = index / width
        let column = index % width
        return pixels[row * bytesPerRow + column * 4] > 24
      }

      for start in 0..<pixelCount where visited[start] == 0 && isVisible(start) {
        visited[start] = 1
        queue.removeAll(keepingCapacity: true)
        queue.append(start)
        var head = 0

        while head < queue.count {
          let index = queue[head]
          head += 1
          let column = index % width
          let row = index / width

          func appendIfVisible(_ neighbor: Int) {
            guard visited[neighbor] == 0, isVisible(neighbor) else { return }
            visited[neighbor] = 1
            queue.append(neighbor)
          }

          if column > 0 { appendIfVisible(index - 1) }
          if column + 1 < width { appendIfVisible(index + 1) }
          if row > 0 { appendIfVisible(index - width) }
          if row + 1 < height { appendIfVisible(index + width) }
        }

        largest = max(largest, queue.count)
      }
      return largest
    }
  }
}
