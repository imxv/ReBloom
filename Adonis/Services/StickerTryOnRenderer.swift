import CoreImage
import UIKit
import Vision

enum StickerTryOnEligibility: Equatable, Sendable {
  case ready
  case needsCleanCatalogImage
  case unsupportedCategory

  static func evaluate(
    sourceKind: WardrobeSourceKind,
    cleanBackgroundScore: Double?,
    category: WardrobeCategory
  ) -> StickerTryOnEligibility {
    guard
      sourceKind == .catalogImage,
      (cleanBackgroundScore ?? 0) >= 0.72
    else {
      return .needsCleanCatalogImage
    }
    guard category == .top || category == .outerwear else {
      return .unsupportedCategory
    }
    return .ready
  }
}

struct StickerTryOnPose: Equatable, Sendable {
  let leftShoulder: CGPoint
  let rightShoulder: CGPoint
  let leftHip: CGPoint
  let rightHip: CGPoint
  let leftKnee: CGPoint?
  let rightKnee: CGPoint?
  let confidence: Double

  init(
    leftShoulder: CGPoint,
    rightShoulder: CGPoint,
    leftHip: CGPoint,
    rightHip: CGPoint,
    leftKnee: CGPoint? = nil,
    rightKnee: CGPoint? = nil,
    confidence: Double
  ) {
    self.leftShoulder = leftShoulder
    self.rightShoulder = rightShoulder
    self.leftHip = leftHip
    self.rightHip = rightHip
    self.leftKnee = leftKnee
    self.rightKnee = rightKnee
    self.confidence = min(max(confidence, 0), 1)
  }
}

struct StickerTryOnResult {
  let image: UIImage
  let elapsedMilliseconds: Int
  let garmentCoverage: Double
  let poseConfidence: Double
  let provenance: VisualContentProvenance
}

protocol StickerTryOnGenerating {
  var executionMetadata: CreativeExecutionMetadata { get }

  func generate(
    person: UIImage,
    garment: UIImage,
    category: WardrobeCategory
  ) async throws -> StickerTryOnResult
}

enum StickerTryOnGeneratorFactory {
  static func make(arguments: [String] = ProcessInfo.processInfo.arguments)
    -> any StickerTryOnGenerating
  {
    #if DEBUG
      if arguments.contains("-ui-testing-sticker-try-on") {
        return UITestStickerTryOnGenerator(arguments: arguments)
      }
    #endif
    return LiveStickerTryOnGenerator()
  }
}

private struct LiveStickerTryOnGenerator: StickerTryOnGenerating {
  let executionMetadata = CreativeExecutionMetadata.stickerTryOn

  func generate(
    person: UIImage,
    garment: UIImage,
    category: WardrobeCategory
  ) async throws -> StickerTryOnResult {
    let pose = try await StickerTryOnPoseDetector().detect(in: person)
    try Task.checkCancellation()
    return try await Task.detached(priority: .userInitiated) {
      try Task.checkCancellation()
      return try StickerTryOnRenderer().render(
        person: person,
        garment: garment,
        category: category,
        pose: pose
      )
    }.value
  }
}

#if DEBUG
  private struct UITestStickerTryOnGenerator: StickerTryOnGenerating {
    let arguments: [String]
    let executionMetadata = CreativeExecutionMetadata.uiTestFixture

    func generate(
      person: UIImage,
      garment: UIImage,
      category: WardrobeCategory
    ) async throws -> StickerTryOnResult {
      if arguments.contains("-ui-testing-sticker-try-on-never-finishes") {
        try await Task.sleep(for: .seconds(300))
      } else {
        try await Task.sleep(for: .milliseconds(1_500))
      }
      try Task.checkCancellation()
      let pose = StickerTryOnPose(
        leftShoulder: CGPoint(x: 0.438, y: 0.478),
        rightShoulder: CGPoint(x: 0.574, y: 0.478),
        leftHip: CGPoint(x: 0.455, y: 0.618),
        rightHip: CGPoint(x: 0.568, y: 0.618),
        leftKnee: CGPoint(x: 0.47, y: 0.82),
        rightKnee: CGPoint(x: 0.55, y: 0.82),
        confidence: 0.94
      )
      return try StickerTryOnRenderer().render(
        person: person,
        garment: garment,
        category: category,
        pose: pose
      )
    }
  }
#endif

