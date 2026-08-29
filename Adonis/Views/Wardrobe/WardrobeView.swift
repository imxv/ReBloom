import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct WardrobeView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \WardrobeItem.createdAt, order: .reverse) private var items: [WardrobeItem]

  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var selectedItem: WardrobeItem?
  @State private var errorMessage: String?
  @State private var isImporting = false
  @State private var importStage: WardrobeImportStage = .reading
  @State private var activeImportID: UUID?
  @State private var activeInputSource: EventInputSource?

  private let analyzer = WardrobeImageAnalyzer()

  private let columns = [
    GridItem(.flexible(), spacing: 14),
    GridItem(.flexible(), spacing: 14),
  ]

  var body: some View {
    ZStack {
      AdonisTheme.canvas
        .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          header

          if items.isEmpty {
            emptyState
          } else {
            categorySummary
            itemGrid
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 36)
      }
      .scrollIndicators(.hidden)
      .disabled(isImporting)

      if isImporting {
        WardrobeImportOverlay(stage: importStage, onCancel: cancelImport)
          .transition(.opacity.combined(with: .scale(scale: 0.98)))
          .zIndex(2)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .onChange(of: selectedPhotoItem) { _, newItem in
      guard let newItem else { return }
      Task { await addItem(from: newItem) }
    }
    .sheet(item: $selectedItem) { item in
      NavigationStack {
        WardrobeItemDetailView(item: item) {
          delete(item)
        }
      }
    }
    .alert(
      "没有添加成功",
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

  private var header: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 5) {
        AdonisWordmark(compact: true)
        Text("我的衣橱")
          .font(.system(size: 34, weight: .black, design: .rounded))
          .foregroundStyle(AdonisTheme.ink)
        Text("不用整理完整，先记住真正会穿的。")
          .font(.subheadline)
          .foregroundStyle(AdonisTheme.secondaryInk)
      }

      Spacer()

      PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
        Image(systemName: "plus")
          .font(.system(size: 18, weight: .black))
          .foregroundStyle(.white)
          .frame(width: 48, height: 48)
          .background(AdonisTheme.ink, in: Circle())
          .shadow(color: AdonisTheme.ink.opacity(0.15), radius: 10, y: 5)
      }
      .buttonStyle(StickerButtonStyle())
      .disabled(isImporting)
      .accessibilityLabel("添加衣服图片")
      .accessibilityIdentifier("add-wardrobe-item")
    }
  }

  private var emptyState: some View {
    VStack(spacing: 22) {
      EmptyGardenView(
        title: "衣橱还在等第一件衣服",
        message: "上传商品图、截图或平铺照片。先收下一件，不需要一次整理完。",
        systemImage: "hanger"
      )

      PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
        PrimaryActionLabel(title: "添加第一件", systemImage: "plus")
      }
      .buttonStyle(StickerButtonStyle())
      .disabled(isImporting)
      .accessibilityIdentifier("add-first-wardrobe-item")

      if isUITestingWardrobeImport {
        Button {
          Task { await addUITestingCatalogItem() }
        } label: {
          Label("添加测试商品图", systemImage: "tshirt.fill")
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
              AdonisTheme.butter.opacity(0.72),
              in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityIdentifier("add-test-wardrobe-item")
      }
    }
    .padding(22)
    .paperSurface()
  }

  private var categorySummary: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 9) {
        StickerTag(title: "\(items.count) 件", color: AdonisTheme.butter, icon: "hanger")
        if isUITestingWardrobeImport {
          Button {
            Task { await addUITestingCatalogItem() }
          } label: {
            Label("再次导入测试图", systemImage: "arrow.clockwise")
              .font(.system(.caption, design: .rounded, weight: .bold))
              .foregroundStyle(AdonisTheme.ink)
              .padding(.horizontal, 12)
              .frame(minHeight: 36)
              .background(AdonisTheme.lavender.opacity(0.3), in: Capsule())
          }
          .buttonStyle(StickerButtonStyle())
          .accessibilityIdentifier("reimport-test-wardrobe-item")
        }
        ForEach(WardrobeCategory.allCases.filter { $0 != .uncategorized }) { category in
          let count = items.filter { $0.category == category }.count
          if count > 0 {
            StickerTag(
              title: "\(category.rawValue) \(count)",
              color: AdonisTheme.leaf.opacity(0.35),
              icon: category.symbol
            )
          }
        }
      }
      .padding(.vertical, 3)
    }
    .scrollIndicators(.hidden)
  }

  private var itemGrid: some View {
    LazyVGrid(columns: columns, spacing: 14) {
      ForEach(items) { item in
        Button {
          selectedItem = item
        } label: {
          WardrobeItemCard(item: item)
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityLabel("\(item.name)，\(item.category.rawValue)")
        .accessibilityIdentifier("wardrobe-item-card")
      }
    }
  }

  @MainActor
  private func addItem(from photoItem: PhotosPickerItem) async {
    let importID = beginImport(source: .photoLibrary)
    do {
      guard let data = try await photoItem.loadTransferable(type: Data.self) else {
        throw WardrobeImageAnalysisError.unreadableImage
      }
      guard activeImportID == importID else { return }
      try await importItem(data: data, source: .photoLibrary, importID: importID)
    } catch {
      handleImportFailure(error, source: .photoLibrary, importID: importID)
    }
  }

  @MainActor
  private func addUITestingCatalogItem() async {
    let importID = beginImport(source: .testFixture)
    do {
      guard let data = WardrobeTestImageFactory.brownCatalogShirt().pngData() else {
        throw MediaStoreError.encodingFailed
      }
      try await importItem(data: data, source: .testFixture, importID: importID)
    } catch {
      handleImportFailure(error, source: .testFixture, importID: importID)
    }
  }

  @MainActor
  private func beginImport(source: EventInputSource) -> UUID {
    let importID = UUID()
    activeImportID = importID
    activeInputSource = source
    isImporting = true
    importStage = .reading
    EventLogger.log(
      .wardrobeImportStarted,
      inputSource: source,
      processingVersion: WardrobeImageAnalyzer.version,
      in: modelContext
    )
    return importID
  }

  @MainActor
  private func importItem(
    data: Data,
    source: EventInputSource,
    importID: UUID
  ) async throws {
    var savedFilename: String?
    do {
      guard activeImportID == importID else { return }
      importStage = .understanding
      let analysis = try await analyzer.analyze(data: data)
      guard activeImportID == importID else { return }
      if let existingItem = items.first(where: {
        $0.imageFingerprint == analysis.imageFingerprint
      }) {
        EventLogger.log(
          .wardrobeItemReused,
          durationMilliseconds: analysis.processingMilliseconds,
          detail: "duplicate_fingerprint",
          inputSource: source,
          processingVersion: analysis.analysisVersion,
          in: modelContext
        )
        finishImport()
        selectedItem = existingItem
        return
      }
      guard let image = UIImage(data: data) else { throw MediaStoreError.encodingFailed }

      importStage = .saving
      let id = UUID()
      let filename = try MediaStore.shared.savePNG(
        image,
        filename: "\(id.uuidString.lowercased())-wardrobe.png"
      )
      savedFilename = filename
      let item = WardrobeItem(
        id: id,
        name: analysis.suggestedName,
        category: analysis.automaticallyAssignedCategory,
        imageFilename: filename,
        sourceKind: analysis.sourceKind,
        dominantColorName: analysis.dominantColorName,
        dominantColorHex: analysis.dominantColorHex,
        suggestedCategory: analysis.suggestedCategory,
        categoryConfidence: analysis.categoryConfidence,
        cleanBackgroundScore: analysis.cleanBackgroundScore,
        imageWidth: analysis.imageWidth,
        imageHeight: analysis.imageHeight,
        imageFingerprint: analysis.imageFingerprint,
        analysisVersion: analysis.analysisVersion
      )
      modelContext.insert(item)
      try modelContext.save()
      EventLogger.log(
        .wardrobeItemAdded,
        durationMilliseconds: analysis.processingMilliseconds,
        detail: importSummary(for: item),
        inputSource: source,
        processingVersion: analysis.analysisVersion,
        in: modelContext
      )
      finishImport()
      selectedItem = item
    } catch {
      modelContext.rollback()
      if let savedFilename {
        MediaStore.shared.delete(filename: savedFilename)
      }
      throw error
    }
  }

  @MainActor
  private func handleImportFailure(
    _ error: Error,
    source: EventInputSource,
    importID: UUID
  ) {
    guard activeImportID == importID else { return }
    modelContext.rollback()
    EventLogger.log(
      .wardrobeImportFailed,
      detail: error.localizedDescription,
      inputSource: source,
      processingVersion: WardrobeImageAnalyzer.version,
      in: modelContext
    )
    finishImport()
    errorMessage = error.localizedDescription
  }

  @MainActor
  private func cancelImport() {
    guard activeImportID != nil else { return }
    activeImportID = nil
    isImporting = false
    selectedPhotoItem = nil
    EventLogger.log(
      .wardrobeImportCancelled,
      inputSource: activeInputSource,
      processingVersion: WardrobeImageAnalyzer.version,
      in: modelContext
    )
    activeInputSource = nil
  }

  @MainActor
  private func finishImport() {
    activeImportID = nil
    activeInputSource = nil
    isImporting = false
    selectedPhotoItem = nil
  }

  private func importSummary(for item: WardrobeItem) -> String {
    let color = item.dominantColorName ?? "unknown"
    return "source=\(item.sourceKind.rawValue);color=\(color);category=\(item.category.rawValue)"
  }

  private var isUITestingWardrobeImport: Bool {
    ProcessInfo.processInfo.arguments.contains("-ui-testing-wardrobe-import")
  }

  @MainActor
  private func delete(_ item: WardrobeItem) {
    let filename = item.imageFilename
    let analysisVersion = item.analysisVersion
    modelContext.delete(item)
    do {
      try modelContext.save()
      MediaStore.shared.delete(filename: filename)
      EventLogger.log(
        .wardrobeItemDeleted,
        processingVersion: analysisVersion,
        in: modelContext
      )
      selectedItem = nil
    } catch {
      modelContext.rollback()
      errorMessage = error.localizedDescription
    }
  }
}

