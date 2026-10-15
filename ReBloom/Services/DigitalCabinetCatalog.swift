import Foundation

struct DigitalCabinetGarment: Identifiable, Equatable {
  let id: UUID
  let name: String
  let category: WardrobeCategory
  let slot: GarmentObservationSlot
}

struct DigitalCabinetEntry: Identifiable {
  let record: OutfitRecord
  let linkedGarments: [DigitalCabinetGarment]
  let pendingGarmentCount: Int
  let missingLinkedGarmentCount: Int
  let hasGarmentObservations: Bool

  var id: UUID { record.id }

  var relationshipSummary: String {
    if !linkedGarments.isEmpty {
      var summary = "已确认 · \(linkedGarments.map(\.name).joined(separator: "、"))"
      if pendingGarmentCount > 0 {
        summary += " · 还有 \(pendingGarmentCount) 件待确认"
      }
      if missingLinkedGarmentCount > 0 {
        summary += " · \(missingLinkedGarmentCount) 件关联已移除"
      }
      return summary
    }

    if pendingGarmentCount > 0 {
      var summary = "\(pendingGarmentCount) 件衣物待你确认"
      if missingLinkedGarmentCount > 0 {
        summary += " · \(missingLinkedGarmentCount) 件关联已移除"
      }
      return summary
    }

    if missingLinkedGarmentCount > 0 {
      return missingLinkedGarmentCount == 1
        ? "关联衣物已从衣橱移除"
        : "\(missingLinkedGarmentCount) 件关联衣物已从衣橱移除"
    }

    return hasGarmentObservations ? "衣物线索已暂放" : "这天还没有衣物线索"
  }
}

struct DigitalCabinetCatalog {
  func entries(
    records: [OutfitRecord],
    wardrobeItems: [WardrobeItem]
  ) -> [DigitalCabinetEntry] {
    let itemByID = Dictionary(uniqueKeysWithValues: wardrobeItems.map { ($0.id, $0) })

    return
      records
      .sorted(by: recordSort)
      .map { record in
        makeEntry(record: record, itemByID: itemByID)
      }
  }

  private func makeEntry(
    record: OutfitRecord,
    itemByID: [UUID: WardrobeItem]
  ) -> DigitalCabinetEntry {
    let observations = record.garmentObservations.sorted(by: observationSort)
    var linkedGarments: [DigitalCabinetGarment] = []
    var resolvedItemIDs = Set<UUID>()
    var missingItemIDs = Set<UUID>()
    var missingLinkWithoutIDCount = 0

    for observation in observations where observation.state.isConfirmedWardrobeLink {
      guard let itemID = observation.matchedWardrobeItemID else {
        missingLinkWithoutIDCount += 1
        continue
      }
      guard !resolvedItemIDs.contains(itemID) else { continue }
      guard let item = itemByID[itemID] else {
        missingItemIDs.insert(itemID)
        continue
      }

      resolvedItemIDs.insert(itemID)
      linkedGarments.append(
        DigitalCabinetGarment(
          id: item.id,
          name: item.name,
          category: item.category,
          slot: observation.slot
        ))
    }

    return DigitalCabinetEntry(
      record: record,
      linkedGarments: linkedGarments,
      pendingGarmentCount: observations.count { $0.state == .pending },
      missingLinkedGarmentCount: missingItemIDs.count + missingLinkWithoutIDCount,
      hasGarmentObservations: !observations.isEmpty
    )
  }

  private func recordSort(_ lhs: OutfitRecord, _ rhs: OutfitRecord) -> Bool {
    if lhs.createdAt != rhs.createdAt {
      return lhs.createdAt > rhs.createdAt
    }
    if lhs.bloomNumber != rhs.bloomNumber {
      return lhs.bloomNumber > rhs.bloomNumber
    }
    return lhs.id.uuidString < rhs.id.uuidString
  }

  private func observationSort(_ lhs: GarmentObservation, _ rhs: GarmentObservation) -> Bool {
    if lhs.slot.sortOrder != rhs.slot.sortOrder {
      return lhs.slot.sortOrder < rhs.slot.sortOrder
    }
    if lhs.createdAt != rhs.createdAt {
      return lhs.createdAt < rhs.createdAt
    }
    return lhs.id.uuidString < rhs.id.uuidString
  }
}

extension GarmentObservationState {
  fileprivate var isConfirmedWardrobeLink: Bool {
    self == .linkedExisting || self == .createdNew
  }
}

extension GarmentObservationSlot {
  fileprivate var sortOrder: Int {
    switch self {
    case .upperBody: 0
    case .lowerBody: 1
    }
  }
}
