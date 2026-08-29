import SwiftData

@MainActor
enum EventLogger {
  static func log(
    _ kind: AppEventKind,
    durationMilliseconds: Int? = nil,
    detail: String? = nil,
    in context: ModelContext
  ) {
    context.insert(
      AppEvent(
        kind: kind,
        durationMilliseconds: durationMilliseconds,
        detail: detail
      ))
    try? context.save()
  }
}