private struct WardrobeItemCard: View {
  let item: WardrobeItem

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      StoredImageView(filename: item.imageFilename)
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 17, style: .continuous)
            .stroke(AdonisTheme.ink.opacity(0.08), lineWidth: 1)
        }

      Text(item.name)
        .font(.system(.subheadline, design: .rounded, weight: .bold))
        .foregroundStyle(AdonisTheme.ink)
        .lineLimit(1)

      HStack(spacing: 6) {
        WardrobeColorDot(hex: item.dominantColorHex)
        Text(itemMetadata)
        Spacer(minLength: 4)
        Image(systemName: item.sourceKind.symbol)
      }
      .font(.caption)
      .foregroundStyle(AdonisTheme.secondaryInk)
      .lineLimit(1)
    }
    .padding(9)
    .background(AdonisTheme.paper, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    .shadow(color: AdonisTheme.ink.opacity(0.08), radius: 10, y: 5)
  }

  private var itemMetadata: String {
    var parts: [String] = []
    if let color = item.dominantColorName { parts.append(color) }
    if item.category != .uncategorized { parts.append(item.category.rawValue) }
    return parts.isEmpty ? item.category.rawValue : parts.joined(separator: " · ")
  }
}

private enum WardrobeImportStage: String {
  case reading = "正在读取衣服图片"
  case understanding = "正在记住颜色与款式"
  case saving = "正在收进衣橱"
}

private struct WardrobeImportOverlay: View {
  let stage: WardrobeImportStage
  let onCancel: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.22)
        .ignoresSafeArea()

      VStack(spacing: 18) {
        ZStack {
          Circle()
            .fill(AdonisTheme.leaf.opacity(0.3))
            .frame(width: 82, height: 82)
          Image(systemName: "hanger")
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(AdonisTheme.ink)
        }

        VStack(spacing: 7) {
          Text(stage.rawValue)
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.ink)
          Text("不确定的内容会留给你以后再改")
            .font(.footnote)
            .foregroundStyle(AdonisTheme.secondaryInk)
        }

        Button("取消", action: onCancel)
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.secondaryInk)
          .frame(minWidth: 88, minHeight: 44)
          .buttonStyle(StickerButtonStyle())
      }
      .padding(.horizontal, 30)
      .frame(width: 304, height: 262)
      .paperSurface()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(stage.rawValue)
    .accessibilityIdentifier("wardrobe-import-overlay")
  }
}
