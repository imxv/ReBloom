import SwiftData
import SwiftUI

struct SeasonalBloomArchiveView: View {
  let onDelete: (OutfitRecord) -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Query(sort: \OutfitRecord.createdAt, order: .reverse) private var records: [OutfitRecord]

  private var groups: [SeasonalBloomGroup] {
    SeasonalBloomCatalog().groups(records: records)
  }

  private var columns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: 14, alignment: .top),
      count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
    )
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AdonisTheme.canvas
          .ignoresSafeArea()

        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            header

            ContentProvenanceNotice(
              provenance: .programmaticComposition,
              detail: "四季花历只整理已收藏记录，不生成新照片，也不改动人物、衣物或日期。",
              identifier: "seasonal-bloom-provenance"
            )

            noPressureNotice

            if groups.isEmpty {
              EmptyGardenView(
                title: "四季还在等第一朵花",
                message: "收藏一条 OOTD 后，它会自己落进对应季节。",
                systemImage: "leaf"
              )
              .padding(.horizontal, 12)
              .paperSurface()
              .accessibilityIdentifier("seasonal-bloom-empty")
            } else {
              LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(groups) { group in
                  NavigationLink {
                    SeasonalBloomDetailView(
                      seasonID: group.id,
                      onDelete: onDelete,
                      onClose: { dismiss() }
                    )
                  } label: {
                    SeasonalBloomGroupCard(group: group)
                  }
                  .buttonStyle(StickerButtonStyle())
                  .accessibilityElement(children: .combine)
                  .accessibilityLabel(
                    "\(group.title) · \(group.moodTitle)，\(group.records.count) 次盛开，\(group.dateRangeTitle)"
                  )
                  .accessibilityHint("查看这个季节保存的 OOTD")
                  .accessibilityIdentifier("seasonal-bloom-group")
                }
              }
            }
          }
          .padding(.horizontal, 20)
          .padding(.top, 12)
          .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("seasonal-bloom-archive")
      }
      .navigationTitle("穿过的四季")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") {
            dismiss()
          }
          .accessibilityIdentifier("close-seasonal-bloom")
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      AdonisWordmark(compact: true)

      Text("穿过的日子，也有自己的季节")
        .font(.system(.title2, design: .rounded, weight: .black))
        .foregroundStyle(AdonisTheme.ink)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)

      Text("每次收藏都会按时间自动归档。春夏秋冬循环回来，你不用再整理一次。")
        .font(.subheadline)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var noPressureNotice: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "heart.text.clipboard")
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(AdonisTheme.ink)
        .frame(width: 40, height: 40)
        .background(AdonisTheme.butter.opacity(0.62), in: Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text("不是打卡，也不用补齐四季")
          .font(.system(.subheadline, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
        Text("这里只出现真正收藏过的季节；空白不是缺失，也不会催你记录。")
          .font(.footnote)
          .foregroundStyle(AdonisTheme.secondaryInk)
          .lineSpacing(2)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
    .padding(14)
    .background(
      AdonisTheme.butter.opacity(0.18),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "不是打卡，也不用补齐四季。这里只出现真正收藏过的季节；空白不是缺失，也不会催你记录。"
    )
    .accessibilityIdentifier("seasonal-bloom-no-pressure")
  }
}

private struct SeasonalBloomDetailView: View {
  let seasonID: SeasonalBloomID
  let onDelete: (OutfitRecord) -> Void
  let onClose: () -> Void

  @Query(sort: \OutfitRecord.createdAt, order: .reverse) private var records: [OutfitRecord]
  @State private var selectedRecord: OutfitRecord?

  private var group: SeasonalBloomGroup? {
    SeasonalBloomCatalog().groups(records: records).first { $0.id == seasonID }
  }

  var body: some View {
    ZStack {
      AdonisTheme.canvas
        .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          detailHeader

          if let group {
            ForEach(group.records) { record in
              Button {
                selectedRecord = record
              } label: {
                SeasonalBloomRecordCard(record: record, season: seasonID.season)
              }
              .buttonStyle(StickerButtonStyle())
              .accessibilityElement(children: .combine)
              .accessibilityLabel(
                "\(record.title)，\(AdonisDateText.longDate(record.createdAt))，Bloom No. \(String(format: "%03d", record.bloomNumber))"
              )
              .accessibilityHint("打开这天的 OOTD")
              .accessibilityIdentifier("seasonal-bloom-record")
            }
          } else {
            EmptyGardenView(
              title: "这个季节暂时空了",
              message: "你删除了它最后一条 OOTD；新的收藏会按日期自动回来。",
              systemImage: "wind"
            )
            .padding(.horizontal, 12)
            .paperSurface()
            .accessibilityIdentifier("seasonal-bloom-empty")
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 36)
      }
      .scrollIndicators(.hidden)
      .accessibilityIdentifier("seasonal-bloom-detail")
    }
    .navigationTitle(seasonID.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("完成") {
          onClose()
        }
        .accessibilityIdentifier("close-seasonal-bloom")
      }
    }
    .sheet(item: $selectedRecord) { record in
      NavigationStack {
        OutfitDetailView(record: record) {
          onDelete(record)
          selectedRecord = nil
        }
      }
    }
  }

  private var detailHeader: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: seasonID.season.symbolName)
        .font(.system(size: 24, weight: .black))
        .foregroundStyle(AdonisTheme.ink)
        .frame(width: 56, height: 56)
        .background(seasonID.season.primaryColor.opacity(0.66), in: Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 5) {
        Text("\(seasonID.title) · \(seasonID.moodTitle)")
          .font(.system(.title2, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .fixedSize(horizontal: false, vertical: true)
        Text("\(group?.records.count ?? 0) 次盛开 · \(seasonID.dateRangeTitle)")
          .font(.subheadline)
          .foregroundStyle(AdonisTheme.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
    .padding(16)
    .background(
      LinearGradient(
        colors: [
          seasonID.season.primaryColor.opacity(0.28),
          seasonID.season.secondaryColor.opacity(0.20),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 24, style: .continuous)
    )
  }
}

private struct SeasonalBloomGroupCard: View {
  let group: SeasonalBloomGroup

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ZStack(alignment: .bottomTrailing) {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .fill(
            LinearGradient(
              colors: [
                group.season.primaryColor.opacity(0.48),
                group.season.secondaryColor.opacity(0.24),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )

        SeasonalStickerStack(records: Array(group.records.prefix(3)))
          .padding(10)

        Text(group.season.title)
          .font(.system(size: 28, weight: .black, design: .rounded))
          .foregroundStyle(AdonisTheme.ink.opacity(0.15))
          .padding(12)
      }
      .aspectRatio(1.16, contentMode: .fit)
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 5) {
        Text("\(group.title) · \(group.moodTitle)")
          .font(.system(.headline, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
        Text("\(group.records.count) 次盛开")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(AdonisTheme.pomegranateInk)
        Text(group.dateRangeTitle)
          .font(.caption)
          .foregroundStyle(AdonisTheme.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 3)
    }
    .padding(10)
    .background(AdonisTheme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(AdonisTheme.ink.opacity(0.07), lineWidth: 1)
    }
    .shadow(color: AdonisTheme.ink.opacity(0.08), radius: 12, y: 6)
  }
}

private struct SeasonalBloomRecordCard: View {
  let record: OutfitRecord
  let season: BloomSeason

  var body: some View {
    HStack(spacing: 14) {
      StoredImageView(filename: record.stickerImageFilename, contentMode: .fit)
        .padding(7)
        .frame(width: 88, height: 110)
        .background(
          LinearGradient(
            colors: [season.primaryColor.opacity(0.38), season.secondaryColor.opacity(0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )

      VStack(alignment: .leading, spacing: 7) {
        Text(record.title)
          .font(.system(.headline, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .lineLimit(2)
        Text(AdonisDateText.longDate(record.createdAt))
          .font(.subheadline)
          .foregroundStyle(AdonisTheme.secondaryInk)
        Text("Bloom No. \(String(format: "%03d", record.bloomNumber))")
          .font(.system(.caption, design: .monospaced, weight: .semibold))
          .foregroundStyle(AdonisTheme.pomegranateInk)
      }

      Spacer(minLength: 0)
      Image(systemName: "chevron.right")
        .foregroundStyle(AdonisTheme.secondaryInk)
        .accessibilityHidden(true)
    }
    .padding(10)
    .background(AdonisTheme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .shadow(color: AdonisTheme.ink.opacity(0.07), radius: 9, y: 4)
  }
}

private struct SeasonalStickerStack: View {
  let records: [OutfitRecord]

  var body: some View {
    ZStack {
      ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
        StoredImageView(filename: record.stickerImageFilename, contentMode: .fit)
          .padding(4)
          .frame(width: 64, height: 82)
          .background(.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 14))
          .rotationEffect(.degrees(Double(index - 1) * 6))
          .offset(x: CGFloat(index - 1) * 14)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

extension BloomSeason {
  fileprivate var symbolName: String {
    switch self {
    case .spring: "leaf.fill"
    case .summer: "sun.max.fill"
    case .autumn: "wind"
    case .winter: "snowflake"
    }
  }

  fileprivate var primaryColor: Color {
    switch self {
    case .spring: AdonisTheme.leaf
    case .summer: AdonisTheme.butter
    case .autumn: AdonisTheme.pomegranate
    case .winter: AdonisTheme.lavender
    }
  }

  fileprivate var secondaryColor: Color {
    switch self {
    case .spring: AdonisTheme.lavender
    case .summer: AdonisTheme.pomegranate
    case .autumn: AdonisTheme.butter
    case .winter: AdonisTheme.leaf
    }
  }
}
