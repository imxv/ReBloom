import UIKit
import XCTest

@testable import Adonis

final class SampleRegressionTests: XCTestCase {
  func testBaselineManifestMatchesAuthorizedCatalog() throws {
    let manifest = try loadManifest()

    XCTAssertEqual(manifest.schemaVersion, 2)
    XCTAssertEqual(manifest.name, "adonis-authorized-sample-regression")
    XCTAssertEqual(manifest.authorization.kind, "user_provided")
    XCTAssertEqual(manifest.authorization.receivedOn, "2026-08-29")
    XCTAssertFalse(manifest.authorization.externalSocialPlatformImagesIncluded)
    XCTAssertEqual(manifest.processing.version, AdonisProcessingVersion.sticker)
    XCTAssertEqual(manifest.processing.generator, "scripts/generate_sample_stickers.swift")
    XCTAssertEqual(
      manifest.processing.platform,
      "macOS Vision VNGeneratePersonSegmentationRequest + Core Image"
    )
    XCTAssertEqual(manifest.processing.minimumLongEdgePixels, 1_536)
    XCTAssertEqual(manifest.samples.map(\.id), SampleCatalog.photos.map(\.id))

    let catalogByID = Dictionary(uniqueKeysWithValues: SampleCatalog.photos.map { ($0.id, $0) })
    for baseline in manifest.samples {
      let sample = try XCTUnwrap(catalogByID[baseline.id])
      XCTAssertEqual(baseline.source.resourceName, "\(sample.resourceName).png")
      XCTAssertEqual(baseline.sticker.resourceName, "\(sample.stickerResourceName).png")
      XCTAssertTrue(isSHA256(baseline.source.sha256), baseline.source.resourceName)
      XCTAssertTrue(isSHA256(baseline.sticker.sha256), baseline.sticker.resourceName)
      XCTAssertFalse(baseline.coverageTags.isEmpty, baseline.id)
      XCTAssertFalse(baseline.knownLimitations.isEmpty, baseline.id)
      XCTAssertEqual(
        baseline.preparedMatteAssessment.level,
        sample.preparedMatteAssessment.level.rawValue,
        baseline.id
      )
      XCTAssertEqual(
        baseline.preparedMatteAssessment.issues,
        sample.preparedMatteAssessment.issues.map(\.rawValue),
        baseline.id
      )
      XCTAssertEqual(
        baseline.showInShowcase,
        SampleCatalog.showcasePhotos.contains(sample),
        baseline.id
      )

      let source = try XCTUnwrap(sample.image())
      let sourceImage = try XCTUnwrap(source.cgImage)
      XCTAssertEqual(sourceImage.width, baseline.source.width, baseline.source.resourceName)
      XCTAssertEqual(sourceImage.height, baseline.source.height, baseline.source.resourceName)

      let sticker = try XCTUnwrap(sample.preparedStickerImage())
      let stickerImage = try XCTUnwrap(sticker.cgImage)
      XCTAssertEqual(stickerImage.width, baseline.sticker.width, baseline.sticker.resourceName)
      XCTAssertEqual(stickerImage.height, baseline.sticker.height, baseline.sticker.resourceName)
    }
  }

  func testPreparedStickerPixelsRemainWithinRecordedBaseline() throws {
    let manifest = try loadManifest()
    let catalogByID = Dictionary(uniqueKeysWithValues: SampleCatalog.photos.map { ($0.id, $0) })

    for baseline in manifest.samples {
      let sample = try XCTUnwrap(catalogByID[baseline.id])
      let sticker = try XCTUnwrap(sample.preparedStickerImage())
      let measurement = try StickerPixelMeasurement(image: sticker)
      let expected = baseline.sticker.metrics

      print("ADONIS_SAMPLE_METRICS \(baseline.id) \(measurement.logLine)")

      XCTAssertGreaterThan(measurement.transparentRatio, 0.1, baseline.id)
      XCTAssertGreaterThan(measurement.opaqueRatio, 0.05, baseline.id)
      XCTAssertGreaterThan(measurement.semiTransparentRatio, 0, baseline.id)
      XCTAssertGreaterThan(measurement.cornerTransparentRatio, 0.95, baseline.id)
      XCTAssertGreaterThan(measurement.largestComponentRatio, 0.95, baseline.id)
      XCTAssertGreaterThan(measurement.whiteBoundaryRatio, 0.5, baseline.id)
      XCTAssertGreaterThan(measurement.nonWhiteOpaqueRatio, 0.03, baseline.id)

      assertClose(measurement.transparentRatio, expected.transparentRatio, baseline.id)
      assertClose(measurement.opaqueRatio, expected.opaqueRatio, baseline.id)
      assertClose(measurement.semiTransparentRatio, expected.semiTransparentRatio, baseline.id)
      assertClose(
        measurement.cornerTransparentRatio,
        expected.cornerTransparentRatio,
        baseline.id
      )
      assertClose(
        measurement.largestComponentRatio,
        expected.largestComponentRatio,
        baseline.id
      )
      assertClose(measurement.whiteBoundaryRatio, expected.whiteBoundaryRatio, baseline.id)
      assertClose(measurement.nonWhiteOpaqueRatio, expected.nonWhiteOpaqueRatio, baseline.id)
    }
  }

