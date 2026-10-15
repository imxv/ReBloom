import Foundation

enum StickerFidelityVerdict: String, Codable, Sendable {
  case matches
  case changed
}

enum StickerFidelityIssue: String, CaseIterable, Codable, Sendable {
  case face
  case hair
  case bodyProportions = "body_proportions"
  case pose
  case clothing
  case shoesBagsAccessories = "shoes_bags_accessories"
  case missingOrExtraContent = "missing_or_extra_content"

  var title: String {
    switch self {
    case .face: "脸"
    case .hair: "发型"
    case .bodyProportions: "身形比例"
    case .pose: "姿势"
    case .clothing: "衣服"
    case .shoesBagsAccessories: "鞋包配饰"
    case .missingOrExtraContent: "画面有缺失或多余内容"
    }
  }

  var symbol: String {
    switch self {
    case .face: "face.smiling"
    case .hair: "person.crop.circle"
    case .bodyProportions: "figure.stand"
    case .pose: "figure.walk"
    case .clothing: "tshirt"
    case .shoesBagsAccessories: "handbag"
    case .missingOrExtraContent: "photo.badge.exclamationmark"
    }
  }
}

struct StickerFidelityReview: Codable, Equatable, Sendable {
  static let version = "sticker-fidelity-review-v1"

  static func canReview(
    stickerProvenance: VisualContentProvenance,
    hasAIStickerSource: Bool
  ) -> Bool {
    stickerProvenance.containsAIGeneratedPixels && hasAIStickerSource
  }

  let verdict: StickerFidelityVerdict
  let issues: [StickerFidelityIssue]
  let reviewedAt: Date

  init(
    verdict: StickerFidelityVerdict,
    issues: [StickerFidelityIssue] = [],
    reviewedAt: Date = .now
  ) {
    self.verdict = verdict
    self.issues = verdict == .matches ? [] : Self.stableUniqueIssues(issues)
    self.reviewedAt = reviewedAt
  }

  var summary: String {
    switch verdict {
    case .matches:
      "你觉得人物和穿搭都像原图"
    case .changed:
      if issues.isEmpty {
        "你觉得有些地方变了"
      } else {
        "你标记了：\(issues.map(\.title).joined(separator: "、"))"
      }
    }
  }

  var eventDetail: String {
    let issueValue = issues.isEmpty ? "none" : issues.map(\.rawValue).joined(separator: ",")
    return "verdict=\(verdict.rawValue);issues=\(issueValue);review_version=\(Self.version)"
  }

  private static func stableUniqueIssues(
    _ issues: [StickerFidelityIssue]
  ) -> [StickerFidelityIssue] {
    let selected = Set(issues)
    return StickerFidelityIssue.allCases.filter(selected.contains)
  }
}
