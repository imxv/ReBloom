import OSLog
import SwiftData

@MainActor
enum EventLogger {
  private static let logger = Logger(
    subsystem: "studio.adonis.localdemo",
    category: "processing-events"
  )

  @discardableResult
  static func log(
    _ kind: AppEventKind,
    durationMilliseconds: Int? = nil,
    detail: String? = nil,
    inputSource: EventInputSource? = nil,
    processingVersion: String? = nil,
    generationPerformanceTrace: GenerationPerformanceTrace? = nil,
    in context: ModelContext
  ) -> Bool {
    context.insert(
      AppEvent(
        kind: kind,
        durationMilliseconds: durationMilliseconds,
        detail: detail,
        inputSource: inputSource,
        processingVersion: processingVersion,
        generationPerformanceTrace: generationPerformanceTrace
      ))
    do {
      try context.save()
      return true
    } catch {
      let nsError = error as NSError
      logger.error(
        "event_persist_failed kind=\(kind.rawValue, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code)"
      )
      return false
    }
  }
}