  func testEveryShowcaseStickerRendersAnOpaqueShareCard() throws {
    let fixedDate = try XCTUnwrap(
      Calendar(identifier: .gregorian).date(
        from: DateComponents(year: 2026, month: 8, day: 29)
      )
    )

    for (index, sample) in SampleCatalog.showcasePhotos.enumerated() {
      let sticker = try XCTUnwrap(sample.preparedStickerImage())
      let card = ShareCardRenderer().render(
        sticker: sticker,
        bloomNumber: index + 1,
        date: fixedDate
      )
      let cardImage = try XCTUnwrap(card.cgImage)
      let measurement = try StickerPixelMeasurement(image: card)

      XCTAssertEqual(cardImage.width, 1_080, sample.id)
      XCTAssertEqual(cardImage.height, 1_440, sample.id)
      XCTAssertEqual(measurement.transparentRatio, 0, accuracy: 0.000_001, sample.id)
      XCTAssertEqual(measurement.semiTransparentRatio, 0, accuracy: 0.000_001, sample.id)

      let attachment = XCTAttachment(image: card)
      attachment.name = "\(sample.id)-share-card"
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }

  private func loadManifest() throws -> RegressionBaselineManifest {
    let url = try XCTUnwrap(
      Bundle.main.url(forResource: "regression-baseline", withExtension: "json")
    )
    return try JSONDecoder().decode(RegressionBaselineManifest.self, from: Data(contentsOf: url))
  }

  private func isSHA256(_ value: String) -> Bool {
    value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) }
  }

  private func assertClose(
    _ actual: Double,
    _ expected: Double,
    _ sampleID: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(actual, expected, accuracy: 0.002, sampleID, file: file, line: line)
  }
}

private struct RegressionBaselineManifest: Decodable {
  let schemaVersion: Int
  let name: String
  let authorization: Authorization
  let processing: Processing
  let samples: [Sample]

  struct Authorization: Decodable {
    let kind: String
    let receivedOn: String
    let externalSocialPlatformImagesIncluded: Bool
  }

  struct Processing: Decodable {
    let version: String
    let generator: String
    let platform: String
    let minimumLongEdgePixels: Int
  }

  struct Sample: Decodable {
    let id: String
    let source: SourceAsset
    let sticker: StickerAsset
    let coverageTags: [String]
    let knownLimitations: [String]
    let preparedMatteAssessment: PreparedMatteAssessment
    let showInShowcase: Bool
  }

  struct PreparedMatteAssessment: Decodable {
    let level: String
    let issues: [String]
  }

  struct SourceAsset: Decodable {
    let resourceName: String
    let sha256: String
    let width: Int
    let height: Int
  }

  struct StickerAsset: Decodable {
    let resourceName: String
    let sha256: String
    let width: Int
    let height: Int
    let metrics: Metrics
  }

  struct Metrics: Decodable {
    let transparentRatio: Double
    let opaqueRatio: Double
    let semiTransparentRatio: Double
    let cornerTransparentRatio: Double
    let largestComponentRatio: Double
    let whiteBoundaryRatio: Double
    let nonWhiteOpaqueRatio: Double
  }
}

private struct StickerPixelMeasurement {
  let transparentRatio: Double
  let opaqueRatio: Double
  let semiTransparentRatio: Double
  let cornerTransparentRatio: Double
  let largestComponentRatio: Double
  let whiteBoundaryRatio: Double
  let nonWhiteOpaqueRatio: Double

  var logLine: String {
    String(
      format:
        "transparent=%.6f opaque=%.6f semi=%.6f corners=%.6f component=%.6f boundaryWhite=%.6f nonWhiteOpaque=%.6f",
      transparentRatio,
      opaqueRatio,
      semiTransparentRatio,
      cornerTransparentRatio,
      largestComponentRatio,
      whiteBoundaryRatio,
      nonWhiteOpaqueRatio
    )
  }

  init(image: UIImage) throws {
    let cgImage = try XCTUnwrap(image.cgImage)
    let width = cgImage.width
    let height = cgImage.height
    let pixelCount = max(width * height, 1)
    let bytesPerRow = width * 4
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
      )
    )
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    func alpha(at index: Int) -> UInt8 {
      pixels[index * 4 + 3]
    }

    var transparent = 0
    var opaque = 0
    var visible = 0
    var boundary = 0
    var whiteBoundary = 0
    var nonWhiteOpaque = 0

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
    var cornerTransparent = 0
    var cornerPixels = 0
    let starts = [
      (0, 0),
      (width - cornerLength, 0),
      (0, height - cornerLength),
      (width - cornerLength, height - cornerLength),
    ]
    for (startX, startY) in starts {
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
