import Combine
import Foundation

struct RebloomRouteRequest: Identifiable, Equatable {
  let id = UUID()
  let suggestionID: RebloomSuggestionID?
}

@MainActor
final class AppNavigationRouter: ObservableObject {
  static let shared = AppNavigationRouter()

  @Published private(set) var pendingRebloomRoute: RebloomRouteRequest?

  func receiveReminderRequest(identifier: String) {
    guard let suggestionID = RebloomReminderService.suggestionID(from: identifier) else { return }
    pendingRebloomRoute = RebloomRouteRequest(suggestionID: suggestionID)
  }

  func openCurrentRebloom() {
    pendingRebloomRoute = RebloomRouteRequest(suggestionID: nil)
  }

  func consume(_ route: RebloomRouteRequest) {
    guard pendingRebloomRoute?.id == route.id else { return }
    pendingRebloomRoute = nil
  }
}
