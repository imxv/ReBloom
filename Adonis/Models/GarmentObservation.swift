import Foundation
import SwiftData

@Model
final class GarmentObservation {
  @Attribute(.unique) var id: UUID
  var createdAt: Date
  var slotRawValue: String
  var suggestedCategoryRawValue: String
  var dominantColorName: String?
  var dominantColorHex: String?
  var confidence: Double
  var previewImageFilename: String
  var stateRawValue: String
  var matchedWardrobeItemID: UUID?
  var rejectedWardrobeItemIDsRawValue: String
  var observerVersion: String
  var outfit: OutfitRecord?

  var slot: GarmentObservationSlot {
    get { GarmentObservationSlot(rawValue: slotRawValue) ?? .upperBody }
    set { slotRawValue = newValue.rawValue }
  }

  var suggestedCategory: WardrobeCategory {
    get { WardrobeCategory(rawValue: suggestedCategoryRawValue) ?? slot.suggestedCategory }
    set { suggestedCategoryRawValue = newValue.rawValue }
  }

  var state: GarmentObservationState {
    get { GarmentObservationState(rawValue: stateRawValue) ?? .pending }
    set { stateRawValue = newValue.rawValue }
  }

  var rejectedWardrobeItemIDs: Set<UUID> {
    Set(
      rejectedWardrobeItemIDsRawValue
        .split(separator: ",")
        .compactMap { UUID(uuidString: String($0)) }
    )
  }

  var displayName: String {
    let color = dominantColorName ?? ""
    return color.isEmpty ? suggestedCategory.rawValue : "\(color)\(suggestedCategory.rawValue)"
  }

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    slot: GarmentObservationSlot,
    suggestedCategory: WardrobeCategory? = nil,
    dominantColorName: String? = nil,
    dominantColorHex: String? = nil,
    confidence: Double,
    previewImageFilename: String,
    state: GarmentObservationState = .pending,
    matchedWardrobeItemID: UUID? = nil,
    rejectedWardrobeItemIDs: Set<UUID> = [],
    observerVersion: String = AdonisProcessingVersion.outfitObservation,
    outfit: OutfitRecord? = nil
  ) {
    self.id = id
    self.createdAt = createdAt
    self.slotRawValue = slot.rawValue
    self.suggestedCategoryRawValue = (suggestedCategory ?? slot.suggestedCategory).rawValue
    self.dominantColorName = dominantColorName
    self.dominantColorHex = dominantColorHex
    self.confidence = confidence
    self.previewImageFilename = previewImageFilename
    self.stateRawValue = state.rawValue
    self.matchedWardrobeItemID = matchedWardrobeItemID
    self.rejectedWardrobeItemIDsRawValue =
      rejectedWardrobeItemIDs
      .map(\.uuidString)
      .sorted()
      .joined(separator: ",")
    self.observerVersion = observerVersion
    self.outfit = outfit
  }

  func rejectWardrobeItem(id: UUID) {
    var ids = rejectedWardrobeItemIDs
    ids.insert(id)
    rejectedWardrobeItemIDsRawValue = ids.map(\.uuidString).sorted().joined(separator: ",")
  }
}

enum GarmentObservationSlot: String, CaseIterable, Sendable {
  case upperBody
  case lowerBody

  var title: String {
    switch self {
    case .upperBody: "上身线索"
    case .lowerBody: "下身线索"
    }
  }

  var symbol: String {
    switch self {
    case .upperBody: "tshirt"
    case .lowerBody: "figure.walk"
    }
  }

  var suggestedCategory: WardrobeCategory {
    switch self {
    case .upperBody: .top
    case .lowerBody: .bottom
    }
  }
}

enum GarmentObservationState: String, Sendable {
  case pending
  case linkedExisting
  case createdNew
  case dismissed
}
