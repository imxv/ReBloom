import UIKit

struct SamplePhoto: Identifiable, Hashable {
  let id: String
  let resourceName: String
  let stickerResourceName: String
  let title: String
  let subtitle: String
  /// Human-reviewed quality of the prepared regression matte.
  let preparedMatteAssessment: StickerQualityAssessment

  func image() -> UIImage? {
    guard let url = Bundle.main.url(forResource: resourceName, withExtension: "png") else {
      return nil
    }
    return UIImage(contentsOfFile: url.path)
  }

  func preparedStickerImage() -> UIImage? {
    guard
      let url = Bundle.main.url(
        forResource: stickerResourceName,
        withExtension: "png"
      )
    else {
      return nil
    }
    return UIImage(contentsOfFile: url.path)
  }
}

enum SampleCatalog {
  static let photos: [SamplePhoto] = [
    SamplePhoto(
      id: "sample-01", resourceName: "sample-01", stickerResourceName: "sample-01-sticker",
      title: "甜酷街角", subtitle: "浅色穿搭 · 手持物",
      preparedMatteAssessment: .acceptable),
    SamplePhoto(
      id: "sample-02", resourceName: "sample-02", stickerResourceName: "sample-02-sticker",
      title: "黑白极简", subtitle: "全身 · 大面积留白",
      preparedMatteAssessment: .acceptable),
    SamplePhoto(
      id: "sample-03", resourceName: "sample-03", stickerResourceName: "sample-03-sticker",
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
}
