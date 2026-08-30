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
  var generationPerformanceVersion: String?
  var generationTargetMilliseconds: Int?
  var generationInputLoadingMilliseconds: Int?
  var generationAIStickerMilliseconds: Int?
  var generationSubjectExtractionMilliseconds: Int?
  var generationQualityAssessmentMilliseconds: Int?
  var generationShareCardCompositionMilliseconds: Int?
  var generationGarmentObservationMilliseconds: Int?
  var generationRetryCount: Int?
  var generationExternalRequestCount: Int?
  var generationUsesPreparedSample: Bool?
  var generationInterruptedStageRawValue: String?
  var generationExecutionMetadataData: Data?

  var kind: AppEventKind {
    AppEventKind(rawValue: kindRawValue) ?? .unknown
  }

  var inputSource: EventInputSource? {
    guard let inputSourceRawValue else { return nil }
    return EventInputSource(rawValue: inputSourceRawValue)
  }

  var generationPerformanceTrace: GenerationPerformanceTrace? {
    guard let generationPerformanceVersion,
      let durationMilliseconds,
      let generationTargetMilliseconds
    else {
      return nil
    }

    let stageTimings = GenerationPerformanceStage.allCases.compactMap { stage in
      generationMilliseconds(for: stage).map {
        GenerationStageTiming(stage: stage, milliseconds: $0)
      }
    }
    return GenerationPerformanceTrace(
      version: generationPerformanceVersion,
      totalMilliseconds: durationMilliseconds,
      targetMilliseconds: generationTargetMilliseconds,
      stageTimings: stageTimings,
      retryCount: generationRetryCount ?? 0,
      externalRequestCount: generationExternalRequestCount ?? 0,
      usesPreparedSample: generationUsesPreparedSample ?? false,
      interruptedStage: generationInterruptedStageRawValue.flatMap(
        GenerationPerformanceStage.init(rawValue:)
      ),
      executionMetadata: generationExecutionMetadataData.flatMap {
        try? JSONDecoder().decode(CreativeExecutionMetadata.self, from: $0)
      }
    )
  }

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    kind: AppEventKind,
    durationMilliseconds: Int? = nil,
    detail: String? = nil,
    inputSource: EventInputSource? = nil,
    processingVersion: String? = nil,
    generationPerformanceTrace: GenerationPerformanceTrace? = nil
  ) {
    self.id = id
    self.createdAt = createdAt
    self.kindRawValue = kind.rawValue
    self.durationMilliseconds =
      generationPerformanceTrace?.totalMilliseconds ?? durationMilliseconds
    self.detail = detail
    self.inputSourceRawValue = inputSource?.rawValue
    self.processingVersion = processingVersion
    self.generationPerformanceVersion = generationPerformanceTrace?.version
    self.generationTargetMilliseconds = generationPerformanceTrace?.targetMilliseconds
    self.generationInputLoadingMilliseconds = generationPerformanceTrace?.milliseconds(
      for: .inputLoading
    )
    self.generationAIStickerMilliseconds = generationPerformanceTrace?.milliseconds(
      for: .aiStickerGeneration
    )
    self.generationSubjectExtractionMilliseconds = generationPerformanceTrace?.milliseconds(
      for: .subjectExtraction
    )
    self.generationQualityAssessmentMilliseconds = generationPerformanceTrace?.milliseconds(
      for: .qualityAssessment
    )
    self.generationShareCardCompositionMilliseconds = generationPerformanceTrace?.milliseconds(
      for: .shareCardComposition
    )
    self.generationGarmentObservationMilliseconds = generationPerformanceTrace?.milliseconds(
      for: .garmentObservation
    )
    self.generationRetryCount = generationPerformanceTrace?.retryCount
    self.generationExternalRequestCount = generationPerformanceTrace?.externalRequestCount
    self.generationUsesPreparedSample = generationPerformanceTrace?.usesPreparedSample
    self.generationInterruptedStageRawValue = generationPerformanceTrace?.interruptedStage?.rawValue
    self.generationExecutionMetadataData = generationPerformanceTrace?.executionMetadata.flatMap {
      try? JSONEncoder().encode($0)
    }
  }

  private func generationMilliseconds(for stage: GenerationPerformanceStage) -> Int? {
    switch stage {
    case .inputLoading: generationInputLoadingMilliseconds
    case .aiStickerGeneration: generationAIStickerMilliseconds
    case .subjectExtraction: generationSubjectExtractionMilliseconds
    case .qualityAssessment: generationQualityAssessmentMilliseconds
    case .shareCardComposition: generationShareCardCompositionMilliseconds
    case .garmentObservation: generationGarmentObservationMilliseconds
    }
  }
}