struct StickerTryOnPoseDetector {
  func detect(in image: UIImage) async throws -> StickerTryOnPose {
    try Task.checkCancellation()
    guard
      let source = CIImage(
        image: image,
        options: [.applyOrientationProperty: true]
      )
    else {
      throw StickerTryOnError.personPoseUnclear
    }

    do {
      if #available(iOS 18.0, *) {
        return try await detectModern(in: source)
      }
      return try await detectLegacy(in: source)
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as StickerTryOnError {
      throw error
    } catch {
      throw StickerTryOnError.poseDetectionUnavailable
    }
  }

  @available(iOS 18.0, *)
  private func detectModern(in source: CIImage) async throws -> StickerTryOnPose {
    let request = DetectHumanBodyPoseRequest()
    let observations = try await request.perform(on: source)
    try Task.checkCancellation()
    guard let observation = observations.first else {
      throw StickerTryOnError.personPoseUnclear
    }

    let leftShoulder = try Self.requiredJoint(.leftShoulder, in: observation)
    let rightShoulder = try Self.requiredJoint(.rightShoulder, in: observation)
    let leftHip = try Self.requiredJoint(.leftHip, in: observation)
    let rightHip = try Self.requiredJoint(.rightHip, in: observation)
    let required = [leftShoulder, rightShoulder, leftHip, rightHip]
    let confidence = required.map(\.confidence).min() ?? 0

    return StickerTryOnPose(
      leftShoulder: leftShoulder.topLeftPoint,
      rightShoulder: rightShoulder.topLeftPoint,
      leftHip: leftHip.topLeftPoint,
      rightHip: rightHip.topLeftPoint,
      leftKnee: Self.optionalJoint(.leftKnee, in: observation),
      rightKnee: Self.optionalJoint(.rightKnee, in: observation),
      confidence: Double(confidence)
    )
  }

  private func detectLegacy(in source: CIImage) async throws -> StickerTryOnPose {
    try await Task.detached(priority: .userInitiated) {
      try Task.checkCancellation()

      let request = VNDetectHumanBodyPoseRequest()
      let handler = VNImageRequestHandler(ciImage: source, options: [:])
      try handler.perform([request])
      try Task.checkCancellation()
      guard let observation = request.results?.first else {
        throw StickerTryOnError.personPoseUnclear
      }

      let leftShoulder = try Self.requiredPoint(.leftShoulder, in: observation)
      let rightShoulder = try Self.requiredPoint(.rightShoulder, in: observation)
      let leftHip = try Self.requiredPoint(.leftHip, in: observation)
      let rightHip = try Self.requiredPoint(.rightHip, in: observation)
      let required = [leftShoulder, rightShoulder, leftHip, rightHip]
      let confidence = required.map(\.confidence).min() ?? 0

      return StickerTryOnPose(
        leftShoulder: leftShoulder.topLeftPoint,
        rightShoulder: rightShoulder.topLeftPoint,
        leftHip: leftHip.topLeftPoint,
        rightHip: rightHip.topLeftPoint,
        leftKnee: Self.optionalPoint(.leftKnee, in: observation),
        rightKnee: Self.optionalPoint(.rightKnee, in: observation),
        confidence: Double(confidence)
      )
    }.value
  }

  @available(iOS 18.0, *)
  private static func requiredJoint(
    _ jointName: HumanBodyPoseObservation.JointName,
    in observation: HumanBodyPoseObservation
  ) throws -> Joint {
    guard
      let joint = observation.joint(for: jointName),
      joint.confidence >= 0.35
    else {
      throw StickerTryOnError.personPoseUnclear
    }
    return joint
  }

  @available(iOS 18.0, *)
  private static func optionalJoint(
    _ jointName: HumanBodyPoseObservation.JointName,
    in observation: HumanBodyPoseObservation
  ) -> CGPoint? {
    guard
      let joint = observation.joint(for: jointName),
      joint.confidence >= 0.25
    else {
      return nil
    }
    return joint.topLeftPoint
  }

  private static func requiredPoint(
    _ joint: VNHumanBodyPoseObservation.JointName,
    in observation: VNHumanBodyPoseObservation
  ) throws -> VNRecognizedPoint {
    let point = try observation.recognizedPoint(joint)
    guard point.confidence >= 0.35 else {
      throw StickerTryOnError.personPoseUnclear
    }
    return point
  }

