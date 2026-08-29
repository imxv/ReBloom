import SwiftData
import SwiftUI
import UIKit

private struct RebloomSharePresentation: Identifiable {
  let id = UUID()
  let image: UIImage
}

struct RebloomView: View {
  let onDelete: (OutfitRecord) -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \OutfitRecord.createdAt, order: .reverse) private var records: [OutfitRecord]
  @Query(sort: \WardrobeItem.createdAt, order: .reverse) private var wardrobeItems: [WardrobeItem]

  @State private var selectedSuggestionID: RebloomSuggestionID?
  @State private var sharePresentation: RebloomSharePresentation?
  @State private var errorMessage: String?

  private var suggestions: [RebloomSuggestion] {
    RebloomCatalog().suggestions(records: records, wardrobeItems: wardrobeItems)
  }

  private var suggestion: RebloomSuggestion? {
    suggestions.first { $0.id == selectedSuggestionID } ?? suggestions.first
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AdonisTheme.canvas
          .ignoresSafeArea()

        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            header

            if let suggestion {
              RebloomSuggestionCard(suggestion: suggestion)

              ContentProvenanceNotice(
                provenance: .programmaticComposition,
                detail:
                  "单品图片来自你确认过的本机衣橱；Adonis 只做规则组合与排版，没有生成试穿照片，也没有改动画面中的衣服。来自 OOTD 的局部图可能带到相邻衣物，补商品图后这里会自动使用更干净的图片。",
                identifier: "rebloom-provenance"
              )

              boundaryNotice
              sourceOutfits(for: suggestion)

              if suggestions.count > 1 {
                Button {
                  showNextSuggestion()
                } label: {
                  Label("换一组真实组合", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(StickerButtonStyle())
                .accessibilityIdentifier("rebloom-next")
              }

              Button {
                makeShareCard(from: suggestion)
              } label: {
                PrimaryActionLabel(title: "分享这身", systemImage: "square.and.arrow.up")
              }
              .buttonStyle(StickerButtonStyle())
              .accessibilityIdentifier("share-rebloom")
            } else {
              EmptyGardenView(
                title: "这组搭配刚刚变了",
                message: "只有仍在衣橱、明确确认过、又没有一起穿过的上装与下装才会出现在这里。",
                systemImage: "arrow.triangle.2.circlepath"
              )
              .padding(.horizontal, 12)
              .paperSurface()
              .accessibilityIdentifier("rebloom-empty")
            }
          }
          .padding(.horizontal, 20)
          .padding(.top, 12)
          .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("rebloom-screen")
      }
      .navigationTitle("再次盛开")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") {
            dismiss()
          }
          .accessibilityIdentifier("close-rebloom")
        }
      }
      .sheet(item: $sharePresentation) { presentation in
        ActivityView(items: [presentation.image])
          .presentationDetents([.medium, .large])
      }
      .alert(
        "搭配卡还没拼好",
        isPresented: Binding(
          get: { errorMessage != nil },
          set: { if !$0 { errorMessage = nil } }
        )
      ) {
        Button("知道了", role: .cancel) {}
      } message: {
        Text(errorMessage ?? "请稍后再试。")
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 9) {
      AdonisWordmark(compact: true)
      Text("今天，让一件旧衣回来")
        .font(.system(.title2, design: .rounded, weight: .black))
        .foregroundStyle(AdonisTheme.ink)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
      Text("不用写 Prompt，也不用选模板。Adonis 从你确认过的穿着里，先递来一组可以直接采用的新组合。")
        .font(.subheadline)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var boundaryNotice: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "checkmark.seal.fill")
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(AdonisTheme.leafInk)
        .frame(width: 42, height: 42)
        .background(AdonisTheme.leaf.opacity(0.24), in: Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text("是真实衣橱建议，不是试穿结果")
          .font(.system(.subheadline, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
        Text("这两件衣物都由你明确确认过，并且从未在同一条 OOTD 中确认过；这里只给穿法清单，不预言上身效果。")
          .font(.footnote)
          .foregroundStyle(AdonisTheme.secondaryInk)
          .lineSpacing(2)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
    .padding(14)
    .background(
      AdonisTheme.leaf.opacity(0.11),
      in: RoundedRectangle(cornerRadius: 19, style: .continuous)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "是真实衣橱建议，不是试穿结果。这两件衣物都由你明确确认过，并且从未在同一条 OOTD 中确认过；这里只给穿法清单，不预言上身效果。"
    )
    .accessibilityIdentifier("rebloom-boundary")
  }

  private func sourceOutfits(for suggestion: RebloomSuggestion) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("它们原来怎么穿")
        .font(.system(.title3, design: .rounded, weight: .black))
        .foregroundStyle(AdonisTheme.ink)
        .accessibilityAddTraits(.isHeader)

      Text("点开可以核对原始 OOTD；来源记录或衣物被删除后，这组建议会自动消失。")
        .font(.footnote)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)

      ForEach(suggestion.sourceRecords) { record in
        NavigationLink {
          OutfitDetailView(record: record) {
            onDelete(record)
          }
        } label: {
          RebloomSourceOutfitCard(
            record: record,
            role: sourceRole(for: record, suggestion: suggestion)
          )
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "\(sourceRole(for: record, suggestion: suggestion))来源，\(record.title)，\(AdonisDateText.longDate(record.createdAt))，Bloom No. \(String(format: "%03d", record.bloomNumber))"
        )
        .accessibilityHint("打开原始 OOTD")
        .accessibilityIdentifier("rebloom-source-outfit")
      }
    }
  }

  private func sourceRole(
    for record: OutfitRecord,
    suggestion: RebloomSuggestion
  ) -> String {
    record.id == suggestion.top.sourceRecord.id ? "上装" : "下装"
  }

  private func showNextSuggestion() {
    guard !suggestions.isEmpty else { return }
    guard let currentID = suggestion?.id,
      let currentIndex = suggestions.firstIndex(where: { $0.id == currentID })
    else {
      selectedSuggestionID = suggestions.first?.id
      return
    }
    selectedSuggestionID = suggestions[(currentIndex + 1) % suggestions.count].id
  }

  private func makeShareCard(from suggestion: RebloomSuggestion) {
    guard
      let topImage = MediaStore.shared.image(filename: suggestion.top.item.imageFilename),
      let bottomImage = MediaStore.shared.image(filename: suggestion.bottom.item.imageFilename)
    else {
      errorMessage = "有一件已确认单品的图片暂时无法读取。原衣橱和 OOTD 没有被改动。"
      return
    }
    guard
      let image = RebloomCardRenderer().render(
        topImage: topImage,
        topName: suggestion.top.displayName,
        bottomImage: bottomImage,
        bottomName: suggestion.bottom.displayName,
        reasonTitle: suggestion.reasonTitle
      )
    else {
      errorMessage = "这组单品暂时无法排进分享卡。原衣橱和 OOTD 没有被改动。"
      return
    }

    EventLogger.log(
      .rebloomShareOpened,
      detail: "reason=\(suggestion.reasonEventValue)",
      processingVersion: AdonisProcessingVersion.rebloomSuggestion,
      in: modelContext
    )
    sharePresentation = RebloomSharePresentation(image: image)
  }
}

