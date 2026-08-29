import XCTest

@testable import Adonis

final class StickerProcessorTests: XCTestCase {
  func testLiveProcessorUsesRealVisionOrReportsKnownSimulatorBoundary() async throws {
    #if targetEnvironment(simulator)
      let sample = try XCTUnwrap(SampleCatalog.photos.first)
      let source = try XCTUnwrap(sample.image(), "无法读取 \(sample.resourceName)")

      do {
        let result = try await StickerProcessor().process(source)
        try assertShareReadySticker(result.image, sampleName: sample.resourceName)
      } catch let error as StickerProcessingError {
        guard case .simulatorVisionUnavailable = error else {
          return XCTFail("模拟器应真实生成贴纸或报告 Vision 能力边界，实际为 \(error)")
        }
      }
    #else
      for sample in SampleCatalog.photos {
        let source = try XCTUnwrap(sample.image(), "无法读取 \(sample.resourceName)")
        let result = try await StickerProcessor().process(source)
        try assertShareReadySticker(result.image, sampleName: sample.resourceName)
      }
    #endif
  }

  func testAllBundledPreparedSamplesProduceRealTransparency() throws {
    for sample in SampleCatalog.photos {
      let source = try XCTUnwrap(sample.image(), "无法读取 \(sample.resourceName)")
      let sticker = try XCTUnwrap(
        sample.preparedStickerImage(),
        "无法读取 \(sample.stickerResourceName)"
      )
      let alpha = try alphaStatistics(of: sticker)

      XCTAssertGreaterThan(sticker.size.width, 100, sample.resourceName)
      XCTAssertGreaterThan(sticker.size.height, 100, sample.resourceName)
      XCTAssertGreaterThanOrEqual(
        max(sticker.size.width, sticker.size.height),
        1_536,
        "\(sample.resourceName) 未达到独立分享的长边规格"
      )
      XCTAssertGreaterThan(
        alpha.transparentRatio,
        0.1,
        "\(sample.resourceName) 的透明区域不足，仍像完整背景矩形"
      )
      XCTAssertGreaterThan(alpha.opaqueRatio, 0.05, "\(sample.resourceName) 没有可见主体")
      XCTAssertTrue(hasAlphaChannel(sticker), "\(sample.resourceName) 没有 Alpha 通道")
      XCTAssertEqual(source.size, CGSize(width: 1_080, height: 1_440))
    }
  }

  func testTinyImageFailsBeforeSegmentation() async {
    let tinyImage = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
      UIColor.systemPink.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
    }

    do {
      _ = try await StickerProcessor().process(tinyImage)
      XCTFail("小尺寸图片不应生成贴纸")
    } catch let error as StickerProcessingError {
      guard case .imageTooSmall = error else {
        return XCTFail("预期 imageTooSmall，实际为 \(error)")
      }
    } catch {
      XCTFail("出现了错误类型之外的异常：\(error)")
    }
  }

  private func hasAlphaChannel(_ image: UIImage) -> Bool {
    guard let alphaInfo = image.cgImage?.alphaInfo else { return false }
    return [.first, .last, .premultipliedFirst, .premultipliedLast].contains(alphaInfo)
  }

  private func assertShareReadySticker(_ image: UIImage, sampleName: String) throws {
    let alpha = try alphaStatistics(of: image)

    XCTAssertGreaterThanOrEqual(
      max(image.size.width, image.size.height),
      1_536,
      "\(sampleName) 实时输出未达到独立分享规格"
    )
    XCTAssertGreaterThan(
      alpha.transparentRatio,
      0.1,
      "\(sampleName) 实时输出仍像完整背景矩形"
    )
    XCTAssertGreaterThan(alpha.opaqueRatio, 0.05, "\(sampleName) 实时输出没有可见主体")
  }

  private func alphaStatistics(of image: UIImage) throws -> (
    transparentRatio: Double, opaqueRatio: Double
  ) {
    let cgImage = try XCTUnwrap(image.cgImage)
    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

    let context = try XCTUnwrap(
      CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          | CGBitmapInfo.byteOrder32Big.rawValue
      ))
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    var transparent = 0
    var opaque = 0
    for index in stride(from: 3, to: pixels.count, by: 4) {
      let alpha = pixels[index]
      if alpha < 8 { transparent += 1 }
      if alpha > 247 { opaque += 1 }
    }

    let pixelCount = Double(max(width * height, 1))
    return (Double(transparent) / pixelCount, Double(opaque) / pixelCount)
  }
}
