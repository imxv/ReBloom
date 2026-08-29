import SwiftData
import SwiftUI

struct LocalSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \AppEvent.createdAt, order: .reverse) private var events: [AppEvent]
  @Query private var records: [OutfitRecord]
  @Query private var items: [WardrobeItem]
  @Query private var observations: [GarmentObservation]

  @State private var showClearConfirmation = false
  @State private var clearError: String?

  var body: some View {
    List {
      Section {
        HStack(spacing: 14) {
          DoodleFlower(size: 42)
          VStack(alignment: .leading, spacing: 3) {
            Text("只在这台设备上")
              .font(.system(.headline, design: .rounded, weight: .bold))
            Text("没有账号、云同步或远程分析")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 4)
      }

      Section("本地内容") {
        LabeledContent("穿搭记录", value: "\(records.count)")
        LabeledContent("衣橱单品", value: "\(items.count)")
        LabeledContent("待确认线索", value: "\(pendingObservations.count)")
        LabeledContent("处理事件", value: "\(events.count)")
      }

      Section("处理状态") {
        LabeledContent("成功", value: "\(successfulEvents.count)")
        LabeledContent("失败", value: "\(failedEvents.count)")
        LabeledContent("平均耗时", value: averageDurationText)

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

      Section("最近事件") {
        if events.isEmpty {
          Text("还没有本地事件")
            .foregroundStyle(.secondary)
        } else {
          ForEach(events.prefix(12)) { event in
            HStack {
              VStack(alignment: .leading, spacing: 3) {
                Text(event.kind.title)
                Text(AdonisDateText.eventTime(event.createdAt))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                if let trace = traceText(for: event) {
                  Text(trace)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
              }
              Spacer()
              if let duration = event.durationMilliseconds {
                Text("\(duration) ms")
                  .font(.system(.caption, design: .monospaced))
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }

      Section {
        Button("清空所有本地数据", role: .destructive) {
          showClearConfirmation = true
        }
      } footer: {
        Text("会删除当前设备里的原图、贴纸、收藏卡、衣橱和调试事件，无法撤销。")
      }
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
    .confirmationDialog("清空所有本地数据？", isPresented: $showClearConfirmation) {
      Button("全部删除", role: .destructive, action: clearAllData)
      Button("取消", role: .cancel) {}
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

  private var successfulEvents: [AppEvent] {
    events.filter { $0.kind == .generationSucceeded }
  }

  private var pendingObservations: [GarmentObservation] {
    observations.filter { $0.state == .pending }
  }

  private var failedEvents: [AppEvent] {
    events.filter { $0.kind == .generationFailed }
  }

  private var averageDurationText: String {
    let durations = successfulEvents.compactMap(\.durationMilliseconds)
    guard !durations.isEmpty else { return "—" }
    return "\(durations.reduce(0, +) / durations.count) ms"
  }

  private func traceText(for event: AppEvent) -> String? {
    let parts = [event.inputSource?.title, event.processingVersion].compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  @MainActor
  private func clearAllData() {
    do {
      records.forEach(modelContext.delete)
      items.forEach(modelContext.delete)
      events.forEach(modelContext.delete)
      try modelContext.save()
      try MediaStore.shared.removeAll()
    } catch {
      clearError = error.localizedDescription
    }
  }
}
