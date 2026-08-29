import SwiftData
import SwiftUI

struct AppRootView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase

  @State private var selection: AppTab = .create
  @State private var sharedImportNotice: SharedWardrobeImportNotice?
  @State private var isProcessingSharedInbox = false
  @State private var didPrepareUITestInbox = false

  private let sharedImportCoordinator = SharedWardrobeImportCoordinator()

  var body: some View {
    TabView(selection: $selection) {
      NavigationStack {
        CreateView()
      }
      .tabItem {
        Label("创作", systemImage: "sparkles.rectangle.stack.fill")
      }
      .tag(AppTab.create)

      NavigationStack {
        WardrobeView(
          sharedImportNotice: sharedImportNotice,
          onDismissSharedImportNotice: { sharedImportNotice = nil },
          onRetrySharedImport: {
            Task { await receiveSharedWardrobeImages() }
          }
        )
      }
      .tabItem {
        Label("衣橱", systemImage: "hanger")
      }
      .tag(AppTab.wardrobe)

      NavigationStack {
        BloomCalendarView()
      }
      .tabItem {
        Label("花历", systemImage: "calendar.day.timeline.leading")
      }
      .tag(AppTab.blooms)
    }
    .tint(AdonisTheme.pomegranate)
    .task {
      await receiveSharedWardrobeImages()
    }
    .onChange(of: scenePhase) { _, newPhase in
      guard newPhase == .active else { return }
      Task { await receiveSharedWardrobeImages() }
    }
  }

  @MainActor
  private func receiveSharedWardrobeImages() async {
    guard !isProcessingSharedInbox else { return }
    isProcessingSharedInbox = true
    defer { isProcessingSharedInbox = false }

    do {
      let inbox = try SharedImageInbox.live()
      try prepareUITestInboxIfNeeded(inbox)
      let summary = try await sharedImportCoordinator.importPending(
        from: inbox,
        in: modelContext
      )
      guard summary.totalCount > 0 else { return }
      sharedImportNotice = SharedWardrobeImportNotice(summary: summary)
      selection = .wardrobe
    } catch {
      guard isUITestingSharedImport else { return }
      sharedImportNotice = SharedWardrobeImportNotice(
        summary: SharedWardrobeImportSummary(failedCount: 1)
      )
      selection = .wardrobe
    }
  }

  @MainActor
  private func prepareUITestInboxIfNeeded(_ inbox: SharedImageInbox) throws {
    guard isUITesting, !didPrepareUITestInbox else { return }
    didPrepareUITestInbox = true
    try inbox.removeAll()
    guard isUITestingSharedImport else { return }
    guard let data = WardrobeTestImageFactory.brownCatalogShirt().pngData() else {
      throw MediaStoreError.encodingFailed
    }
    try inbox.enqueue(data: data)
  }

  private var isUITesting: Bool {
    ProcessInfo.processInfo.arguments.contains("-ui-testing")
  }

  private var isUITestingSharedImport: Bool {
    ProcessInfo.processInfo.arguments.contains("-ui-testing-shared-import")
  }
}

private enum AppTab: Hashable {
  case create
  case wardrobe
  case blooms
}

#Preview {
  AppRootView()
    .modelContainer(for: [OutfitRecord.self, WardrobeItem.self, AppEvent.self], inMemory: true)
}
