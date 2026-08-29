import SwiftData
import SwiftUI

struct BloomCalendarView: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \OutfitRecord.createdAt, order: .reverse) private var records: [OutfitRecord]

  @State private var visibleMonth = Date.now
  @State private var selectedRecord: OutfitRecord?
  @State private var deleteErrorMessage: String?

  private let calendar = Calendar.current
  private let weekdayTitles = ["日", "一", "二", "三", "四", "五", "六"]

  var body: some View {
    ZStack {
      AdonisTheme.canvas
        .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          header
          monthCard

          if records.isEmpty {
            EmptyGardenView(
              title: "花历还没有盛开",
              message: "完成第一张贴纸后选择“收藏今天”，它就会回到这里。",
              systemImage: "calendar.badge.plus"
            )
            .padding(.horizontal, 12)
            .paperSurface()
          } else {
            recentBlooms
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 36)
      }
      .scrollIndicators(.hidden)
    }
    .toolbar(.hidden, for: .navigationBar)
    .sheet(item: $selectedRecord) { record in
      NavigationStack {
        OutfitDetailView(record: record) {
          delete(record)
        }
      }
    }
    .alert(
      "删除失败",
      isPresented: Binding(
        get: { deleteErrorMessage != nil },
        set: { if !$0 { deleteErrorMessage = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(deleteErrorMessage ?? "请稍后再试。")
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 5) {
      AdonisWordmark(compact: true)
      Text("我的花历")
        .font(.system(.largeTitle, design: .rounded, weight: .black))
        .foregroundStyle(AdonisTheme.ink)
        .accessibilityAddTraits(.isHeader)
      Text("穿过的每一天，都可以再盛开一次。")
        .font(.subheadline)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var monthCard: some View {
    VStack(spacing: 18) {
      monthNavigation

      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8)
      {
        ForEach(weekdayTitles, id: \.self) { title in
          Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(AdonisTheme.secondaryInk)
            .frame(maxWidth: .infinity)
        }

        ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
          if let date {
            dayCell(for: date)
          } else {
            Color.clear
              .frame(height: 48)
          }
        }
      }
      .dynamicTypeSize(.xSmall ... .xxxLarge)
    }
    .padding(18)
    .paperSurface()
    .accessibilityIdentifier("bloom-calendar")
  }

  private var recentBlooms: some View {
    VStack(alignment: .leading, spacing: 14) {
      AccessibilityAdaptiveStack(spacing: 8) {
        Text("最近盛开")
          .font(.system(.title3, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
          .accessibilityIdentifier("recent-blooms-title")
        StickerTag(title: "\(records.count) 次", color: AdonisTheme.leaf.opacity(0.36))
      }

      ForEach(records) { record in
        Button {
          selectedRecord = record
        } label: {
          HStack(spacing: 14) {
            StoredImageView(filename: record.cardImageFilename)
              .frame(width: 82, height: 108)
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
              Text(record.title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(AdonisTheme.ink)
              Text(AdonisDateText.longDate(record.createdAt))
                .font(.subheadline)
                .foregroundStyle(AdonisTheme.secondaryInk)
              Text("Bloom No. \(String(format: "%03d", record.bloomNumber))")
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(AdonisTheme.pomegranateInk)
            }

            Spacer()
            Image(systemName: "chevron.right")
              .foregroundStyle(AdonisTheme.secondaryInk)
          }
          .padding(10)
          .background(AdonisTheme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
          .shadow(color: AdonisTheme.ink.opacity(0.07), radius: 9, y: 4)
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityLabel(
          "\(record.title)，\(AdonisDateText.longDate(record.createdAt))，Bloom No. \(String(format: "%03d", record.bloomNumber))"
        )
        .accessibilityIdentifier("bloom-record-card")
      }
    }
  }

  @ViewBuilder
  private var monthNavigation: some View {
    if dynamicTypeSize.isAccessibilitySize {
      VStack(spacing: 8) {
        Text(monthTitle)
          .font(.system(.title3, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)

        HStack(spacing: 12) {
          Button {
            showPreviousMonth()
          } label: {
            Label("上个月", systemImage: "chevron.left")
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(StickerButtonStyle())

          Button {
            showNextMonth()
          } label: {
            Label("下个月", systemImage: "chevron.right")
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(StickerButtonStyle())
        }
      }
    } else {
      HStack {
        Button {
          showPreviousMonth()
        } label: {
          Image(systemName: "chevron.left")
            .frame(width: 44, height: 44)
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityLabel("上个月")

        Spacer()

        Text(monthTitle)
          .font(.system(.title3, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)

        Spacer()

        Button {
          showNextMonth()
        } label: {
          Image(systemName: "chevron.right")
            .frame(width: 44, height: 44)
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityLabel("下个月")
      }
    }
  }

  private func showPreviousMonth() {
    visibleMonth = calendar.date(byAdding: .month, value: -1, to: visibleMonth) ?? visibleMonth
  }

  private func showNextMonth() {
    visibleMonth = calendar.date(byAdding: .month, value: 1, to: visibleMonth) ?? visibleMonth
  }

  private func dayCell(for date: Date) -> some View {
    let record = records.first { calendar.isDate($0.createdAt, inSameDayAs: date) }
    let isToday = calendar.isDateInToday(date)

    return Button {
      if let record {
        selectedRecord = record
      }
    } label: {
      ZStack {
        if let record {
          StoredImageView(filename: record.sourceImageFilename)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
              RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(AdonisTheme.ink.opacity(0.12))
            }
          Text("\(calendar.component(.day, from: date))")
            .font(.caption.weight(.black))
            .foregroundStyle(.white)
            .shadow(radius: 2)
        } else {
          Text("\(calendar.component(.day, from: date))")
            .font(.caption.weight(isToday ? .black : .medium))
            .foregroundStyle(isToday ? AdonisTheme.pomegranateInk : AdonisTheme.secondaryInk)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(
        isToday && record == nil ? AdonisTheme.pomegranate.opacity(0.12) : Color.clear,
        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
      )
    }
    .buttonStyle(StickerButtonStyle())
    .disabled(record == nil)
    .accessibilityLabel(dayAccessibilityLabel(date: date, record: record))
  }

  private var monthTitle: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy 年 M 月"
    return formatter.string(from: visibleMonth)
  }

  private var monthCells: [Date?] {
    guard let interval = calendar.dateInterval(of: .month, for: visibleMonth),
      let dayRange = calendar.range(of: .day, in: .month, for: visibleMonth)
    else {
      return []
    }

    let firstWeekday = calendar.component(.weekday, from: interval.start)
    var cells = [Date?](repeating: nil, count: max(0, firstWeekday - 1))
    cells.append(
      contentsOf: dayRange.compactMap { day in
        calendar.date(bySetting: .day, value: day, of: interval.start)
      })
    return cells
  }

  private func dayAccessibilityLabel(date: Date, record: OutfitRecord?) -> String {
    let dateText = AdonisDateText.longDate(date)
    return record == nil ? dateText : "\(dateText)，有一条穿搭记录"
  }

  @MainActor
  private func delete(_ record: OutfitRecord) {
    let filenames =
      [
        record.sourceImageFilename,
        record.stickerImageFilename,
        record.cardImageFilename,
      ] + record.garmentObservations.map(\.previewImageFilename)
    modelContext.delete(record)
    do {
      try modelContext.save()
      MediaStore.shared.delete(filenames: filenames)
      EventLogger.log(.outfitDeleted, in: modelContext)
      selectedRecord = nil
    } catch {
      modelContext.rollback()
      deleteErrorMessage = error.localizedDescription
    }
  }
}