  private static func optionalPoint(
    _ joint: VNHumanBodyPoseObservation.JointName,
    in observation: VNHumanBodyPoseObservation
  ) -> CGPoint? {
    guard
      let point = try? observation.recognizedPoint(joint),
      point.confidence >= 0.25
    else {
      return nil
    }
    return point.topLeftPoint
  }
}

struct StickerTryOnRenderer {
  func render(
    person: UIImage,
    garment: UIImage,
    category: WardrobeCategory,
    pose: StickerTryOnPose
  ) throws -> StickerTryOnResult {
    let startedAt = ContinuousClock.now
    guard category == .top || category == .outerwear else {
      throw StickerTryOnError.unsupportedCategory
    }
    guard person.size.width >= 64, person.size.height >= 64 else {
      throw StickerTryOnError.personImageTooSmall
    }
    guard let garmentCutout = Self.makeGarmentCutout(from: garment) else {
      throw StickerTryOnError.garmentNotSeparated
    }

    let targetRect = try Self.targetRect(
      for: pose,
      category: category,
      canvasSize: person.size
    )
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    let output = UIGraphicsImageRenderer(size: person.size, format: format).image { _ in
      person.draw(in: CGRect(origin: .zero, size: person.size))
      Self.drawStickerizedGarment(garmentCutout, in: targetRect)
    }
    let elapsed = startedAt.duration(to: .now)
    let elapsedMilliseconds = max(
      0,
      Int(elapsed.components.seconds * 1_000)
        + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
    )
    let canvasArea = max(person.size.width * person.size.height, 1)

    return StickerTryOnResult(
      image: output,
      elapsedMilliseconds: elapsedMilliseconds,
      garmentCoverage: Double(targetRect.width * targetRect.height / canvasArea),
      poseConfidence: pose.confidence,
      provenance: .programmaticComposition
    )
  }

  private static func targetRect(
    for pose: StickerTryOnPose,
    category: WardrobeCategory,
    canvasSize: CGSize
  ) throws -> CGRect {
    let leftShoulder = pose.leftShoulder.scaled(to: canvasSize)
    let rightShoulder = pose.rightShoulder.scaled(to: canvasSize)
    let leftHip = pose.leftHip.scaled(to: canvasSize)
    let rightHip = pose.rightHip.scaled(to: canvasSize)
    let shoulderWidth = leftShoulder.distance(to: rightShoulder)
    let shoulderCenter = leftShoulder.midpoint(to: rightShoulder)
    let hipCenter = leftHip.midpoint(to: rightHip)
    let torsoHeight = shoulderCenter.distance(to: hipCenter)

    guard pose.confidence >= 0.35,
      shoulderWidth >= min(canvasSize.width, canvasSize.height) * 0.07,
      torsoHeight >= min(canvasSize.width, canvasSize.height) * 0.1
    else {
      throw StickerTryOnError.personPoseUnclear
    }

    let widthMultiplier: CGFloat = category == .outerwear ? 1.82 : 1.62
    let targetWidth = shoulderWidth * widthMultiplier
    let topY = min(leftShoulder.y, rightShoulder.y) - torsoHeight * 0.1
    let bottomY = max(leftHip.y, rightHip.y) + torsoHeight * 0.13
    let centerX = (shoulderCenter.x + hipCenter.x) / 2
    let unclipped = CGRect(
      x: centerX - targetWidth / 2,
      y: topY,
      width: targetWidth,
      height: max(bottomY - topY, targetWidth * 0.88)
    )
    let canvas = CGRect(origin: .zero, size: canvasSize)
    let clipped = unclipped.intersection(canvas)
    guard !clipped.isNull, clipped.width >= 32, clipped.height >= 32 else {
      throw StickerTryOnError.personPoseUnclear
    }
    return clipped.integral
  }

  private static func drawStickerizedGarment(_ image: UIImage, in targetRect: CGRect) {
    let outline = image.withTintColor(.white, renderingMode: .alwaysTemplate)
    let radius = max(3, min(targetRect.width, targetRect.height) * 0.024)
    for index in 0..<16 {
      let angle = CGFloat(index) / 16 * .pi * 2
      outline.draw(
        in: targetRect.offsetBy(
          dx: cos(angle) * radius,
          dy: sin(angle) * radius
        )
      )
    }
    image.draw(in: targetRect)
  }

