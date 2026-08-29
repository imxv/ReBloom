import Foundation

enum StickerQualityLevel: String, Codable, Sendable {
  case acceptable
  case reviewRecommended = "review_recommended"
  case rejected
}

enum StickerQualityIssue: String, Codable, CaseIterable, Sendable {
  case backgroundNotSeparated = "background_not_separated"
  case subjectMissing = "subject_missing"
  case subjectFragmented = "subject_fragmented"
  case edgeMayIncludeBackground = "edge_may_include_background"
  case outlineMayBeBroken = "outline_may_be_broken"
  case subjectTooSmall = "subject_too_small"
}

struct StickerQualityAssessment: Codable, Equatable, Sendable {
  static let acceptable = StickerQualityAssessment(level: .acceptable, issues: [])

  let level: StickerQualityLevel
  let issues: [StickerQualityIssue]

  init(level: StickerQualityLevel, issues: [StickerQualityIssue]) {
    self.level = level
    self.issues = issues.reduce(into: []) { uniqueIssues, issue in
      if !uniqueIssues.contains(issue) {
        uniqueIssues.append(issue)
      }
    }
  }

  init(levelRawValue: String, issueRawValues: String) {
    let decodedIssues =
      issueRawValues
      .split(separator: ",")
      .compactMap { StickerQualityIssue(rawValue: String($0)) }
    self.init(
      level: StickerQualityLevel(rawValue: levelRawValue) ?? .acceptable,
      issues: decodedIssues
    )
  }

  var requiresReview: Bool { level == .reviewRecommended }
  var isRejected: Bool { level == .rejected }
  var issueRawValues: String { issues.map(\.rawValue).joined(separator: ",") }

  var userTitle: String {
    switch level {
    case .acceptable: "贴纸边缘看起来正常"
    case .reviewRecommended: "这张边缘可能不够干净"
    case .rejected: "这张还不适合做成贴纸"
    }
  }

  var userDetail: String {
    if issues.contains(.subjectTooSmall) {
      return "人物在画面里有点小。先看看透明贴纸，不满意就点“再做一张”，换一张人物更近、更清楚的照片。"
    }
    if issues.contains(.outlineMayBeBroken) || issues.contains(.subjectFragmented) {
      return "有些轮廓可能没有完整连起来。先看看透明贴纸，不满意就点“再做一张”换一张照片。"
    }
    if issues.contains(.edgeMayIncludeBackground)
      || issues.contains(.backgroundNotSeparated)
    {
      return "人物旁边可能带进了一小块背景。先看看透明贴纸，不满意就点“再做一张”，换一张人物与背景更分开的照片。"
    }
    return "先看看透明贴纸；不满意可以直接换一张，原始照片不会被修改。"
  }

  var eventDetail: String {
    "level=\(level.rawValue);issues=\(issueRawValues)"
  }
}
