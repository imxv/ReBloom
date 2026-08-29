import SwiftData
import SwiftUI

struct WardrobeItemDetailView: View {
  @Bindable var item: WardrobeItem
  let onDelete: () -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @State private var showDeleteConfirmation = false

  var body: some View {
    ZStack {
      AdonisTheme.canvas
        .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          StoredImageView(filename: item.imageFilename, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .background(AdonisTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: AdonisTheme.ink.opacity(0.1), radius: 14, y: 8)

          VStack(alignment: .leading, spacing: 10) {
            Text("给它一个轻松的名字")
              .font(.system(.headline, design: .rounded, weight: .bold))
              .foregroundStyle(AdonisTheme.ink)
            TextField("例如：经常穿的黑色外套", text: $item.name)
              .textFieldStyle(.plain)
              .padding(.horizontal, 16)
              .frame(minHeight: 50)
              .background(
                .white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }

          VStack(alignment: .leading, spacing: 12) {
            Text("它属于哪一类？")
              .font(.system(.headline, design: .rounded, weight: .bold))
              .foregroundStyle(AdonisTheme.ink)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 10)], spacing: 10) {
              ForEach(WardrobeCategory.allCases) { category in
                Button {
                  item.category = category
                  try? modelContext.save()
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
              }
            }
          }

          VStack(alignment: .leading, spacing: 10) {
            Text("随手记一点")
              .font(.system(.headline, design: .rounded, weight: .bold))
              .foregroundStyle(AdonisTheme.ink)
            TextField("品牌、颜色或你为什么喜欢它", text: $item.note, axis: .vertical)
              .lineLimit(3...6)
              .padding(16)
              .background(
                .white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }

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
  }
}
