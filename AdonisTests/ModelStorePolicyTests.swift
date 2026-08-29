import XCTest

@testable import Adonis

final class ModelStorePolicyTests: XCTestCase {
  func testProductionLaunchUsesProductionStore() {
    let mode = AdonisModelStorePolicy.resolve(
      arguments: ["Adonis"],
      environment: [:]
    )

    XCTAssertEqual(mode, .production)
  }

  func testUnitAndDefaultUITestLaunchesStayTransient() {
    XCTAssertEqual(
      AdonisModelStorePolicy.resolve(
        arguments: ["Adonis"],
        environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"]
      ),
      .transientTest
    )
    XCTAssertEqual(
      AdonisModelStorePolicy.resolve(
        arguments: ["Adonis", "-ui-testing"],
        environment: [:]
      ),
      .transientTest
    )
  }

  func testPersistentStoreArgumentRequiresUITestingAndAValidUUID() {
    let identifier = UUID()
    let arguments = [
      "Adonis",
      AdonisModelStorePolicy.persistentStoreArgument,
      identifier.uuidString,
    ]

    XCTAssertEqual(
      AdonisModelStorePolicy.resolve(arguments: arguments, environment: [:]),
      .production
    )
    XCTAssertEqual(
      AdonisModelStorePolicy.resolve(
        arguments: ["Adonis", "-ui-testing", "-ui-testing-persistent-store", "../shared"],
        environment: [:]
      ),
      .transientTest
    )
  }

  func testValidPersistentUITestGetsAnIsolatedStoreURL() {
    let identifier = UUID(uuidString: "50D71A9C-FDA9-43CF-84C0-141D4E1C0F9E")!
    let mode = AdonisModelStorePolicy.resolve(
      arguments: [
        "Adonis",
        "-ui-testing",
        AdonisModelStorePolicy.persistentStoreArgument,
        identifier.uuidString,
      ],
      environment: [:]
    )
    let baseDirectory = URL(fileURLWithPath: "/tmp/adonis-model-store-tests", isDirectory: true)
    let storeURL = AdonisModelStorePolicy.persistentUITestStoreURL(
      identifier: identifier,
      baseDirectory: baseDirectory
    )

    XCTAssertEqual(mode, .persistentUITest(identifier))
    XCTAssertEqual(
      storeURL.path,
      "/tmp/adonis-model-store-tests/AdonisUITestStores/50d71a9c-fda9-43cf-84c0-141d4e1c0f9e/Adonis.store"
    )
  }
}
