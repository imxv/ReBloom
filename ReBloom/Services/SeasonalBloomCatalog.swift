import Foundation

enum BloomSeason: Int, CaseIterable, Hashable, Sendable {
  case spring
  case summer
  case autumn
  case winter

  var title: String {
    switch self {
    case .spring: "春"
    case .summer: "夏"
    case .autumn: "秋"
    case .winter: "冬"
    }
  }

  var moodTitle: String {
    switch self {
    case .spring: "苏醒"
    case .summer: "盛放"
    case .autumn: "收藏"
    case .winter: "休眠"
    }
  }

  fileprivate var startMonth: Int {
    switch self {
    case .spring: 3
    case .summer: 6
    case .autumn: 9
    case .winter: 12
    }
  }

  fileprivate static func season(for month: Int) -> BloomSeason {
    switch month {
    case 3...5: .spring
    case 6...8: .summer
    case 9...11: .autumn
    default: .winter
    }
  }
}

struct SeasonalBloomID: Hashable, Sendable {
  let season: BloomSeason
  let startYear: Int

  var title: String {
    if season == .winter {
      return "\(startYear)–\(startYear + 1) 冬"
    }
    return "\(startYear) 年 \(season.title)"
  }

  var moodTitle: String { season.moodTitle }

  var dateRangeTitle: String {
    switch season {
    case .spring: "3 月—5 月"
    case .summer: "6 月—8 月"
    case .autumn: "9 月—11 月"
    case .winter: "\(startYear) 年 12 月—\(startYear + 1) 年 2 月"
    }
  }
}

struct SeasonalBloomGroup: Identifiable {
  let id: SeasonalBloomID
  let periodStart: Date
  let records: [OutfitRecord]

  var season: BloomSeason { id.season }
  var startYear: Int { id.startYear }
  var title: String { id.title }
  var moodTitle: String { id.moodTitle }
  var dateRangeTitle: String { id.dateRangeTitle }
}

struct SeasonalBloomCatalog {
  func groups(
    records: [OutfitRecord],
    calendar: Calendar = .current
  ) -> [SeasonalBloomGroup] {
    let groupedRecords = Dictionary(grouping: records) { record in
      seasonID(for: record.createdAt, calendar: calendar)
    }

    return groupedRecords.compactMap { id, records in
      guard
        let periodStart = calendar.date(
          from: DateComponents(year: id.startYear, month: id.season.startMonth, day: 1)
        )
      else {
        return nil
      }

      return SeasonalBloomGroup(
        id: id,
        periodStart: periodStart,
        records: records.sorted(by: recordSort)
      )
    }
    .sorted { lhs, rhs in
      if lhs.periodStart != rhs.periodStart {
        return lhs.periodStart > rhs.periodStart
      }
      if lhs.startYear != rhs.startYear {
        return lhs.startYear > rhs.startYear
      }
      return lhs.season.rawValue > rhs.season.rawValue
    }
  }

  private func seasonID(for date: Date, calendar: Calendar) -> SeasonalBloomID {
    let month = calendar.component(.month, from: date)
    let year = calendar.component(.year, from: date)
    let season = BloomSeason.season(for: month)
    let startYear = season == .winter && month < 3 ? year - 1 : year
    return SeasonalBloomID(season: season, startYear: startYear)
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
