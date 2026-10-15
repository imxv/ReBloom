import Foundation

enum AdonisModelStoreMode: Equatable {
  case production
  case transientTest
  case persistentUITest(UUID)
}

struct AdonisModelStorePolicy {
  static let persistentStoreArgument = "-ui-testing-persistent-store"

  static func resolve(
    arguments: [String],
    environment: [String: String]
  ) -> AdonisModelStoreMode {
    #if DEBUG
      let isUITesting = arguments.contains("-ui-testing")

      if isUITesting {
        guard
          let argumentIndex = arguments.firstIndex(of: persistentStoreArgument),
          arguments.indices.contains(argumentIndex + 1),
          let identifier = UUID(uuidString: arguments[argumentIndex + 1])
        else {
          return .transientTest
        }

        return .persistentUITest(identifier)
      }

      if environment["XCTestConfigurationFilePath"] != nil {
        return .transientTest
      }

      return .production
    #else
      return .production
    #endif
  }

  static func persistentUITestStoreURL(
    identifier: UUID,
    baseDirectory: URL
  ) -> URL {
    baseDirectory
      .appendingPathComponent("AdonisUITestStores", isDirectory: true)
      .appendingPathComponent(identifier.uuidString.lowercased(), isDirectory: true)
      .appendingPathComponent("Adonis.store", isDirectory: false)
  }
}