private struct RebloomSuggestionCard: View {
  let suggestion: RebloomSuggestion

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      AccessibilityAdaptiveStack(spacing: 8, verticalAlignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 4) {
          Text("今天可以直接照着穿")
            .font(.system(.title3, design: .rounded, weight: .black))
            .foregroundStyle(AdonisTheme.ink)
          Text(suggestion.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AdonisTheme.pomegranateInk)
            .fixedSize(horizontal: false, vertical: true)
        }
        StickerTag(
          title: "未一起穿过",
          color: AdonisTheme.butter.opacity(0.72),
          icon: "sparkles"
        )
      }

      if dynamicTypeSize.isAccessibilitySize {
        VStack(spacing: 12) {
          RebloomItemCard(use: suggestion.top, role: "上装")
          pairDivider
          RebloomItemCard(use: suggestion.bottom, role: "下装")
        }
      } else {
        HStack(spacing: 12) {
          RebloomItemCard(use: suggestion.top, role: "上装")
          Image(systemName: "multiply")
            .font(.system(size: 17, weight: .black))
            .foregroundStyle(AdonisTheme.pomegranateInk)
            .frame(width: 34, height: 34)
            .background(AdonisTheme.paper, in: Circle())
            .accessibilityHidden(true)
          RebloomItemCard(use: suggestion.bottom, role: "下装")
        }
      }

      Text(suggestion.reasonTitle)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(AdonisTheme.ink)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          AdonisTheme.butter.opacity(0.22),
          in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
    .padding(16)
    .background(
      LinearGradient(
        colors: [AdonisTheme.lavender.opacity(0.30), AdonisTheme.leaf.opacity(0.18)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 28, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(AdonisTheme.pomegranate.opacity(0.16), lineWidth: 1)
    }
    .shadow(color: AdonisTheme.ink.opacity(0.10), radius: 14, y: 7)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "今天可以直接照着穿。上装，\(suggestion.top.displayName)。下装，\(suggestion.bottom.displayName)。\(suggestion.reasonTitle)"
    )
    .accessibilityIdentifier("rebloom-card")
  }

  private var pairDivider: some View {
    Label("搭配", systemImage: "plus")
      .font(.caption.weight(.black))
      .foregroundStyle(AdonisTheme.pomegranateInk)
      .frame(maxWidth: .infinity, minHeight: 32)
      .accessibilityHidden(true)
  }
}

