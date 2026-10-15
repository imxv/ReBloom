import UIKit

struct SamplePhoto: Identifiable, Hashable {
  let id: String
  let resourceName: String
  let stickerResourceName: String
  let homepageAISourceResourceName: String?
  let homepageAIStickerResourceName: String?
  let title: String
  let subtitle: String
  /// Human-reviewed quality of the prepared regression matte.
  let preparedMatteAssessment: StickerQualityAssessment

  init(
    id: String,
    resourceName: String,
    stickerResourceName: String,
    homepageAISourceResourceName: String? = nil,
    homepageAIStickerResourceName: String? = nil,
    title: String,
    subtitle: String,
    preparedMatteAssessment: StickerQualityAssessment
  ) {
    self.id = id
    self.resourceName = resourceName
    self.stickerResourceName = stickerResourceName
    self.homepageAISourceResourceName = homepageAISourceResourceName
    self.homepageAIStickerResourceName = homepageAIStickerResourceName
    self.title = title
    self.subtitle = subtitle
    self.preparedMatteAssessment = preparedMatteAssessment
  }

  func image() -> UIImage? {
    guard let url = Bundle.main.url(forResource: resourceName, withExtension: "png") else {
      return nil
    }
    return UIImage(contentsOfFile: url.path)
  }

  func preparedStickerImage() -> UIImage? {
    bundledImage(named: stickerResourceName)
  }

  func homepageAISourceImage() -> UIImage? {
    homepageAISourceResourceName.flatMap(bundledImage(named:))
  }

  func homepageAIStickerImage() -> UIImage? {
    homepageAIStickerResourceName.flatMap(bundledImage(named:))
  }

  var homepageProvenance: VisualContentProvenance {
    homepageAIStickerResourceName == nil ? .derivedFromOriginal : .aiGenerated
  }

  private func bundledImage(named name: String) -> UIImage? {
    guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
      return nil
    }
    return UIImage(contentsOfFile: url.path)
  }
}

enum SampleCatalog {
  static let photos: [SamplePhoto] = [
    SamplePhoto(
      id: "sample-01", resourceName: "sample-01", stickerResourceName: "sample-01-sticker",
      homepageAISourceResourceName: "sample-01-ai-source",
      homepageAIStickerResourceName: "sample-01-ai-sticker",
      title: "甜酷街角", subtitle: "浅色穿搭 · 手持物",
      preparedMatteAssessment: .acceptable),
    SamplePhoto(
      id: "sample-02", resourceName: "sample-02", stickerResourceName: "sample-02-sticker",
      homepageAISourceResourceName: "sample-02-ai-source",
      homepageAIStickerResourceName: "sample-02-ai-sticker",
      title: "黑白极简", subtitle: "全身 · 大面积留白",
      preparedMatteAssessment: .acceptable),
    SamplePhoto(
      id: "sample-03", resourceName: "sample-03", stickerResourceName: "sample-03-sticker",
      homepageAISourceResourceName: "sample-03-ai-source",
      homepageAIStickerResourceName: "sample-03-ai-sticker",
      title: "面包店散步", subtitle: "复杂背景 · 宽松裤装",
      preparedMatteAssessment: .acceptable),
    SamplePhoto(
      id: "sample-04", resourceName: "sample-04", stickerResourceName: "sample-04-sticker",
      title: "夜色机能", subtitle: "坐姿 · 深色边缘",
      preparedMatteAssessment: StickerQualityAssessment(
        level: .rejected,
        issues: [.backgroundAdhesionSuspected]
      )),
  ]

  static let showcasePhotos = photos.filter { !$0.preparedMatteAssessment.isRejected }
  static let homepagePhotos = showcasePhotos.filter { $0.homepageAIStickerResourceName != nil }
}
