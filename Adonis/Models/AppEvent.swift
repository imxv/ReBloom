import Foundation
import SwiftData

@Model
final class AppEvent {
  @Attribute(.unique) var id: UUID
  var createdAt: Date
  var kindRawValue: String
  var durationMilliseconds: Int?
  var detail: String?
  var inputSourceRawValue: String?
  var processingVersion: String?

  var kind: AppEventKind {
    AppEventKind(rawValue: kindRawValue) ?? .unknown
  }

  var inputSource: EventInputSource? {
    guard let inputSourceRawValue else { return nil }
    return EventInputSource(rawValue: inputSourceRawValue)
  }

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    kind: AppEventKind,
    durationMilliseconds: Int? = nil,
    detail: String? = nil,
    inputSource: EventInputSource? = nil,
    processingVersion: String? = nil
  ) {
    self.id = id
    self.createdAt = createdAt
    self.kindRawValue = kind.rawValue
    self.durationMilliseconds = durationMilliseconds
    self.detail = detail
    self.inputSourceRawValue = inputSource?.rawValue
    self.processingVersion = processingVersion
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
  case wardrobeItemCorrected
  case wardrobeItemReused
  case wardrobeImportStarted
  case wardrobeImportFailed
  case wardrobeImportCancelled
  case wardrobeImageUpgradeStarted
  case wardrobeImageUpgradeSucceeded
  case wardrobeImageUpgradeFailed
  case garmentObservationsCreated
  case garmentObservationLinked
  case garmentObservationRejected
  case garmentObservationDismissed
  case garmentObservationCreatedItem
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
    case .wardrobeItemCorrected: "纠正单品"
    case .wardrobeItemReused: "找到已有单品"
    case .wardrobeImportStarted: "开始识别单品"
    case .wardrobeImportFailed: "单品识别失败"
    case .wardrobeImportCancelled: "取消识别单品"
    case .wardrobeImageUpgradeStarted: "开始补充商品图"
    case .wardrobeImageUpgradeSucceeded: "商品图更新成功"
    case .wardrobeImageUpgradeFailed: "商品图更新失败"
    case .garmentObservationsCreated: "发现穿搭线索"
    case .garmentObservationLinked: "关联已有单品"
    case .garmentObservationRejected: "排除候选单品"
    case .garmentObservationDismissed: "暂放穿搭线索"
    case .garmentObservationCreatedItem: "从穿搭加入单品"
    case .unknown: "未知事件"
    }
  }
}
