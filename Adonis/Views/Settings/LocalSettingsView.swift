import SwiftData
import SwiftUI

struct LocalSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \AppEvent.createdAt, order: .reverse) private var events: [AppEvent]
  @Query private var records: [OutfitRecord]
  @Query private var creativeWorks: [CreativeWork]
  @Query private var items: [WardrobeItem]
  @Query private var observations: [GarmentObservation]

  @State private var showClearConfirmation = false
  @State private var showExportConfirmation = false
  @State private var showClearSuccess = false
  @State private var isPreparingExport = false
  @State private var activeArchive: PersonalDataArchive?
  @State private var exportURLForCleanup: URL?
  @State private var exportError: String?
  @State private var clearError: String?
  @State private var pendingSharedImageCount = 0
  @State private var didPrepareUITestData = false

  private let archiveService = PersonalDataArchiveService()
  private let deletionService = PersonalDataDeletionService()

  var body: some View {
    List {
      privacyOverviewSection
      localContentSection
      dataActionsSection
      processingStatusSection
      recentEventsSection
    }
    .scrollContentBackground(.hidden)
    .background(AdonisTheme.canvas)
    .navigationTitle("本地设置")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("完成") { dismiss() }
      }
    }
    .task {
      try? archiveService.removeAllTemporaryExports()
      await prepareUITestDataIfNeeded()
      refreshPendingSharedImageCount()
    }
    .sheet(item: $activeArchive, onDismiss: cleanupExport) { archive in
      ActivityView(items: [archive.url])
    }
    .confirmationDialog("导出一份完整副本？", isPresented: $showExportConfirmation) {
      Button("生成导出包") {
        Task { await prepareExport() }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("导出包包含你的原图和穿搭数据。只有你在下一步选择的 App 或位置会收到它。")
    }
    .confirmationDialog("清空所有本地数据？", isPresented: $showClearConfirmation) {
      Button("全部删除", role: .destructive, action: clearAllData)
      Button("取消", role: .cancel) {}
    } message: {
      Text("会删除原图、贴纸、收藏卡、创作作品、衣橱、处理记录和待导入图片，无法撤销。")
    }
    .alert("已经清空本地数据", isPresented: $showClearSuccess) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text("Adonis 在这台设备里保存的内容已经删除。")
    }
    .alert(
      "导出失败",
      isPresented: Binding(
        get: { exportError != nil },
        set: { if !$0 { exportError = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(exportError ?? "请稍后再试。")
    }
    .alert(
      "清空失败",
      isPresented: Binding(
        get: { clearError != nil },
        set: { if !$0 { clearError = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(clearError ?? "请稍后再试。")
    }
  }

  private var privacyOverviewSection: some View {
    Section {
      HStack(spacing: 14) {
        DoodleFlower(size: 42)
        VStack(alignment: .leading, spacing: 3) {
          Text("由你保管")
            .font(.system(.headline, design: .rounded, weight: .bold))
          Text("没有账号或 Adonis 云同步；AI 图片生成由 Apple 系统管理")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 4)
    } footer: {
      Text("只读取你主动选择或分享的图片。AI 贴纸会交给 Apple 系统图片生成，网络与费用信息由系统管理且未向 Adonis 公开；设备备份由你的 iOS 设置决定。")
    }
  }

  private var localContentSection: some View {
    Section("本地内容") {
      privacyCount("穿搭记录", count: records.count, identifier: "privacy-outfit-count")
      privacyCount("创作作品", count: creativeWorks.count, identifier: "privacy-creative-count")
      privacyCount("衣橱单品", count: items.count, identifier: "privacy-wardrobe-count")
      privacyCount(
        "待确认线索",
        count: pendingObservations.count,
        identifier: "privacy-observation-count"
      )
      privacyCount(
        "待导入图片",
        count: pendingSharedImageCount,
        identifier: "privacy-inbox-count"
      )
      privacyCount("处理事件", count: events.count, identifier: "privacy-event-count")
    }
  }

  private var dataActionsSection: some View {
    Section {
      Button {
        showExportConfirmation = true
      } label: {
        HStack {
          Label("导出我的数据", systemImage: "square.and.arrow.up")
          Spacer()
          if isPreparingExport {
            ProgressView()
          }
        }
      }
      .disabled(isPreparingExport)
      .accessibilityIdentifier("export-personal-data")

      Button("清空所有本地数据", role: .destructive) {
        showClearConfirmation = true
      }
      .accessibilityIdentifier("delete-all-personal-data")
    } header: {
      Text("带走或删除")
    } footer: {
      Text("导出包包含原图、贴纸、收藏卡、创作作品、衣橱和本机处理记录。全部删除还会清空尚未导入的分享图片，无法撤销。")
    }
  }

  private var processingStatusSection: some View {
    Section("处理状态") {
      LabeledContent("成功", value: "\(successfulEvents.count)")
      LabeledContent("失败", value: "\(failedEvents.count)")
      LabeledContent("超时", value: "\(timedOutEvents.count)")
      LabeledContent("取消", value: "\(cancelledEvents.count)")
      LabeledContent("平均端到端耗时", value: averageDurationText)

      if !successfulPerformanceTraces.isEmpty {
        LabeledContent(
          "45 秒目标内",
          value: "\(withinTargetCount) / \(successfulPerformanceTraces.count) 次"
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("performance-budget-summary")
      }

      if let latestPerformanceEvent,
        let trace = latestPerformanceEvent.generationPerformanceTrace
      {
        LabeledContent(
          "最近一次链路",
          value: "\(latestPerformanceEvent.kind.title) · \(durationText(trace.totalMilliseconds))"
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("performance-latest-event")

        if let slowestStage = trace.slowestStage {
          LabeledContent(
            "最近最慢阶段",
            value: "\(slowestStage.stage.title) · \(durationText(slowestStage.milliseconds))"
          )
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("performance-latest-stage")
        }

        if let interruptedStage = trace.interruptedStage {
          LabeledContent("中断位置", value: interruptedStage.title)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("performance-interrupted-stage")
        }

        LabeledContent("本地重试", value: "\(trace.retryCount) 次")
        if let metadata = trace.executionMetadata {
          LabeledContent("图片提供方", value: providerTitle(metadata.provider))
          LabeledContent("提供方请求", value: "\(metadata.providerRequestCount) 次")
          LabeledContent(
            "外部请求",
            value: metadata.externalRequestCount.map { "\($0) 次" } ?? "系统未公开"
          )
          LabeledContent("网络方式", value: transportTitle(metadata.networkTransport))
          LabeledContent("外部费用", value: costTitle(metadata.externalCost))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("performance-external-cost")
        } else {
          LabeledContent("外部请求", value: "\(trace.externalRequestCount) 次")
          LabeledContent(
            "外部费用",
            value: trace.externalRequestCount == 0 ? "不适用（旧版本机链路）" : "尚未接入计价"
          )
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("performance-external-cost")
        }

        if trace.usesPreparedSample {
          Text("最近一次使用固定样片，只代表本机演示链路。")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      if let latestFailure = failedEvents.first, let detail = latestFailure.detail {
        VStack(alignment: .leading, spacing: 4) {
          Text("最近一次失败")
            .font(.caption.weight(.bold))
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var recentEventsSection: some View {
    Section("最近事件") {
      if events.isEmpty {
        Text("还没有本地事件")
          .foregroundStyle(.secondary)
      } else {
        ForEach(events.prefix(12)) { event in
          AccessibilityAdaptiveStack(spacing: 8, verticalAlignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
              Text(event.kind.title)
              Text(AdonisDateText.eventTime(event.createdAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
              if let trace = traceText(for: event) {
                Text(trace)
                  .font(.system(.caption2, design: .monospaced))
                  .foregroundStyle(.secondary)
                  .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let duration = event.durationMilliseconds {
              Text("\(duration) ms")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
  }

  private var successfulEvents: [AppEvent] {
    events.filter { $0.kind == .generationSucceeded }
  }

  private var pendingObservations: [GarmentObservation] {
    observations.filter { $0.state == .pending }
  }

  private var failedEvents: [AppEvent] {
    events.filter { $0.kind == .generationFailed }
  }

  private var cancelledEvents: [AppEvent] {
    events.filter { $0.kind == .generationCancelled }
  }

  private var timedOutEvents: [AppEvent] {
    events.filter { $0.kind == .generationTimedOut }
  }

  private var successfulPerformanceTraces: [GenerationPerformanceTrace] {
    successfulEvents.compactMap(\.generationPerformanceTrace)
  }

  private var withinTargetCount: Int {
    successfulPerformanceTraces.count { $0.budgetStatus == .withinTarget }
  }

  private var latestPerformanceEvent: AppEvent? {
    events.first {
      $0.generationPerformanceTrace != nil
        && [
          .generationSucceeded,
          .generationFailed,
          .generationTimedOut,
          .generationCancelled,
        ].contains($0.kind)
    }
  }

  private var averageDurationText: String {
    let durations = successfulPerformanceTraces.map(\.totalMilliseconds)
    guard !durations.isEmpty else { return "—" }
    return durationText(durations.reduce(0, +) / durations.count)
  }

  private func durationText(_ milliseconds: Int) -> String {
    guard milliseconds >= 1_000 else { return "\(milliseconds) 毫秒" }
    let roundedTenths = (milliseconds + 50) / 100
    return "\(roundedTenths / 10).\(roundedTenths % 10) 秒"
  }

  private func providerTitle(_ provider: CreativeProviderIdentifier) -> String {
    switch provider {
    case .adonisLocalRenderer: "Adonis 本机"
    case .appleImagePlayground: "Apple 系统图片生成"
    case .uiTestFixture: "测试夹具"
    case .unknown: "未知"
    }
  }

  private func transportTitle(_ transport: CreativeNetworkTransport) -> String {
    switch transport {
    case .none: "无"
    case .systemManaged: "由系统管理"
    case .unknown: "未知"
    }
  }

  private func costTitle(_ cost: CreativeExternalCost) -> String {
    switch cost {
    case .notApplicable: "不适用"
    case .notExposed: "系统未公开"
    case .unknown: "未知"
    }
  }

  private func traceText(for event: AppEvent) -> String? {
    let parts = [event.inputSource?.title, event.processingVersion].compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  private func privacyCount(_ title: String, count: Int, identifier: String) -> some View {
    LabeledContent(title, value: "\(count)")
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(title) \(count)")
      .accessibilityIdentifier(identifier)
  }

  @MainActor
  private func prepareExport() async {
    guard !isPreparingExport else { return }
    isPreparingExport = true
    defer { isPreparingExport = false }
    do {
      let inbox = try SharedImageInbox.live()
      let archive = try await archiveService.export(
        records: records,
        items: items,
        observations: observations,
        events: events,
        inbox: inbox
      )
      exportURLForCleanup = archive.url
      activeArchive = archive
    } catch {
      exportError = error.localizedDescription
    }
  }

  private func cleanupExport() {
    if let exportURLForCleanup {
      archiveService.removeTemporaryExport(at: exportURLForCleanup)
    }
    exportURLForCleanup = nil
  }

  @MainActor
  private func refreshPendingSharedImageCount() {
    pendingSharedImageCount = (try? SharedImageInbox.live().pendingItems().count) ?? 0
  }

  @MainActor
  private func clearAllData() {
    do {
      let inbox = try SharedImageInbox.live()
      try deletionService.deleteAll(in: modelContext, inbox: inbox)
      cleanupExport()
      refreshPendingSharedImageCount()
      showClearSuccess = true
    } catch {
      clearError = error.localizedDescription
    }
  }

  @MainActor
  private func prepareUITestDataIfNeeded() async {
    guard isUITestingPrivacyData, !didPrepareUITestData else { return }
    didPrepareUITestData = true
    do {
      try MediaStore.shared.removeAll()
      let image = WardrobeTestImageFactory.brownCatalogShirt()
      let filename = try MediaStore.shared.savePNG(
        image,
        filename: "privacy-ui-test-wardrobe.png"
      )
      modelContext.insert(
        WardrobeItem(
          name: "棕色单品",
          category: .top,
          imageFilename: filename,
          sourceKind: .catalogImage
        ))
      modelContext.insert(AppEvent(kind: .wardrobeItemAdded, inputSource: .testFixture))
      try modelContext.save()

      if let data = image.pngData() {
        let inbox = try SharedImageInbox.live()
        try inbox.enqueue(data: data)
      }
    } catch {
      clearError = error.localizedDescription
    }
  }

  private var isUITestingPrivacyData: Bool {
    ProcessInfo.processInfo.arguments.contains("-ui-testing-privacy-data")
  }
}
