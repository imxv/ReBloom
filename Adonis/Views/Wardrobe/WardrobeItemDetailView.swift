import SwiftData
import SwiftUI

struct WardrobeItemDetailView: View {
  @Bindable var item: WardrobeItem
  let onDelete: () -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @State private var showDeleteConfirmation = false
  @State private var showOptionalDetails = false

  var body: some View {
    ZStack {
      AdonisTheme.canvas
        .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          StoredImageView(filename: item.imageFilename, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(height: 330)
            .background(AdonisTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
              RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AdonisTheme.ink.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: AdonisTheme.ink.opacity(0.1), radius: 14, y: 8)

          analysisSummary

          VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
              Text("不对的话，点一下改")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(AdonisTheme.ink)
              Text(categoryHelperText)
                .font(.caption)
                .foregroundStyle(AdonisTheme.secondaryInk)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 10)], spacing: 10) {
              ForEach(WardrobeCategory.allCases) { category in
                Button {
                  select(category)
                } label: {
                  Label(category.rawValue, systemImage: category.symbol)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AdonisTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                      item.category == category
                        ? AdonisTheme.butter
                        : Color.white.opacity(0.74),
                      in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(StickerButtonStyle())
                .accessibilityIdentifier("wardrobe-category-\(category.rawValue)")
              }
            }
          }

          optionalDetails

          HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
              .foregroundStyle(AdonisTheme.leaf)
              .frame(width: 22)
            Text("颜色和款式只在当前设备上分析；图片不会因为加入衣橱而上传。")
              .font(.footnote)
              .foregroundStyle(AdonisTheme.secondaryInk)
              .lineSpacing(3)
          }
          .padding(15)
          .background(
            AdonisTheme.leaf.opacity(0.11),
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
          )

          Button(role: .destructive) {
            showDeleteConfirmation = true
          } label: {
            Label("从衣橱删除", systemImage: "trash")
              .font(.system(.headline, design: .rounded, weight: .bold))
              .frame(maxWidth: .infinity, minHeight: 50)
          }
        }
        .padding(20)
      }
    }
    .navigationTitle("衣物详情")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("完成") {
          try? modelContext.save()
          dismiss()
        }
      }
    }
    .confirmationDialog("删除这件衣服？", isPresented: $showDeleteConfirmation) {
      Button("删除", role: .destructive) {
        onDelete()
        dismiss()
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("图片和备注会从当前设备移除，已有 OOTD 记录不会受影响。")
    }
    .accessibilityIdentifier("wardrobe-item-detail")
  }

  private var analysisSummary: some View {
    VStack(alignment: .leading, spacing: 15) {
      HStack(alignment: .top, spacing: 13) {
        ZStack {
          Circle()
            .fill(AdonisTheme.butter)
            .frame(width: 48, height: 48)
          Image(systemName: "checkmark")
            .font(.system(size: 18, weight: .black))
            .foregroundStyle(AdonisTheme.ink)
        }

        VStack(alignment: .leading, spacing: 4) {
          Text(item.analysisVersion == nil ? "已经收进衣橱" : "已自动记住")
            .font(.system(.headline, design: .rounded, weight: .black))
            .foregroundStyle(AdonisTheme.ink)
            .accessibilityIdentifier("wardrobe-analysis-summary")
          Text(item.name)
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.ink)
            .lineLimit(2)
        }
      }

      ScrollView(.horizontal) {
        HStack(spacing: 8) {
          if let colorName = item.dominantColorName {
            WardrobeMetadataChip(
              title: colorName,
              systemImage: "circle.fill",
              color: AdonisTheme.butter.opacity(0.5),
              colorHex: item.dominantColorHex
            )
          }
          WardrobeMetadataChip(
            title: item.sourceKind.title,
            systemImage: item.sourceKind.symbol
          )
          WardrobeMetadataChip(
            title: item.category.rawValue,
            systemImage: item.category.symbol,
            color: item.category == .uncategorized
              ? AdonisTheme.lavender.opacity(0.28)
              : AdonisTheme.leaf.opacity(0.28)
          )
        }
        .padding(.vertical, 2)
      }
      .scrollIndicators(.hidden)

      if item.category == .uncategorized {
        Text("这次没有把款式猜死，避免把错误信息写进衣橱。")
          .font(.footnote)
          .foregroundStyle(AdonisTheme.secondaryInk)
      }
    }
    .padding(18)
    .paperSurface(radius: 24)
  }

  private var optionalDetails: some View {
    DisclosureGroup(isExpanded: $showOptionalDetails) {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text("名字")
            .font(.caption.weight(.bold))
            .foregroundStyle(AdonisTheme.secondaryInk)
          TextField("例如：经常穿的黑色外套", text: $item.name)
            .textFieldStyle(.plain)
            .padding(.horizontal, 15)
            .frame(minHeight: 48)
            .background(
              .white.opacity(0.8),
              in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("备注")
            .font(.caption.weight(.bold))
            .foregroundStyle(AdonisTheme.secondaryInk)
          TextField("品牌、颜色或你为什么喜欢它", text: $item.note, axis: .vertical)
            .lineLimit(3...6)
            .padding(15)
            .background(
              .white.opacity(0.8),
              in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
        }
      }
      .padding(.top, 15)
    } label: {
      Label("补充名字或备注（可选）", systemImage: "pencil.line")
        .font(.system(.headline, design: .rounded, weight: .bold))
        .foregroundStyle(AdonisTheme.ink)
        .frame(minHeight: 44)
    }
    .padding(17)
    .background(
      AdonisTheme.paper,
      in: RoundedRectangle(cornerRadius: 22, style: .continuous)
    )
  }

  private var categoryHelperText: String {
    item.category == .uncategorized
      ? "不确定也没关系，未分类不会影响以后使用。"
      : "已经按你的选择更新，之后随时可以再改。"
  }

  @MainActor
  private func select(_ category: WardrobeCategory) {
    guard item.category != category else { return }
    let previousCategory = item.category
    let color = item.dominantColorName ?? ""
    let generatedNames = [
      "新单品",
      "\(color)单品",
      previousCategory == .uncategorized ? "" : "\(color)\(previousCategory.rawValue)",
      previousCategory == .uncategorized ? "" : previousCategory.rawValue,
    ]
    let shouldRefreshName = item.analysisVersion != nil && generatedNames.contains(item.name)

    item.category = category
    if shouldRefreshName {
      item.name =
        category == .uncategorized
        ? (color.isEmpty ? "新单品" : "\(color)单品")
        : "\(color)\(category.rawValue)"
    }
    try? modelContext.save()
    EventLogger.log(
      .wardrobeItemCorrected,
      detail: "category=\(previousCategory.rawValue)->\(category.rawValue)",
      processingVersion: item.analysisVersion,
      in: modelContext
    )
  }
}
