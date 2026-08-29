import Foundation
import SwiftData

struct SharedWardrobeImportSummary: Equatable, Sendable {
  var addedCount = 0
  var reusedCount = 0
  var failedCount = 0

  var totalCount: Int {
    addedCount + reusedCount + failedCount
  }
}

struct SharedWardrobeImportNotice: Equatable, Identifiable, Sendable {
  let id: UUID
  let addedCount: Int
  let reusedCount: Int
  let failedCount: Int

  init(id: UUID = UUID(), summary: SharedWardrobeImportSummary) {
    self.id = id
    self.addedCount = summary.addedCount
    self.reusedCount = summary.reusedCount
    self.failedCount = summary.failedCount
  }

  var title: String {
    if addedCount > 0 {
      return "已收进衣橱 · \(addedCount) 件"
    }
    if reusedCount == 1, failedCount == 0 {
      return "这张图片已经在衣橱里"
    }
    if reusedCount > 0, failedCount == 0 {
      return "这些图片已经在衣橱里"
    }
    return "有 \(failedCount) 张图片暂时没收好"
  }

  var detail: String {
    var parts: [String] = []
    if addedCount > 0 {
      parts.append("颜色和画面类型已在本机记住，不需要再填资料。")
    }
    if reusedCount > 0 {
      parts.append("其中 \(reusedCount) 张已有记录，没有重复创建。")
    }
    if failedCount > 0 {
      parts.append("未成功的图片仍留在本机，可以再试一次。")
    }
    return parts.joined(separator: " ")
  }
}

@MainActor
struct SharedWardrobeImportCoordinator {
  private let analyzer: WardrobeImageAnalyzer
  private let importer: WardrobeItemImportService

  init(
    analyzer: WardrobeImageAnalyzer = WardrobeImageAnalyzer(),
    importer: WardrobeItemImportService = WardrobeItemImportService()
  ) {
    self.analyzer = analyzer
    self.importer = importer
  }

  func importPending(
    from inbox: SharedImageInbox,
    in modelContext: ModelContext
  ) async throws -> SharedWardrobeImportSummary {
    let pendingItems = try inbox.pendingItems()
    var summary = SharedWardrobeImportSummary()

    for pendingItem in pendingItems {
      EventLogger.log(
        .wardrobeImportStarted,
        inputSource: .shareExtension,
        processingVersion: SharedImageInbox.version,
        in: modelContext
      )

      do {
        let data = try inbox.data(for: pendingItem)
        let analysis = try await analyzer.analyze(data: data)
        let outcome = try importer.persist(
          data: data,
          analysis: analysis,
          in: modelContext
        )
        try inbox.remove(pendingItem)

        switch outcome.disposition {
        case .added:
          summary.addedCount += 1
          EventLogger.log(
            .wardrobeItemAdded,
            durationMilliseconds: analysis.processingMilliseconds,
            detail: outcome.eventDetail,
            inputSource: .shareExtension,
            processingVersion: processingVersion(for: analysis),
            in: modelContext
          )
        case .reused:
          summary.reusedCount += 1
          EventLogger.log(
            .wardrobeItemReused,
            durationMilliseconds: analysis.processingMilliseconds,
            detail: outcome.eventDetail,
            inputSource: .shareExtension,
            processingVersion: processingVersion(for: analysis),
            in: modelContext
          )
        }
      } catch {
        modelContext.rollback()
        summary.failedCount += 1
        EventLogger.log(
          .wardrobeImportFailed,
          detail: error.localizedDescription,
          inputSource: .shareExtension,
          processingVersion: SharedImageInbox.version,
          in: modelContext
        )
      }
    }

    return summary
  }

  private func processingVersion(for analysis: WardrobeImageAnalysis) -> String {
    "\(SharedImageInbox.version)+\(analysis.analysisVersion)"
  }
}
