import Foundation

@MainActor
final class GenerationDeadlineController {
  nonisolated static let productionTimeout: Duration = .seconds(90)

  typealias Sleeper = @Sendable (Duration) async throws -> Void

  private let sleeper: Sleeper
  private var deadlineTask: Task<Void, Never>?
  private var activeGenerationID: UUID?

  init(
    sleeper: @escaping Sleeper = { duration in
      try await Task.sleep(for: duration)
    }
  ) {
    self.sleeper = sleeper
  }

  func arm(
    generationID: UUID,
    timeout: Duration = GenerationDeadlineController.productionTimeout,
    onTimeout: @escaping @MainActor (UUID) -> Void
  ) {
    cancel()
    activeGenerationID = generationID
    let sleeper = sleeper
    deadlineTask = Task { [weak self] in
      do {
        try await sleeper(timeout)
      } catch {
        return
      }
      guard !Task.isCancelled else { return }
      self?.fire(generationID: generationID, onTimeout: onTimeout)
    }
  }

  func cancel(generationID: UUID? = nil) {
    if let generationID, generationID != activeGenerationID { return }
    deadlineTask?.cancel()
    deadlineTask = nil
    activeGenerationID = nil
  }

  private func fire(
    generationID: UUID,
    onTimeout: @escaping @MainActor (UUID) -> Void
  ) {
    guard activeGenerationID == generationID else { return }
    deadlineTask = nil
    activeGenerationID = nil
    onTimeout(generationID)
  }
}
