import Foundation
import SwiftData

@Model
final class AppEvent {
  @Attribute(.unique) var id: UUID
  var createdAt: Date
  var kindRawValue: String
  var durationMilliseconds: Int?
  var detail: String?

  var kind: AppEventKind {
    AppEventKind(rawValue: kindRawValue) ?? .unknown
  }

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    kind: AppEventKind,
    durationMilliseconds: Int? = nil,
    detail: String? = nil
  ) {
    self.id = id
    self.createdAt = createdAt
    self.kindRawValue = kind.rawValue
    self.durationMilliseconds = durationMilliseconds
    self.detail = detail
  }
}

enum AppEventKind: String {
  case generationStarted
  case generationSucceeded
  case generationFailed
  case generationCancelled
  case outfitSaved
  case outfitDeleted
  case wardrobeItemAdded
  case wardrobeItemDeleted
  case unknown

  var title: String {
    switch self {
    case .generationStarted: "开始处理"
    case .generationSucceeded: "处理成功"
    case .generationFailed: "处理失败"
    case .generationCancelled: "取消处理"
    case .outfitSaved: "保存穿搭"
    case .outfitDeleted: "删除穿搭"
    case .wardrobeItemAdded: "添加单品"
    case .wardrobeItemDeleted: "删除单品"
    case .unknown: "未知事件"
    }
  }
}