private struct RebloomItemCard: View {
  let use: RebloomItemUse
  let role: String

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      StoredImageView(filename: use.item.imageFilename, contentMode: .fit)
        .padding(10)
        .frame(maxWidth: .infinity)
        .aspectRatio(0.86, contentMode: .fit)
        .background(
          .white.opacity(0.84), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

      HStack(spacing: 6) {
        Text(role)
          .font(.caption2.weight(.black))
          .foregroundStyle(AdonisTheme.pomegranateInk)
        Text(use.item.sourceKind.title)
          .font(.caption2)
          .foregroundStyle(AdonisTheme.secondaryInk)
      }
      Text(use.displayName)
        .font(.system(.subheadline, design: .rounded, weight: .black))
        .foregroundStyle(AdonisTheme.ink)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
      Text("上次确认 · \(AdonisDateText.longDate(use.lastWornAt))")
        .font(.caption2)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(11)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      AdonisTheme.paper.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(AdonisTheme.ink.opacity(0.07), lineWidth: 1)
    }
  }
}

private struct RebloomSourceOutfitCard: View {
  let record: OutfitRecord
  let role: String

  var body: some View {
    HStack(spacing: 13) {
      StoredImageView(filename: record.stickerImageFilename, contentMode: .fit)
        .padding(6)
        .frame(width: 64, height: 76)
        .background(AdonisTheme.lavender.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))

      VStack(alignment: .leading, spacing: 4) {
        Text("\(role)来自这天")
          .font(.caption.weight(.bold))
          .foregroundStyle(AdonisTheme.pomegranateInk)
        Text(record.title)
          .font(.system(.subheadline, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .lineLimit(2)
        Text(AdonisDateText.longDate(record.createdAt))
          .font(.caption)
          .foregroundStyle(AdonisTheme.secondaryInk)
      }

      Spacer(minLength: 0)
      Image(systemName: "chevron.right")
        .foregroundStyle(AdonisTheme.secondaryInk)
        .accessibilityHidden(true)
    }
    .padding(11)
    .background(AdonisTheme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(AdonisTheme.ink.opacity(0.07), lineWidth: 1)
    }
  }
}
