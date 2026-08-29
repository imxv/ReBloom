import Foundation
import XCTest

@testable import Adonis

@MainActor
final class SeasonalBloomCatalogTests: XCTestCase {
  func testCatalogIsEmptyWithoutSavedOutfits() {
    XCTAssertEqual(AdonisProcessingVersion.seasonalBloom, "seasonal-bloom-v1")
    XCTAssertEqual(AppEventKind.seasonalBloomArchiveOpened.title, "打开四季花历")
    XCTAssertTrue(
      SeasonalBloomCatalog().groups(records: [], calendar: calendar).isEmpty
    )
  }

  func testCatalogUsesMeteorologicalSeasonBoundaries() throws {
    let records = [
      record(date: try date(year: 2026, month: 3, day: 1), bloomNumber: 1),
      record(date: try date(year: 2026, month: 5, day: 31), bloomNumber: 2),
      record(date: try date(year: 2026, month: 6, day: 1), bloomNumber: 3),
      record(date: try date(year: 2026, month: 8, day: 31), bloomNumber: 4),
      record(date: try date(year: 2026, month: 9, day: 1), bloomNumber: 5),
      record(date: try date(year: 2026, month: 11, day: 30), bloomNumber: 6),
      record(date: try date(year: 2026, month: 12, day: 1), bloomNumber: 7),
      record(date: try date(year: 2027, month: 2, day: 28), bloomNumber: 8),
    ]

    let groups = SeasonalBloomCatalog().groups(records: records, calendar: calendar)

    XCTAssertEqual(groups.map(\.season), [.winter, .autumn, .summer, .spring])
    XCTAssertEqual(groups.map(\.records.count), [2, 2, 2, 2])
    XCTAssertEqual(groups.map(\.startYear), [2026, 2026, 2026, 2026])
  }

  func testWinterCombinesDecemberWithFollowingJanuaryAndFebruary() throws {
    let december = record(date: try date(year: 2025, month: 12, day: 31), bloomNumber: 9)
    let january = record(date: try date(year: 2026, month: 1, day: 1), bloomNumber: 10)
    let february = record(date: try date(year: 2026, month: 2, day: 28), bloomNumber: 11)
    let march = record(date: try date(year: 2026, month: 3, day: 1), bloomNumber: 12)

    let groups = SeasonalBloomCatalog().groups(
      records: [january, march, december, february],
      calendar: calendar
    )

    let winter = try XCTUnwrap(groups.first { $0.season == .winter })
    XCTAssertEqual(winter.startYear, 2025)
    XCTAssertEqual(winter.title, "2025–2026 冬")
    XCTAssertEqual(winter.moodTitle, "休眠")
    XCTAssertEqual(winter.dateRangeTitle, "2025 年 12 月—2026 年 2 月")
    XCTAssertEqual(winter.records.map(\.id), [february.id, january.id, december.id])
    XCTAssertEqual(groups.first?.season, .spring)
  }

  func testRecordsAreNewestFirstAndBreakDateTiesByBloomNumber() throws {
    let day = try date(year: 2026, month: 8, day: 8)
    let older = record(date: try date(year: 2026, month: 7, day: 1), bloomNumber: 20)
    let lowerBloom = record(date: day, bloomNumber: 2)
    let higherBloom = record(date: day, bloomNumber: 7)

    let summer = try XCTUnwrap(
      SeasonalBloomCatalog().groups(
        records: [lowerBloom, older, higherBloom],
        calendar: calendar
      ).first
    )

    XCTAssertEqual(summer.season, .summer)
    XCTAssertEqual(summer.title, "2026 年 夏")
    XCTAssertEqual(summer.moodTitle, "盛放")
    XCTAssertEqual(summer.dateRangeTitle, "6 月—8 月")
    XCTAssertEqual(summer.records.map(\.id), [higherBloom.id, lowerBloom.id, older.id])
  }

  func testEachSavedOutfitAppearsInExactlyOneSeason() throws {
    let records = try (1...12).map { month in
      record(
        date: try date(year: 2026, month: month, day: 15),
        bloomNumber: month
      )
    }

    let groups = SeasonalBloomCatalog().groups(records: records, calendar: calendar)
    let groupedIDs = groups.flatMap(\.records).map(\.id)

    XCTAssertEqual(groupedIDs.count, records.count)
    XCTAssertEqual(Set(groupedIDs), Set(records.map(\.id)))
  }

  private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.locale = Locale(identifier: "zh_CN")
    value.timeZone = TimeZone(secondsFromGMT: 0)!
    return value
  }

  private func date(year: Int, month: Int, day: Int) throws -> Date {
    try XCTUnwrap(
      calendar.date(from: DateComponents(year: year, month: month, day: day))
    )
  }

  private func record(date: Date, bloomNumber: Int) -> OutfitRecord {
    OutfitRecord(
      createdAt: date,
      sourceImageFilename: "source-\(bloomNumber).png",
      stickerImageFilename: "sticker-\(bloomNumber).png",
      cardImageFilename: "card-\(bloomNumber).png",
      bloomNumber: bloomNumber
    )
  }
}
