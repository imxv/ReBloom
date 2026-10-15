import SwiftData
import SwiftUI

struct BloomCalendarView: View {
  let rebloomRoute: RebloomRouteRequest?
  let onConsumeRebloomRoute: (RebloomRouteRequest) -> Void

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \OutfitRecord.createdAt, order: .reverse) private var records: [OutfitRecord]
  @Query(sort: \WardrobeItem.createdAt, order: .reverse) private var wardrobeItems: [WardrobeItem]

  @State private var visibleMonth = Date.now
  @State private var selectedRecord: OutfitRecord?
  @State private var monthlyLookbook: MonthlyLookbookPresentation?
  @State private var showDigitalCabinet = false
  @State private var showSeasonalBloomArchive = false
  @State private var showRebloom = false
  @State private var selectedRebloomSuggestionID: RebloomSuggestionID?
  @State private var reminderRouteMessage: String?
  @State private var deleteErrorMessage: String?
  @State private var lookbookErrorMessage: String?

  private let calendar = Calendar.current
  private let weekdayTitles = ["日", "一", "二", "三", "四", "五", "六"]

  init(
    rebloomRoute: RebloomRouteRequest? = nil,
    onConsumeRebloomRoute: @escaping (RebloomRouteRequest) -> Void = { _ in }
  ) {
    self.rebloomRoute = rebloomRoute
    self.onConsumeRebloomRoute = onConsumeRebloomRoute
  }

  var body: some View {
    ZStack {
      AdonisTheme.canvas
        .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          header
          monthCard

          if let suggestion = rebloomSuggestions.first {
            rebloomEntryCard(suggestion)
          }

          if !records.isEmpty {
            digitalCabinetEntryCard
          }

          if !visibleMonthRecords.isEmpty {
            monthlyLookbookCard
          }

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
    .sheet(item: $monthlyLookbook) { presentation in
      MonthlyLookbookView(presentation: presentation)
    }
    .sheet(isPresented: $showDigitalCabinet) {
      DigitalCabinetView { record in
        delete(record)
      }
    }
    .sheet(isPresented: $showSeasonalBloomArchive) {
      SeasonalBloomArchiveView { record in
        delete(record)
      }
    }
    .sheet(isPresented: $showRebloom) {
      RebloomView(
        initialSuggestionID: selectedRebloomSuggestionID,
        onDelete: { record in
          delete(record)
        }
      )
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
    .alert(
      "画册还没拼好",
      isPresented: Binding(
        get: { lookbookErrorMessage != nil },
        set: { if !$0 { lookbookErrorMessage = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(lookbookErrorMessage ?? "请稍后再试。")
    }
    .alert(
      "提醒里的搭配已变化",
      isPresented: Binding(
        get: { reminderRouteMessage != nil },
        set: { if !$0 { reminderRouteMessage = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(reminderRouteMessage ?? "花历已经按当前真实记录更新。")
    }
    .task(id: rebloomRoute?.id) {
      openRoutedRebloomIfNeeded()
    }
    .task(id: rebloomReminderValidityKey) {
      await RebloomReminderService.live.synchronize(
        validSuggestionIDs: Set(rebloomSuggestions.map(\.id))
      )
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
      VStack(spacing: 18) {
        monthNavigation

        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
          spacing: 8
        ) {
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
      .accessibilityIdentifier("bloom-calendar")

      if !records.isEmpty {
        Divider()
          .overlay(AdonisTheme.ink.opacity(0.08))

        seasonalBloomEntry
      }
    }
    .padding(18)
    .paperSurface()
  }

  private var seasonalBloomGroups: [SeasonalBloomGroup] {
    SeasonalBloomCatalog().groups(records: records, calendar: calendar)
  }

  private var rebloomSuggestions: [RebloomSuggestion] {
    RebloomCatalog().suggestions(
      records: records,
      wardrobeItems: wardrobeItems,
      calendar: calendar
    )
  }

  private var rebloomReminderValidityKey: String {
    rebloomSuggestions
      .map { RebloomReminderService.identifier(for: $0.id) }
      .sorted()
      .joined(separator: "|")
  }

  @MainActor
  private func openRoutedRebloomIfNeeded() {
    guard let route = rebloomRoute else { return }
    defer { onConsumeRebloomRoute(route) }

    if let requestedID = route.suggestionID {
      guard rebloomSuggestions.contains(where: { $0.id == requestedID }) else {
        reminderRouteMessage =
          "原来那组衣物或来源 OOTD 已经变化，ReBloom 没有把它补成仍然有效的建议。花历保留的是当前真实记录。"
        return
      }
      selectedRebloomSuggestionID = requestedID
    } else {
      guard let firstSuggestion = rebloomSuggestions.first else {
        reminderRouteMessage =
          "现在没有仍然有效的新组合。等衣橱里再次出现两件明确确认、又没一起穿过的衣物时，入口会自然回来。"
        return
      }
      selectedRebloomSuggestionID = firstSuggestion.id
    }

    showRebloom = true
  }

  private func rebloomEntryCard(_ suggestion: RebloomSuggestion) -> some View {
    Button {
      EventLogger.log(
        .rebloomOpened,
        detail:
          "reason=\(suggestion.reasonEventValue);suggestion_count=\(rebloomSuggestions.count)",
        processingVersion: AdonisProcessingVersion.rebloomSuggestion,
        in: modelContext
      )
      selectedRebloomSuggestionID = suggestion.id
      showRebloom = true
    } label: {
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 14) {
            rebloomItemStack(suggestion)
            rebloomEntryCopy(suggestion)
            rebloomEntryAction
          }
        } else {
          HStack(spacing: 16) {
            rebloomItemStack(suggestion)
            rebloomEntryCopy(suggestion)
            Spacer(minLength: 0)
            rebloomEntryAction
          }
        }
      }
      .padding(16)
      .background(
        LinearGradient(
          colors: [AdonisTheme.pomegranate.opacity(0.17), AdonisTheme.butter.opacity(0.31)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        in: RoundedRectangle(cornerRadius: 27, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 27, style: .continuous)
          .stroke(AdonisTheme.pomegranate.opacity(0.20), lineWidth: 1)
      }
    }
    .buttonStyle(StickerButtonStyle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "打开再次盛开。不用选模板，建议把上装 \(suggestion.top.displayName) 和下装 \(suggestion.bottom.displayName) 组合；两件衣物都已确认，且没有在同一条 OOTD 中共同出现。"
    )
    .accessibilityIdentifier("rebloom-entry")
  }

  private func rebloomEntryCopy(_ suggestion: RebloomSuggestion) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("再次盛开")
        .font(.system(.title3, design: .rounded, weight: .black))
        .foregroundStyle(AdonisTheme.ink)
      Text("不用选模板，今天试试 \(suggestion.title)。")
        .font(.subheadline)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func rebloomItemStack(_ suggestion: RebloomSuggestion) -> some View {
    HStack(spacing: -8) {
      rebloomEntryImage(filename: suggestion.top.item.imageFilename, color: AdonisTheme.lavender)
        .rotationEffect(.degrees(-5))
      rebloomEntryImage(filename: suggestion.bottom.item.imageFilename, color: AdonisTheme.leaf)
        .rotationEffect(.degrees(5))
    }
    .frame(width: 88, height: 78)
    .accessibilityHidden(true)
  }

  private func rebloomEntryImage(filename: String, color: Color) -> some View {
    StoredImageView(filename: filename, contentMode: .fit)
      .padding(6)
      .frame(width: 54, height: 70)
      .background(color.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(AdonisTheme.paper, lineWidth: 2)
      }
  }

  private var rebloomEntryAction: some View {
    Image(systemName: "arrow.triangle.2.circlepath")
      .font(.system(size: 17, weight: .black))
      .foregroundStyle(AdonisTheme.pomegranateInk)
      .frame(width: 42, height: 42)
      .background(AdonisTheme.paper.opacity(0.78), in: Circle())
      .accessibilityHidden(true)
  }

  private var seasonalBloomEntry: some View {
    Button {
      EventLogger.log(
        .seasonalBloomArchiveOpened,
        processingVersion: AdonisProcessingVersion.seasonalBloom,
        in: modelContext
      )
      showSeasonalBloomArchive = true
    } label: {
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 12) {
            seasonalBloomIconRow
            seasonalBloomCopy
          }
        } else {
          HStack(spacing: 14) {
            seasonalBloomIconRow
            seasonalBloomCopy
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
              .font(.system(size: 15, weight: .black))
              .foregroundStyle(AdonisTheme.pomegranateInk)
              .accessibilityHidden(true)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(
        LinearGradient(
          colors: [AdonisTheme.leaf.opacity(0.13), AdonisTheme.lavender.opacity(0.16)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
      )
    }
    .buttonStyle(StickerButtonStyle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "打开穿过的四季，已自动归档 \(seasonalBloomGroups.count) 个季节、\(records.count) 次盛开"
    )
    .accessibilityHint("只展示真正收藏过的季节，不是打卡")
    .accessibilityIdentifier("seasonal-bloom-entry")
  }

  private var seasonalBloomCopy: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("穿过的四季")
        .font(.system(.headline, design: .rounded, weight: .black))
        .foregroundStyle(AdonisTheme.ink)
      Text("\(seasonalBloomGroups.count) 个季节已自己归档，不用补齐。")
        .font(.caption)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var seasonalBloomIconRow: some View {
    HStack(spacing: -5) {
      ForEach(seasonalBloomGroups.prefix(4)) { group in
        Text(group.season.title)
          .font(.system(.caption, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .frame(width: 34, height: 34)
          .background(seasonEntryColor(group.season), in: Circle())
          .overlay {
            Circle().stroke(AdonisTheme.paper, lineWidth: 2)
          }
      }
    }
    .accessibilityHidden(true)
  }

  private func seasonEntryColor(_ season: BloomSeason) -> Color {
    switch season {
    case .spring: AdonisTheme.leaf.opacity(0.58)
    case .summer: AdonisTheme.butter.opacity(0.82)
    case .autumn: AdonisTheme.pomegranate.opacity(0.42)
    case .winter: AdonisTheme.lavender.opacity(0.72)
    }
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

  private var digitalCabinetEntryCard: some View {
    Button {
      EventLogger.log(
        .digitalCabinetOpened,
        processingVersion: AdonisProcessingVersion.digitalCabinet,
        in: modelContext
      )
      showDigitalCabinet = true
    } label: {
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 14) {
            cabinetStickerStack
            cabinetEntryCopy
            cabinetEntryAction
          }
        } else {
          HStack(spacing: 16) {
            cabinetStickerStack
            cabinetEntryCopy
            Spacer(minLength: 0)
            cabinetEntryAction
          }
        }
      }
      .padding(16)
      .background(
        LinearGradient(
          colors: [AdonisTheme.leaf.opacity(0.20), AdonisTheme.lavender.opacity(0.25)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        in: RoundedRectangle(cornerRadius: 26, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
          .stroke(AdonisTheme.leaf.opacity(0.25), lineWidth: 1)
      }
    }
    .buttonStyle(StickerButtonStyle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "打开我的数字展柜，已自动收进 \(records.count) 个贴纸手办，可回看对应日期、OOTD 和衣物关系"
    )
    .accessibilityIdentifier("digital-cabinet-entry")
  }

  private var cabinetEntryCopy: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("我的数字展柜")
        .font(.system(.title3, design: .rounded, weight: .black))
        .foregroundStyle(AdonisTheme.ink)
      Text("\(records.count) 个贴纸手办已自动站好，随时回到那天。")
        .font(.subheadline)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var cabinetEntryAction: some View {
    Image(systemName: "cabinet.fill")
      .font(.system(size: 17, weight: .black))
      .foregroundStyle(AdonisTheme.ink)
      .frame(width: 42, height: 42)
      .background(AdonisTheme.butter.opacity(0.70), in: Circle())
      .accessibilityHidden(true)
  }

  private var cabinetStickerStack: some View {
    ZStack {
      ForEach(Array(records.prefix(3).enumerated()), id: \.element.id) { index, record in
        DigitalCabinetStage(
          stickerFilename: record.stickerImageFilename,
          bloomNumber: record.bloomNumber,
          compact: true
        )
        .frame(width: 54, height: 66)
        .rotationEffect(.degrees(Double(index - 1) * 5))
        .offset(x: CGFloat(index) * 13)
      }
    }
    .frame(width: 84, height: 70, alignment: .leading)
    .accessibilityHidden(true)
  }

  private var monthlyLookbookCard: some View {
    Button {
      makeMonthlyLookbook()
    } label: {
      HStack(spacing: 16) {
        lookbookStickerStack

        VStack(alignment: .leading, spacing: 6) {
          Text("本月贴纸画册")
            .font(.system(.title3, design: .rounded, weight: .black))
            .foregroundStyle(AdonisTheme.ink)
          Text("一键把 \(visibleMonthRecords.count) 次盛开排好，直接分享。")
            .font(.subheadline)
            .foregroundStyle(AdonisTheme.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 0)

        Image(systemName: "arrow.up.right")
          .font(.system(size: 16, weight: .black))
          .foregroundStyle(AdonisTheme.pomegranateInk)
          .frame(width: 40, height: 40)
          .background(AdonisTheme.butter.opacity(0.56), in: Circle())
      }
      .padding(16)
      .background(
        LinearGradient(
          colors: [AdonisTheme.lavender.opacity(0.23), AdonisTheme.butter.opacity(0.24)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        in: RoundedRectangle(cornerRadius: 26, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
          .stroke(AdonisTheme.pomegranate.opacity(0.16), lineWidth: 1)
      }
    }
    .buttonStyle(StickerButtonStyle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "制作本月贴纸画册，\(monthTitle)，共 \(visibleMonthRecords.count) 次盛开"
    )
    .accessibilityIdentifier("monthly-lookbook-entry")
  }

  private var lookbookStickerStack: some View {
    ZStack {
      ForEach(Array(visibleMonthRecords.prefix(3).enumerated()), id: \.offset) { index, record in
        StoredImageView(filename: record.stickerImageFilename, contentMode: .fit)
          .padding(7)
          .frame(width: 68, height: 82)
          .background(
            [AdonisTheme.butter, AdonisTheme.leaf, AdonisTheme.lavender][index]
              .opacity(0.48),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
          )
          .rotationEffect(.degrees(Double(index - 1) * 6))
          .offset(x: CGFloat(index - 1) * 8)
      }
    }
    .frame(width: 84, height: 88)
    .accessibilityHidden(true)
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

  private var visibleMonthRecords: [OutfitRecord] {
    records.filter {
      calendar.isDate($0.createdAt, equalTo: visibleMonth, toGranularity: .month)
    }
  }

  private func makeMonthlyLookbook() {
    let monthRecords = visibleMonthRecords
    var entries: [MonthlyLookbookEntry] = []
    entries.reserveCapacity(monthRecords.count)

    for record in monthRecords {
      guard let sticker = MediaStore.shared.image(filename: record.stickerImageFilename) else {
        lookbookErrorMessage = "有一张已收藏贴纸暂时无法读取。原记录没有丢失，可以稍后再试。"
        return
      }
      entries.append(
        MonthlyLookbookEntry(
          sticker: sticker,
          bloomNumber: record.bloomNumber,
          date: record.createdAt,
          stickerProvenance: record.stickerProvenance
        ))
    }

    guard
      let image = MonthlyLookbookRenderer().render(
        entries: entries,
        month: visibleMonth,
        calendar: calendar
      )
    else {
      lookbookErrorMessage = "这个月还没有可以排进画册的贴纸。"
      return
    }

    monthlyLookbook = MonthlyLookbookPresentation(
      image: image,
      month: visibleMonth,
      entryCount: visibleMonthRecords.count,
      provenance: entries.contains { $0.stickerProvenance.containsAIGeneratedPixels }
        ? .aiGenerated : .programmaticComposition
    )
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
      ] + [record.aiStickerSourceImageFilename].compactMap { $0 }
      + record.garmentObservations.map(\.previewImageFilename)
      + record.creativeWorks.map(\.imageFilename)
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