  private static func makeGarmentCutout(from image: UIImage) -> UIImage? {
    let width = max(Int(image.size.width.rounded()), 1)
    let height = max(Int(image.size.height.rounded()), 1)
    guard width >= 32, height >= 32 else { return nil }

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
    context.interpolationQuality = .high
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    UIGraphicsPushContext(context)
    image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
    UIGraphicsPopContext()

    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1
    var visiblePixels = 0

    for y in 0..<height {
      for x in 0..<width {
        let offset = y * bytesPerRow + x * bytesPerPixel
        let red = Double(pixels[offset])
        let green = Double(pixels[offset + 1])
        let blue = Double(pixels[offset + 2])
        let originalAlpha = Double(pixels[offset + 3]) / 255
        let distanceFromWhite = sqrt(
          pow(255 - red, 2) + pow(255 - green, 2) + pow(255 - blue, 2)
        )
        let edgeAlpha = min(max((distanceFromWhite - 12) / 34, 0), 1)
        let alpha = originalAlpha * edgeAlpha
        pixels[offset] = UInt8((red * alpha).rounded())
        pixels[offset + 1] = UInt8((green * alpha).rounded())
        pixels[offset + 2] = UInt8((blue * alpha).rounded())
        pixels[offset + 3] = UInt8((255 * alpha).rounded())

        if alpha > 0.08 {
          visiblePixels += 1
          minX = min(minX, x)
          minY = min(minY, y)
          maxX = max(maxX, x)
          maxY = max(maxY, y)
        }
      }
    }

    guard visiblePixels >= width * height / 100,
      maxX >= minX,
      maxY >= minY,
      let fullImage = context.makeImage()
    else {
      return nil
    }

    let margin = max(2, min(width, height) / 100)
    let crop = CGRect(
      x: max(0, minX - margin),
      y: max(0, minY - margin),
      width: min(width - 1, maxX + margin) - max(0, minX - margin) + 1,
      height: min(height - 1, maxY + margin) - max(0, minY - margin) + 1
    )
    guard let cropped = fullImage.cropping(to: crop) else { return nil }
    return UIImage(cgImage: cropped, scale: 1, orientation: .up)
  }
}

enum StickerTryOnError: LocalizedError, Equatable {
  case unsupportedCategory
  case personImageTooSmall
  case poseDetectionUnavailable
  case personPoseUnclear
  case garmentNotSeparated
  case renderFailed

  var eventCode: String {
    switch self {
    case .unsupportedCategory: "unsupported_category"
    case .personImageTooSmall: "person_image_too_small"
    case .poseDetectionUnavailable: "pose_detection_unavailable"
    case .personPoseUnclear: "person_pose_unclear"
    case .garmentNotSeparated: "garment_not_separated"
    case .renderFailed: "render_failed"
    }
  }

  var errorDescription: String? {
    switch self {
    case .unsupportedCategory:
      "这件单品暂时不适合贴纸试搭，先试试上装或外套。"
    case .personImageTooSmall:
      "最近一次穿搭照片尺寸太小了，换一张更清楚的全身照再试。"
    case .poseDetectionUnavailable:
      "这台设备暂时无法读取人物姿态，原照片和衣橱都没有改变。"
    case .personPoseUnclear:
      "没有找到足够清楚的肩膀和腰部位置，换一张人物更完整的照片再试。"
    case .garmentNotSeparated:
      "这张衣物图的背景不够干净，补一张白底或平铺商品图再试。"
    case .renderFailed:
      "试搭草图没有生成成功，原照片和衣橱都没有改变。"
    }
  }
}

extension CGPoint {
  fileprivate func scaled(to size: CGSize) -> CGPoint {
    CGPoint(x: x * size.width, y: y * size.height)
  }

  fileprivate func distance(to other: CGPoint) -> CGFloat {
    hypot(x - other.x, y - other.y)
  }

  fileprivate func midpoint(to other: CGPoint) -> CGPoint {
    CGPoint(x: (x + other.x) / 2, y: (y + other.y) / 2)
  }
}

extension VNRecognizedPoint {
  fileprivate var topLeftPoint: CGPoint {
    CGPoint(x: location.x, y: 1 - location.y)
  }
}

@available(iOS 18.0, *)
extension Joint {
  fileprivate var topLeftPoint: CGPoint {
    CGPoint(x: location.x, y: 1 - location.y)
  }
}