enum AppEventKind: String {
  case generationStarted
  case generationSucceeded
  case generationFailed
  case generationTimedOut
  case generationCancelled
  case generationQualityWarning
  case generationQualityRejected
  case outfitSaved
  case outfitDeleted
  case stickerPhotoSaved
  case stickerPhotoSaveFailed
  case digitalFigurineCardCreated
  case digitalFigurineCardShareOpened
  case creativeWorkGenerationStarted
  case creativeWorkGenerationFailed
  case creativeWorkGenerationTimedOut
  case creativeWorkGenerationCancelled
  case creativeWorkCreated
  case creativeWorkSaved
  case creativeWorkShareOpened
  case digitalCabinetOpened
  case seasonalBloomArchiveOpened
  case rebloomOpened
  case rebloomShareOpened
  case rebloomReminderScheduled
  case rebloomReminderCancelled
  case rebloomReminderOpened
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
  case wardrobeVisualSignaturesBackfilled
  case wardrobeVisualSignatureBackfillFailed
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
    case .generationTimedOut: "处理超时"
    case .generationCancelled: "取消处理"
    case .generationQualityWarning: "贴纸建议复查"
    case .generationQualityRejected: "贴纸质量未通过"
    case .outfitSaved: "保存穿搭"
    case .outfitDeleted: "删除穿搭"
    case .stickerPhotoSaved: "贴纸存入相册"
    case .stickerPhotoSaveFailed: "贴纸未存入相册"
    case .digitalFigurineCardCreated: "生成手办收藏卡"
    case .digitalFigurineCardShareOpened: "打开手办卡分享"
    case .creativeWorkGenerationStarted: "开始生成创作作品"
    case .creativeWorkGenerationFailed: "创作作品生成失败"
    case .creativeWorkGenerationTimedOut: "创作作品生成超时"
    case .creativeWorkGenerationCancelled: "取消生成创作作品"
    case .creativeWorkCreated: "生成创作作品"
    case .creativeWorkSaved: "收藏创作作品"
    case .creativeWorkShareOpened: "打开创作作品分享"
    case .digitalCabinetOpened: "打开数字展柜"
    case .seasonalBloomArchiveOpened: "打开四季花历"
    case .rebloomOpened: "打开再次盛开"
    case .rebloomShareOpened: "打开再次盛开分享"
    case .rebloomReminderScheduled: "安排再次盛开提醒"
    case .rebloomReminderCancelled: "取消再次盛开提醒"
    case .rebloomReminderOpened: "从提醒打开再次盛开"
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
    case .wardrobeVisualSignaturesBackfilled: "补齐衣物画面线索"
    case .wardrobeVisualSignatureBackfillFailed: "衣物画面线索补齐失败"
    case .garmentObservationsCreated: "发现穿搭线索"
    case .garmentObservationLinked: "关联已有单品"
    case .garmentObservationRejected: "排除候选单品"
    case .garmentObservationDismissed: "暂放穿搭线索"
    case .garmentObservationCreatedItem: "从穿搭加入单品"
    case .unknown: "未知事件"
    }
  }
}
