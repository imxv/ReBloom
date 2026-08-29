import Foundation

enum RebloomSuggestionReason: Equatable {
  case longUnworn(dayCount: Int)
  case pastOutfitRemix
}

struct RebloomSuggestionID: Hashable {
  let topItemID: UUID
  let bottomItemID: UUID
}

struct RebloomItemUse: Identifiable {
  let item: WardrobeItem
  let lastWornAt: Date
  let sourceRecord: OutfitRecord
  fileprivate let recordIDs: Set<UUID>

  var id: UUID { item.id }

  var displayName: String {
    guard item.sourceKind == .outfitObservation,
      item.name == observationDefaultName
    else {
      return item.name
    }
    return "这件\(item.category.rawValue)"
  }

  private var observationDefaultName: String {
    let color = item.dominantColorName ?? ""
    return color.isEmpty ? item.category.rawValue : "\(color)\(item.category.rawValue)"
  }
}

struct RebloomSuggestion: Identifiable {
  let id: RebloomSuggestionID
  let top: RebloomItemUse
  let bottom: RebloomItemUse
  let returningItemID: UUID
  let reason: RebloomSuggestionReason

  var returningItem: WardrobeItem {
    returningUse.item
  }

  var familiarItem: WardrobeItem {
    familiarUse.item
  }

  var sourceRecords: [OutfitRecord] {
    [top.sourceRecord, bottom.sourceRecord]
  }

  var sourceRecordIDs: [UUID] {
    sourceRecords.map(\.id)
  }

  var isNovelCombination: Bool {
    top.recordIDs.isDisjoint(with: bottom.recordIDs)
  }

  var title: String {
    "\(top.displayName) × \(bottom.displayName)"
  }

  var reasonTitle: String {
    switch reason {
    case .longUnworn(let dayCount):
      "\(returningUse.displayName) 隔了 \(dayCount) 天再次出现；和 \(familiarUse.displayName) 一起，今天可以直接照着穿。"
    case .pastOutfitRemix:
      "把两次真实穿着拆开重组，今天可以直接照着穿。"
    }
  }

  var reasonEventValue: String {
    switch reason {
    case .longUnworn: "long_unworn"
    case .pastOutfitRemix: "history_remix"
    }
  }

  fileprivate var returningUse: RebloomItemUse {
    returningItemID == top.id ? top : bottom
  }

  fileprivate var familiarUse: RebloomItemUse {
    returningItemID == top.id ? bottom : top
  }
}

struct RebloomCatalog {
  static let longUnwornDayThreshold = 30

  func suggestions(
    records: [OutfitRecord],
    wardrobeItems: [WardrobeItem],
    now: Date = .now,
    calendar: Calendar = .current
  ) -> [RebloomSuggestion] {
    let itemByID = Dictionary(uniqueKeysWithValues: wardrobeItems.map { ($0.id, $0) })
    var recordsByItemID: [UUID: [OutfitRecord]] = [:]

    for record in records {
      let confirmedItemIDs = Set(
        record.garmentObservations.compactMap { observation -> UUID? in
          guard observation.state.isRebloomConfirmed,
            let itemID = observation.matchedWardrobeItemID,
            itemByID[itemID] != nil
          else {
            return nil
          }
          return itemID
        })

      for itemID in confirmedItemIDs {
        recordsByItemID[itemID, default: []].append(record)
      }
    }

    let itemUses = recordsByItemID.compactMap { itemID, itemRecords -> RebloomItemUse? in
      guard let item = itemByID[itemID], let latestRecord = itemRecords.sorted(by: recordSort).first
      else {
        return nil
      }
      return RebloomItemUse(
        item: item,
        lastWornAt: latestRecord.createdAt,
        sourceRecord: latestRecord,
        recordIDs: Set(itemRecords.map(\.id))
      )
    }

    let tops = itemUses.filter { $0.item.category == .top }
    let bottoms = itemUses.filter { $0.item.category == .bottom }

    var suggestions: [RebloomSuggestion] = []
    suggestions.reserveCapacity(tops.count * bottoms.count)

    for top in tops {
      for bottom in bottoms where top.recordIDs.isDisjoint(with: bottom.recordIDs) {
        let returningUse = olderUse(top, bottom) ? top : bottom
        let dayCount = daysSince(returningUse.lastWornAt, now: now, calendar: calendar)
        let reason: RebloomSuggestionReason =
          dayCount >= Self.longUnwornDayThreshold
          ? .longUnworn(dayCount: dayCount)
          : .pastOutfitRemix

        suggestions.append(
          RebloomSuggestion(
            id: RebloomSuggestionID(topItemID: top.id, bottomItemID: bottom.id),
            top: top,
            bottom: bottom,
            returningItemID: returningUse.id,
            reason: reason
          ))
      }
    }

    return suggestions.sorted(by: suggestionSort)
  }

  private func daysSince(_ date: Date, now: Date, calendar: Calendar) -> Int {
    let start = calendar.startOfDay(for: date)
    let end = calendar.startOfDay(for: now)
    return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
  }

  private func olderUse(_ lhs: RebloomItemUse, _ rhs: RebloomItemUse) -> Bool {
    if lhs.lastWornAt != rhs.lastWornAt {
      return lhs.lastWornAt < rhs.lastWornAt
    }
    if lhs.item.createdAt != rhs.item.createdAt {
      return lhs.item.createdAt < rhs.item.createdAt
    }
    return lhs.id.uuidString < rhs.id.uuidString
  }

  private func suggestionSort(_ lhs: RebloomSuggestion, _ rhs: RebloomSuggestion) -> Bool {
    if lhs.returningUse.lastWornAt != rhs.returningUse.lastWornAt {
      return lhs.returningUse.lastWornAt < rhs.returningUse.lastWornAt
    }
    if lhs.returningUse.item.createdAt != rhs.returningUse.item.createdAt {
      return lhs.returningUse.item.createdAt < rhs.returningUse.item.createdAt
    }
    if lhs.returningUse.id != rhs.returningUse.id {
      return lhs.returningUse.id.uuidString < rhs.returningUse.id.uuidString
    }
    if lhs.familiarUse.lastWornAt != rhs.familiarUse.lastWornAt {
      return lhs.familiarUse.lastWornAt > rhs.familiarUse.lastWornAt
    }
    if lhs.familiarUse.item.createdAt != rhs.familiarUse.item.createdAt {
      return lhs.familiarUse.item.createdAt > rhs.familiarUse.item.createdAt
    }
    if lhs.id.topItemID != rhs.id.topItemID {
      return lhs.id.topItemID.uuidString < rhs.id.topItemID.uuidString
    }
    return lhs.id.bottomItemID.uuidString < rhs.id.bottomItemID.uuidString
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
}

extension GarmentObservationState {
  fileprivate var isRebloomConfirmed: Bool {
    self == .linkedExisting || self == .createdNew
  }
}
