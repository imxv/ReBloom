import Foundation
import SwiftData

struct WardrobeHistoryCandidate: Identifiable {
  let observation: GarmentObservation
  let score: Double
  let reasons: [String]

  var id: UUID { observation.id }

  var reasonText: String {
    reasons.joined(separator: " · ")
  }

  var outfitDate: Date {
    observation.outfit?.createdAt ?? observation.createdAt
  }
}

struct WardrobeHistoryMatcher {
  static let version = AdonisProcessingVersion.wardrobeHistoryMatching

  private let candidateMatcher = WardrobeCandidateMatcher()

  func candidates(
    for item: WardrobeItem,
    among observations: [GarmentObservation],
    limit: Int = 3
  ) -> [WardrobeHistoryCandidate] {
    observations
      .filter { observation in
        observation.outfit != nil
          && observation.state == .pending
          && observation.matchedWardrobeItemID == nil
          && !observation.rejectedWardrobeItemIDs.contains(item.id)
      }
      .compactMap { observation in
        guard
          let match = candidateMatcher.candidates(
            for: observation,
            among: [item],
            limit: 1
          ).first
        else {
          return nil
        }
        return WardrobeHistoryCandidate(
          observation: observation,
          score: match.score,
          reasons: match.reasons
        )
      }
      .sorted { lhs, rhs in
        if abs(lhs.score - rhs.score) > 0.0001 { return lhs.score > rhs.score }
        return lhs.outfitDate > rhs.outfitDate
      }
      .prefix(max(0, limit))
      .map { $0 }
  }
}

@MainActor
enum WardrobeHistoryLinker {
  static func confirm(
    observation: GarmentObservation,
    as item: WardrobeItem,
    in modelContext: ModelContext
  ) throws {
    try modelContext.save()
    observation.matchedWardrobeItemID = item.id
    observation.state = .linkedExisting
    do {
      try modelContext.save()
    } catch {
      modelContext.rollback()
      throw error
    }
  }

  static func reject(
    observation: GarmentObservation,
    for item: WardrobeItem,
    in modelContext: ModelContext
  ) throws {
    try modelContext.save()
    observation.rejectWardrobeItem(id: item.id)
    observation.matchedWardrobeItemID = nil
    observation.state = .pending
    do {
      try modelContext.save()
    } catch {
      modelContext.rollback()
      throw error
    }
  }
}
