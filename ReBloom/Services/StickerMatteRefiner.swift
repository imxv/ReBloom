import CoreImage

struct StickerMatteRefinementResult {
  let mask: CIImage
  let subject: CIImage
}

struct StickerMatteRefiner {
  static func extractSubject(
    source: CIImage,
    coarseMask: CIImage
  ) -> StickerMatteRefinementResult {
    let mask = refine(source: source, coarseMask: coarseMask)
    let clear = CIImage(color: .clear).cropped(to: source.extent)
    let subject = source.applyingFilter(
      "CIBlendWithMask",
      parameters: [
        kCIInputBackgroundImageKey: clear,
        kCIInputMaskImageKey: mask,
      ]
    ).cropped(to: source.extent)
    return StickerMatteRefinementResult(mask: mask, subject: subject)
  }

  static func refine(source: CIImage, coarseMask: CIImage) -> CIImage {
    let sourceExtent = source.extent.integral
    let maskExtent = coarseMask.extent.integral
    guard sourceExtent.width > 0, sourceExtent.height > 0,
      maskExtent.width > 0, maskExtent.height > 0
    else {
      return coarseMask
    }

    let normalizedSource = source.transformed(
      by: CGAffineTransform(
        translationX: -sourceExtent.minX,
        y: -sourceExtent.minY
      ))
    let normalizedMask = coarseMask.transformed(
      by: CGAffineTransform(
        translationX: -maskExtent.minX,
        y: -maskExtent.minY
      ))
    let normalizedSourceExtent = CGRect(
      origin: .zero,
      size: sourceExtent.size
    ).integral
    let scaledMask =
      normalizedMask
      .transformed(
        by: CGAffineTransform(
          scaleX: sourceExtent.width / maskExtent.width,
          y: sourceExtent.height / maskExtent.height
        )
      )
      .cropped(to: normalizedSourceExtent)

    guard let filter = CIFilter(name: "CIEdgePreserveUpsampleFilter") else {
      return restoreOrigin(of: scaledMask, to: sourceExtent)
    }
    filter.setValue(normalizedSource, forKey: kCIInputImageKey)
    filter.setValue(normalizedMask, forKey: "inputSmallImage")
    filter.setValue(3, forKey: "inputSpatialSigma")
    filter.setValue(0.15, forKey: "inputLumaSigma")

    let refined = (filter.outputImage ?? scaledMask)
      .cropped(to: normalizedSourceExtent)
    let constrained = constrainToTrimap(
      refined: refined,
      scaledCoarseMask: scaledMask,
      extent: normalizedSourceExtent
    )
    return restoreOrigin(of: constrained, to: sourceExtent)
  }

  private static func constrainToTrimap(
    refined: CIImage,
    scaledCoarseMask: CIImage,
    extent: CGRect
  ) -> CIImage {
    let definiteForeground = scaledCoarseMask.applyingFilter(
      "CIColorThreshold",
      parameters: ["inputThreshold": 0.99]
    )
    let possibleForeground = scaledCoarseMask.applyingFilter(
      "CIColorThreshold",
      parameters: ["inputThreshold": 0.01]
    )
    let black = CIImage(color: .black).cropped(to: extent)
    let white = CIImage(color: .white).cropped(to: extent)
    let bounded = refined.applyingFilter(
      "CIBlendWithMask",
      parameters: [
        kCIInputBackgroundImageKey: black,
        kCIInputMaskImageKey: possibleForeground,
      ]
    )
    return white.applyingFilter(
      "CIBlendWithMask",
      parameters: [
        kCIInputBackgroundImageKey: bounded,
        kCIInputMaskImageKey: definiteForeground,
      ]
    ).cropped(to: extent)
  }

  private static func restoreOrigin(of image: CIImage, to extent: CGRect) -> CIImage {
    image
      .transformed(
        by: CGAffineTransform(
          translationX: extent.minX,
          y: extent.minY
        )
      )
      .cropped(to: extent)
  }
}
