import Foundation

enum StickerQualityLevel: String, Codable, Hashable, Sendable {
  case acceptable
  case reviewRecommended = "review_recommended"
  case rejected
}

enum StickerQualityIssue: String, Codable, CaseIterable, Hashable, Sendable {
  case backgroundNotSeparated = "background_not_separated"
  case backgroundAdhesionSuspected = "background_adhesion_suspected"
  case subjectMissing = "subject_missing"
  case subjectFragmented = "subject_fragmented"
  case edgeMayIncludeBackground = "edge_may_include_background"
  case outlineMayBeBroken = "outline_may_be_broken"
  case subjectTooSmall = "subject_too_small"
}

struct StickerQualityAssessment: Codable, Equatable, Hashable, Sendable {
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
    if isRejected {
      if issues.contains(.backgroundAdhesionSuspected) {
        return "人物旁边带进了较大块背景，这张不会继续做成收藏卡。换一张人物与家具、墙面更分开的照片吧。"
      }
      if issues.contains(.subjectMissing) {
        return "没有找到足够完整的人物，这张不会继续做成收藏卡。换一张人物更清楚、身体更完整的照片吧。"
      }
      if issues.contains(.subjectFragmented) || issues.contains(.outlineMayBeBroken) {
        return "人物轮廓没有完整连起来，这张不会继续做成收藏卡。换一张人物遮挡更少、与背景更分开的照片吧。"
      }
      if issues.contains(.backgroundNotSeparated) || issues.contains(.edgeMayIncludeBackground) {
        return "人物和背景没有分开，这张不会继续做成收藏卡。换一张人物与背景颜色更分开、四周更干净的照片吧。"
      }
      return "这张还没有得到完整的人物贴纸，不会继续做成收藏卡。换一张人物更清楚、背景更干净的照片吧。"
    }
    if issues.contains(.subjectTooSmall) {
      return "人物在画面里有点小。先看看透明贴纸，不满意就点“再做一张”，换一张人物更近、更清楚的照片。"
    }
    if issues.contains(.outlineMayBeBroken) || issues.contains(.subjectFragmented) {
      return "有些轮廓可能没有完整连起来。先看看透明贴纸，不满意就点“再做一张”换一张照片。"
    }
    if issues.contains(.edgeMayIncludeBackground)
      || issues.contains(.backgroundAdhesionSuspected)
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
