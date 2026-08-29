import Foundation
import SwiftData
import SwiftUI

@main
struct AdonisApp: App {
  private let modelContainer: ModelContainer

  init() {
    let schema = Schema([
      OutfitRecord.self,
      GarmentObservation.self,
      WardrobeItem.self,
      AppEvent.self,
    ])
    do {
      let storeMode = AdonisModelStorePolicy.resolve(
        arguments: ProcessInfo.processInfo.arguments,
        environment: ProcessInfo.processInfo.environment
      )
      let configuration: ModelConfiguration

      switch storeMode {
      case .production:
        configuration = ModelConfiguration(schema: schema)
      case .transientTest:
        configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
      case .persistentUITest(let identifier):
        let storeURL = AdonisModelStorePolicy.persistentUITestStoreURL(
          identifier: identifier,
          baseDirectory: FileManager.default.temporaryDirectory
        )
        try FileManager.default.createDirectory(
          at: storeURL.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        configuration = ModelConfiguration(
          "AdonisUITestStore",
          schema: schema,
          url: storeURL,
          cloudKitDatabase: .none
        )
      }

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
