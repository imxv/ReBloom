import CoreImage

struct StickerSourceFidelityReport: Equatable, Sendable {
  let assessment: StickerQualityAssessment
  let comparedCorePixelCount: Int
  let changedCorePixelRatio: Double
}

struct StickerSourceFidelityAssessor {
  static let version = AdonisProcessingVersion.stickerSourceFidelity

  private static let maximumLongEdge = 768
  private static let coreAlphaThreshold: UInt8 = 250
  private static let maximumChannelDelta = 4
  private static let maximumChangedCorePixelRatio = 0.005
  private static let context = CIContext(options: [.cacheIntermediates: false])

  static func assessSynchronously(
    source: CIImage,
    subject: CIImage,
    mask: CIImage
  ) -> StickerSourceFidelityReport {
    guard
      let measurement = Measurement(
        source: source,
        subject: subject,
        mask: mask,
        maximumLongEdge: maximumLongEdge,
        context: context
      )
    else {
      return StickerSourceFidelityReport(
        assessment: StickerQualityAssessment(level: .rejected, issues: [.subjectMissing]),
        comparedCorePixelCount: 0,
        changedCorePixelRatio: 0
      )
    }

    let assessment: StickerQualityAssessment
    if measurement.comparedCorePixelCount == 0 {
      assessment = StickerQualityAssessment(level: .rejected, issues: [.subjectMissing])
    } else if measurement.changedCorePixelRatio > maximumChangedCorePixelRatio {
      assessment = StickerQualityAssessment(level: .rejected, issues: [.sourcePixelsChanged])
    } else {
      assessment = .acceptable
    }

    return StickerSourceFidelityReport(
      assessment: assessment,
      comparedCorePixelCount: measurement.comparedCorePixelCount,
      changedCorePixelRatio: measurement.changedCorePixelRatio
    )
  }

  private struct Measurement {
    let comparedCorePixelCount: Int
    let changedCorePixelRatio: Double

    init?(
      source: CIImage,
      subject: CIImage,
      mask: CIImage,
      maximumLongEdge: Int,
      context: CIContext
    ) {
      let extent =
        source.extent
        .intersection(subject.extent)
        .intersection(mask.extent)
        .integral
      guard !extent.isNull, !extent.isInfinite, extent.width > 0, extent.height > 0 else {
        return nil
      }

      let scale = min(
        1,
        CGFloat(maximumLongEdge) / max(extent.width, extent.height)
      )
      let width = max(1, Int((extent.width * scale).rounded(.down)))
      let height = max(1, Int((extent.height * scale).rounded(.down)))
      let bounds = CGRect(x: 0, y: 0, width: width, height: height)
      let translation = CGAffineTransform(
        translationX: -extent.minX,
        y: -extent.minY
      )
      let scaling = CGAffineTransform(scaleX: scale, y: scale)

      func normalized(_ image: CIImage) -> CIImage {
        image
          .cropped(to: extent)
          .transformed(by: translation)
          .transformed(by: scaling)
          .cropped(to: bounds)
      }

      let pixelCount = width * height
      var sourcePixels = [UInt8](repeating: 0, count: pixelCount * 4)
      var subjectPixels = [UInt8](repeating: 0, count: pixelCount * 4)
      var maskPixels = [UInt8](repeating: 0, count: pixelCount)
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)

      context.render(
        normalized(source),
        toBitmap: &sourcePixels,
        rowBytes: width * 4,
        bounds: bounds,
        format: .RGBA8,
        colorSpace: colorSpace
      )
      context.render(
        normalized(subject),
        toBitmap: &subjectPixels,
        rowBytes: width * 4,
        bounds: bounds,
        format: .RGBA8,
        colorSpace: colorSpace
      )
      context.render(
        normalized(mask),
        toBitmap: &maskPixels,
        rowBytes: width,
        bounds: bounds,
        format: .L8,
        colorSpace: CGColorSpaceCreateDeviceGray()
      )

      var compared = 0
      var changed = 0
      for index in 0..<pixelCount {
        let offset = index * 4
        let sourceAlpha = sourcePixels[offset + 3]
        let maskAlpha = maskPixels[index]
        guard
          sourceAlpha >= StickerSourceFidelityAssessor.coreAlphaThreshold,
          maskAlpha >= StickerSourceFidelityAssessor.coreAlphaThreshold
        else {
          continue
        }

        compared += 1
        let subjectAlpha = subjectPixels[offset + 3]
        let expectedAlpha = Int(sourceAlpha) * Int(maskAlpha) / 255
        guard
          abs(Int(subjectAlpha) - expectedAlpha)
            <= StickerSourceFidelityAssessor.maximumChannelDelta,
          subjectAlpha > 0
        else {
          changed += 1
          continue
        }

        var pixelChanged = false
        for channel in 0..<3 {
          let sourceChannel = Self.unpremultipliedChannel(
            sourcePixels[offset + channel],
            alpha: sourceAlpha
          )
          let subjectChannel = Self.unpremultipliedChannel(
            subjectPixels[offset + channel],
            alpha: subjectAlpha
          )
          if abs(sourceChannel - subjectChannel)
            > StickerSourceFidelityAssessor.maximumChannelDelta
          {
            pixelChanged = true
            break
          }
        }
        if pixelChanged {
          changed += 1
        }
      }

      comparedCorePixelCount = compared
      changedCorePixelRatio = Double(changed) / Double(max(compared, 1))
    }

    private static func unpremultipliedChannel(
      _ value: UInt8,
      alpha: UInt8
    ) -> Int {
      let scale = 255.0 / Double(alpha)
      return min(255, Int((Double(value) * scale).rounded()))
    }
  }
}
