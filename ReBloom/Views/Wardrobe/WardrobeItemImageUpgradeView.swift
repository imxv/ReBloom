import PhotosUI
import SwiftData
import SwiftUI

enum WardrobeItemImageUpgradePresentation {
  case standalone
  case embedded
}

struct WardrobeItemImageUpgradeView: View {
  @Bindable var item: WardrobeItem
  let presentation: WardrobeItemImageUpgradePresentation
  let accessibilitySuffix: String

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \WardrobeItem.createdAt, order: .reverse) private var wardrobeItems: [WardrobeItem]

  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var isProcessing = false
  @State private var errorMessage: String?

  var body: some View {
    content
      .padding(presentation == .standalone ? 18 : 0)
      .background {
        if presentation == .standalone {
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(AdonisTheme.paper)
        }
      }
      .onChange(of: selectedPhotoItem) { _, newItem in
        guard let newItem else { return }
        Task { await upgrade(from: newItem) }
      }
      .alert(
        "没有更新成功",
        isPresented: Binding(
          get: { errorMessage != nil },
          set: { if !$0 { errorMessage = nil } }
        )
      ) {
        Button("知道了", role: .cancel) {}
      } message: {
        Text(errorMessage ?? "请换一张图片再试。")
      }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: isUpgraded ? "checkmark.seal.fill" : "photo.badge.plus")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(isUpgraded ? AdonisTheme.leafInk : AdonisTheme.pomegranateInk)
          .frame(width: 42, height: 42)
          .background(
            (isUpgraded ? AdonisTheme.leaf : AdonisTheme.butter).opacity(0.18),
            in: Circle()
          )

        VStack(alignment: .leading, spacing: 4) {
          Text(isUpgraded ? "已经换成更清楚的图" : "有商品图的话，补一下会更准")
            .font(.system(.subheadline, design: .rounded, weight: .black))
            .foregroundStyle(AdonisTheme.ink)
            .accessibilityIdentifier(
              isUpgraded
                ? "wardrobe-image-upgrade-success-\(accessibilitySuffix)"
                : "wardrobe-image-upgrade-prompt-\(accessibilitySuffix)"
            )
          Text(helperText)
            .font(.footnote)
            .foregroundStyle(AdonisTheme.secondaryInk)
            .lineSpacing(2)
            .accessibilityIdentifier("wardrobe-image-upgrade-source-\(accessibilitySuffix)")
        }
        Spacer(minLength: 0)
      }

      if isProcessing {
        HStack(spacing: 10) {
          ProgressView()
            .tint(AdonisTheme.ink)
          Text("正在认颜色和图片类型…")
            .font(.system(.footnote, design: .rounded, weight: .semibold))
            .foregroundStyle(AdonisTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .accessibilityIdentifier("wardrobe-image-upgrade-progress-\(accessibilitySuffix)")
      } else {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
          Label(isUpgraded ? "换一张" : "补一张更清楚的图", systemImage: "photo.on.rectangle")
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
              isUpgraded ? AdonisTheme.leaf.opacity(0.16) : AdonisTheme.butter,
              in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityIdentifier("wardrobe-image-upgrade-picker-\(accessibilitySuffix)")

        if isUITestingWardrobeImport {
          Button {
            Task { await upgradeUsingTestImage() }
          } label: {
            Text("使用测试商品图")
              .font(.system(.caption, design: .rounded, weight: .bold))
              .foregroundStyle(AdonisTheme.secondaryInk)
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(StickerButtonStyle())
          .accessibilityIdentifier("wardrobe-image-upgrade-test-\(accessibilitySuffix)")
        }
      }
    }
    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isUpgraded)
  }

  private var isUpgraded: Bool {
    item.sourceKind != .outfitObservation
  }

  private var helperText: String {
    if isUpgraded {
      return "现在识别为「\(item.sourceKind.title)」，仍是衣橱里的同一件。"
    }
    return "会更新这件衣服，不会再新增一件。现在没有也可以跳过。"
  }

  private var isUITestingWardrobeImport: Bool {
    ProcessInfo.processInfo.arguments.contains("-ui-testing-wardrobe-import")
  }

  @MainActor
  private func upgrade(from photoItem: PhotosPickerItem) async {
    do {
      guard let data = try await photoItem.loadTransferable(type: Data.self) else {
        throw WardrobeImageAnalysisError.unreadableImage
      }
      await performUpgrade(data: data, inputSource: .photoLibrary)
    } catch {
      selectedPhotoItem = nil
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func upgradeUsingTestImage() async {
    guard let data = WardrobeTestImageFactory.blueCatalogShirt().pngData() else {
      errorMessage = MediaStoreError.encodingFailed.localizedDescription
      return
    }
    await performUpgrade(data: data, inputSource: .testFixture)
  }

  @MainActor
  private func performUpgrade(data: Data, inputSource: EventInputSource) async {
    guard !isProcessing else { return }
    isProcessing = true
    EventLogger.log(
      .wardrobeImageUpgradeStarted,
      inputSource: inputSource,
      processingVersion: AdonisProcessingVersion.wardrobeImageUpgrade,
      in: modelContext
    )

    do {
      let result = try await WardrobeItemImageUpgradeService().upgrade(
        item: item,
        with: data,
        among: wardrobeItems,
        in: modelContext
      )
      EventLogger.log(
        .wardrobeImageUpgradeSucceeded,
        durationMilliseconds: result.analysis.processingMilliseconds,
        detail: "source=\(result.analysis.sourceKind.rawValue);same_item=true",
        inputSource: inputSource,
        processingVersion: AdonisProcessingVersion.wardrobeImageUpgrade,
        in: modelContext
      )
    } catch {
      EventLogger.log(
        .wardrobeImageUpgradeFailed,
        detail: error.localizedDescription,
        inputSource: inputSource,
        processingVersion: AdonisProcessingVersion.wardrobeImageUpgrade,
        in: modelContext
      )
      errorMessage = error.localizedDescription
    }

    selectedPhotoItem = nil
    isProcessing = false
  }
}
