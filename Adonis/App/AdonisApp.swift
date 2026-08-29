import SwiftData
import SwiftUI

@main
struct AdonisApp: App {
  private let modelContainer: ModelContainer

  init() {
    let schema = Schema([
      OutfitRecord.self,
      WardrobeItem.self,
      AppEvent.self,
    ])
    let isRunningTests =
      ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
      || ProcessInfo.processInfo.arguments.contains("-ui-testing")
    let configuration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: isRunningTests
    )

    do {
      modelContainer = try ModelContainer(
        for: schema,
        configurations: [configuration]
      )
    } catch {
      fatalError("无法初始化本地数据库：\(error.localizedDescription)")
    }
  }

  var body: some Scene {
    WindowGroup {
      AppRootView()
    }
    .modelContainer(modelContainer)
  }
}
