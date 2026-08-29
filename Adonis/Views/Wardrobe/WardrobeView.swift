import PhotosUI
import SwiftData
import SwiftUI

struct WardrobeView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \WardrobeItem.createdAt, order: .reverse) private var items: [WardrobeItem]

  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var selectedItem: WardrobeItem?
  @State private var errorMessage: String?

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
      .accessibilityIdentifier("add-first-wardrobe-item")
    }
    .padding(22)
    .paperSurface()
  }

  private var categorySummary: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 9) {
        StickerTag(title: "\(items.count) 件", color: AdonisTheme.butter, icon: "hanger")
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
      }
    }
  }

  @MainActor
  private func addItem(from photoItem: PhotosPickerItem) async {
    var savedFilename: String?
    do {
      guard let data = try await photoItem.loadTransferable(type: Data.self),
        let image = UIImage(data: data)
      else {
        throw MediaStoreError.encodingFailed
      }

      let id = UUID()
      let filename = try MediaStore.shared.savePNG(
        image,
        filename: "\(id.uuidString.lowercased())-wardrobe.png"
      )
      savedFilename = filename
      let item = WardrobeItem(
        id: id,
        name: "新单品 \(items.count + 1)",
        imageFilename: filename
      )
      modelContext.insert(item)
      try modelContext.save()
      EventLogger.log(.wardrobeItemAdded, in: modelContext)
      selectedItem = item
      selectedPhotoItem = nil
    } catch {
      modelContext.rollback()
      if let savedFilename {
        MediaStore.shared.delete(filename: savedFilename)
      }
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func delete(_ item: WardrobeItem) {
    let filename = item.imageFilename
    modelContext.delete(item)
    do {
      try modelContext.save()
      MediaStore.shared.delete(filename: filename)
      EventLogger.log(.wardrobeItemDeleted, in: modelContext)
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

      Label(item.category.rawValue, systemImage: item.category.symbol)
        .font(.caption)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .lineLimit(1)
    }
    .padding(9)
    .background(AdonisTheme.paper, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    .shadow(color: AdonisTheme.ink.opacity(0.08), radius: 10, y: 5)
  }
}
