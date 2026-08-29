import SwiftData
import SwiftUI

struct OutfitDetailView: View {
  @Bindable var record: OutfitRecord
  let onDelete: () -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @State private var showShare = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    ZStack {
      AdonisTheme.canvas
        .ignoresSafeArea()

      ScrollView {
        VStack(spacing: 22) {
          StoredImageView(filename: record.cardImageFilename, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: AdonisTheme.ink.opacity(0.14), radius: 16, y: 9)

          VStack(alignment: .leading, spacing: 12) {
            TextField("今日穿搭", text: $record.title)
              .font(.system(.title2, design: .rounded, weight: .black))
              .foregroundStyle(AdonisTheme.ink)

            Text(AdonisDateText.dateAndTime(record.createdAt))
              .font(.subheadline)
              .foregroundStyle(AdonisTheme.secondaryInk)

            TextField("给今天留一句话", text: $record.note, axis: .vertical)
              .lineLimit(2...5)
              .padding(14)
              .background(
                .white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }

          Button {
            showShare = true
          } label: {
            PrimaryActionLabel(title: "分享这次盛开", systemImage: "square.and.arrow.up")
          }
          .buttonStyle(StickerButtonStyle())

          Button(role: .destructive) {
            showDeleteConfirmation = true
          } label: {
            Label("删除这条记录", systemImage: "trash")
              .font(.system(.headline, design: .rounded, weight: .bold))
              .frame(maxWidth: .infinity, minHeight: 50)
          }
        }
        .padding(20)
      }
    }
    .navigationTitle("Bloom No. \(String(format: "%03d", record.bloomNumber))")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("完成") {
          try? modelContext.save()
          dismiss()
        }
      }
    }
    .sheet(isPresented: $showShare) {
      if let image = MediaStore.shared.image(filename: record.cardImageFilename) {
        ActivityView(items: [image])
          .presentationDetents([.medium, .large])
      }
    }
    .confirmationDialog("删除这一天？", isPresented: $showDeleteConfirmation) {
      Button("删除", role: .destructive) {
        onDelete()
        dismiss()
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("原图、贴纸和收藏卡都会从当前设备移除。")
    }
  }
}
