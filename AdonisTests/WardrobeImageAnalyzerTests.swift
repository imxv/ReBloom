import XCTest

@testable import Adonis

final class WardrobeImageAnalyzerTests: XCTestCase {
  func testCleanWhiteBackgroundExtractsCatalogSourceAndGarmentColor() async throws {
    let image = makeImage(size: CGSize(width: 180, height: 240)) { context in
      UIColor.white.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 180, height: 240))
      UIColor(red: 0.42, green: 0.24, blue: 0.12, alpha: 1).setFill()
      context.fill(CGRect(x: 45, y: 42, width: 90, height: 156))
    }

    let analysis = try await WardrobeImageAnalyzer().analyze(data: try XCTUnwrap(image.pngData()))

    XCTAssertEqual(analysis.sourceKind, .catalogImage)
    XCTAssertEqual(analysis.dominantColorName, "棕色")
    XCTAssertEqual(analysis.suggestedName, "棕色单品")
    XCTAssertGreaterThan(analysis.cleanBackgroundScore, 0.65)
    XCTAssertEqual(analysis.imageWidth, 180)
    XCTAssertEqual(analysis.imageHeight, 240)
    XCTAssertEqual(analysis.imageFingerprint.count, 64)
    XCTAssertNotNil(analysis.visualSignatureRawValue)
    XCTAssertEqual(analysis.analysisVersion, AdonisProcessingVersion.wardrobeAnalysis)
  }

  func testFullFramePhotoUsesFlatLaySourceWithoutInventingCategory() async throws {
    let image = makeImage(size: CGSize(width: 120, height: 160)) { context in
      UIColor(red: 0.18, green: 0.62, blue: 0.25, alpha: 1).setFill()
      context.fill(CGRect(x: 0, y: 0, width: 120, height: 160))
    }

    let analysis = try await WardrobeImageAnalyzer().analyze(data: try XCTUnwrap(image.pngData()))

    XCTAssertEqual(analysis.sourceKind, .flatLay)
    XCTAssertEqual(analysis.dominantColorName, "绿色")
    XCTAssertEqual(analysis.suggestedCategory, nil)
    XCTAssertEqual(analysis.automaticallyAssignedCategory, .uncategorized)
  }

  func testCategoryMappingPicksHighestSupportedClothingLabel() throws {
    let result = WardrobeImageAnalyzer.categorySuggestion(for: [
      (identifier: "tabby cat", confidence: 0.96),
      (identifier: "trench coat", confidence: 0.81),
      (identifier: "running shoe", confidence: 0.55),
    ])

    XCTAssertEqual(try XCTUnwrap(result).category, .outerwear)
    XCTAssertEqual(try XCTUnwrap(result).confidence, 0.81, accuracy: 0.001)
  }

  func testLowConfidenceSuggestionRemainsUncategorized() {
    let analysis = WardrobeImageAnalysis(
      sourceKind: .catalogImage,
      dominantColorName: "蓝色",
      dominantColorHex: "#2040A0",
      suggestedCategory: .top,
      categoryConfidence: 0.61,
      cleanBackgroundScore: 0.9,
      imageWidth: 100,
      imageHeight: 160,
      imageFingerprint: String(repeating: "a", count: 64),
      visualSignatureRawValue: nil,
      processingMilliseconds: 8,
      analysisVersion: AdonisProcessingVersion.wardrobeAnalysis
    )

    XCTAssertEqual(analysis.automaticallyAssignedCategory, .uncategorized)
    XCTAssertEqual(analysis.suggestedName, "蓝色单品")
  }

  func testUnreadableImageDataFailsClearly() async {
    do {
      _ = try await WardrobeImageAnalyzer().analyze(data: Data("not-an-image".utf8))
      XCTFail("无效图片数据不应通过分析")
    } catch let error as WardrobeImageAnalysisError {
      guard case .unreadableImage = error else {
        return XCTFail("预期 unreadableImage，实际为 \(error)")
      }
    } catch {
      XCTFail("出现了错误类型之外的异常：\(error)")
    }
  }

  private func makeImage(
    size: CGSize,
    drawing: (UIGraphicsImageRendererContext) -> Void
  ) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).image(actions: drawing)
  }
}
