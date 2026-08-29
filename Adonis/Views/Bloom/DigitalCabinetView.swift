import SwiftData
import SwiftUI

struct DigitalCabinetView: View {
  let onDelete: (OutfitRecord) -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Query(sort: \OutfitRecord.createdAt, order: .reverse) private var records: [OutfitRecord]
  @Query(sort: \WardrobeItem.createdAt, order: .reverse) private var wardrobeItems: [WardrobeItem]

  private var entries: [DigitalCabinetEntry] {
    DigitalCabinetCatalog().entries(records: records, wardrobeItems: wardrobeItems)
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
              detail: "每个展位直接读取你已收藏的透明贴纸；人物、衣服、姿势与纯白边保持原样，展柜和底座由 Adonis 程序绘制。",
              identifier: "digital-cabinet-provenance"
            )

            boundaryNotice

            if entries.isEmpty {
              EmptyGardenView(
                title: "展柜还空着",
                message: "收藏第一条 OOTD 后，它会自动站到这里，不需要再整理一次。",
                systemImage: "cabinet"
              )
              .padding(.horizontal, 12)
              .paperSurface()
              .accessibilityIdentifier("digital-cabinet-empty")
            } else {
              LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(entries) { entry in
                  NavigationLink {
                    OutfitDetailView(record: entry.record) {
                      onDelete(entry.record)
                    }
                  } label: {
                    DigitalCabinetOutfitCard(entry: entry)
                  }
                  .buttonStyle(StickerButtonStyle())
                  .accessibilityElement(children: .combine)
                  .accessibilityLabel(accessibilityLabel(for: entry))
                  .accessibilityHint("打开这天的 OOTD，可查看原图、贴纸和衣物关系")
                  .accessibilityIdentifier("digital-cabinet-outfit")
                }
              }
            }
          }
          .padding(.horizontal, 20)
          .padding(.top, 12)
          .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("digital-cabinet-screen")
      }
      .navigationTitle("我的数字展柜")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") {
            dismiss()
          }
          .accessibilityIdentifier("close-digital-cabinet")
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      AdonisWordmark(compact: true)

      Text("穿过的日子，自动站到这里")
        .font(.system(.title2, design: .rounded, weight: .black))
        .foregroundStyle(AdonisTheme.ink)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)

      Text("不用新建收藏，也不用选模板。点任意展位，就能回到当天的 OOTD 和衣物线索。")
        .font(.subheadline)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)

      AccessibilityAdaptiveStack(spacing: 8) {
        StickerTag(
          title: "\(entries.count) 个贴纸手办",
          color: AdonisTheme.butter,
          icon: "person.crop.rectangle.stack"
        )
        StickerTag(
          title: "自动按最近排列",
          color: AdonisTheme.leaf.opacity(0.42),
          icon: "arrow.down"
        )
      }
    }
  }

  private var boundaryNotice: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "cube.transparent")
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(AdonisTheme.ink)
        .frame(width: 40, height: 40)
        .background(AdonisTheme.leaf.opacity(0.24), in: Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text("这是可追溯的贴纸展柜")
          .font(.system(.subheadline, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
        Text("当前展位不是可旋转的 3D 模型；没有确认的衣物只会标成“待确认”，不会被当作事实。")
          .font(.footnote)
          .foregroundStyle(AdonisTheme.secondaryInk)
          .lineSpacing(2)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
    .padding(14)
    .background(
      AdonisTheme.leaf.opacity(0.10),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "这是可追溯的贴纸展柜。当前展位不是可旋转的 3D 模型；没有确认的衣物只会标成待确认，不会被当作事实。"
    )
    .accessibilityIdentifier("digital-cabinet-boundary")
  }

  private func accessibilityLabel(for entry: DigitalCabinetEntry) -> String {
    "Bloom No. \(String(format: "%03d", entry.record.bloomNumber))，\(entry.record.title)，\(AdonisDateText.longDate(entry.record.createdAt))，\(entry.relationshipSummary)"
  }
}

private struct DigitalCabinetOutfitCard: View {
  let entry: DigitalCabinetEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 11) {
      DigitalCabinetStage(
        stickerFilename: entry.record.stickerImageFilename,
        bloomNumber: entry.record.bloomNumber
      )

      VStack(alignment: .leading, spacing: 5) {
        Text(entry.record.title)
          .font(.system(.headline, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .lineLimit(2)

        Text(AdonisDateText.longDate(entry.record.createdAt))
          .font(.caption)
          .foregroundStyle(AdonisTheme.secondaryInk)

        Label(entry.relationshipSummary, systemImage: relationshipSymbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(relationshipColor)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 4)

      HStack(spacing: 5) {
        Text("查看这天")
        Image(systemName: "arrow.right")
      }
      .font(.system(.caption, design: .rounded, weight: .black))
      .foregroundStyle(AdonisTheme.pomegranateInk)
      .padding(.horizontal, 4)
    }
    .padding(10)
    .background(AdonisTheme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(AdonisTheme.ink.opacity(0.07), lineWidth: 1)
    }
    .shadow(color: AdonisTheme.ink.opacity(0.09), radius: 12, y: 6)
  }

  private var relationshipSymbol: String {
    if !entry.linkedGarments.isEmpty { return "checkmark.seal.fill" }
    if entry.pendingGarmentCount > 0 { return "questionmark.circle.fill" }
    if entry.missingLinkedGarmentCount > 0 { return "exclamationmark.triangle.fill" }
    return "tag.slash"
  }

  private var relationshipColor: Color {
    if !entry.linkedGarments.isEmpty { return AdonisTheme.leafInk }
    if entry.pendingGarmentCount > 0 { return AdonisTheme.pomegranateInk }
    return AdonisTheme.secondaryInk
  }
}

struct DigitalCabinetStage: View {
  let stickerFilename: String
  let bloomNumber: Int
  var compact = false

  var body: some View {
    ZStack(alignment: .bottom) {
      RoundedRectangle(cornerRadius: compact ? 15 : 20, style: .continuous)
        .fill(
          LinearGradient(
            colors: [AdonisTheme.lavender.opacity(0.38), AdonisTheme.butter.opacity(0.20)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      RoundedRectangle(cornerRadius: compact ? 11 : 15, style: .continuous)
        .fill(.white.opacity(0.26))
        .overlay {
          RoundedRectangle(cornerRadius: compact ? 11 : 15, style: .continuous)
            .stroke(.white.opacity(0.82), lineWidth: compact ? 1 : 2)
        }
        .padding(compact ? 6 : 9)

      Ellipse()
        .fill(AdonisTheme.ink.opacity(0.13))
        .frame(width: compact ? 42 : 86, height: compact ? 9 : 16)
        .blur(radius: compact ? 2 : 4)
        .offset(y: compact ? -9 : -15)

      StoredImageView(filename: stickerFilename, contentMode: .fit)
        .padding(.horizontal, compact ? 7 : 13)
        .padding(.top, compact ? 6 : 10)
        .padding(.bottom, compact ? 10 : 20)

      VStack(spacing: 0) {
        Spacer()
        Capsule()
          .fill(AdonisTheme.paper)
          .frame(height: compact ? 8 : 13)
          .overlay {
            Capsule()
              .stroke(AdonisTheme.ink.opacity(0.10), lineWidth: 1)
          }
          .padding(.horizontal, compact ? 5 : 10)
          .padding(.bottom, compact ? 3 : 5)
      }

      Text(String(format: "%03d", bloomNumber))
        .font(.system(size: compact ? 7 : 10, weight: .black, design: .monospaced))
        .foregroundStyle(AdonisTheme.ink)
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, compact ? 3 : 4)
        .background(AdonisTheme.butter.opacity(0.90), in: Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(compact ? 5 : 8)
    }
    .aspectRatio(0.82, contentMode: .fit)
    .accessibilityHidden(true)
  }
}
