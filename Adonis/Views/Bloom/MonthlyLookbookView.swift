import SwiftUI
import UIKit

struct MonthlyLookbookPresentation: Identifiable {
  let id = UUID()
  let image: UIImage
  let month: Date
  let entryCount: Int
  let provenance: VisualContentProvenance
}

struct MonthlyLookbookView: View {
  let presentation: MonthlyLookbookPresentation

  @Environment(\.dismiss) private var dismiss
  @State private var showShare = false

  var body: some View {
    NavigationStack {
      ZStack {
        AdonisTheme.canvas
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 20) {
            header

            Image(uiImage: presentation.image)
              .resizable()
              .scaledToFit()
              .background(AdonisTheme.paper)
              .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
              .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                  .stroke(AdonisTheme.ink.opacity(0.08), lineWidth: 1)
              }
              .shadow(color: AdonisTheme.ink.opacity(0.14), radius: 18, y: 9)
              .accessibilityElement(children: .ignore)
              .accessibilityLabel(
                "\(monthTitle)月度贴纸画册，包含 \(presentation.entryCount) 次盛开"
              )
              .accessibilityIdentifier("monthly-lookbook-preview")

            ContentProvenanceNotice(
              provenance: presentation.provenance,
              detail: presentation.provenance.containsAIGeneratedPixels
                ? "这张画册包含 AI 生成贴纸，并把贴纸、日期与 Bloom 编号重新排版；Adonis 没有再次补画人物或衣物。"
                : "这张画册只把本月已经收藏的原图贴纸、日期与 Bloom 编号重新排版；没有补画人物或衣物。"
            )

            Button {
              showShare = true
            } label: {
              PrimaryActionLabel(title: "分享这本花册", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(StickerButtonStyle())
            .accessibilityIdentifier("share-monthly-lookbook")
          }
          .padding(.horizontal, 20)
          .padding(.top, 12)
          .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
      }
      .navigationTitle("月度花册")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") {
            dismiss()
          }
        }
      }
      .sheet(isPresented: $showShare) {
        ActivityView(items: [presentation.image])
          .presentationDetents([.medium, .large])
      }
    }
  }

  private var header: some View {
    VStack(spacing: 7) {
      AdonisWordmark(compact: true)
      Text(monthTitle)
        .font(.system(.title2, design: .rounded, weight: .black))
        .foregroundStyle(AdonisTheme.ink)
        .accessibilityAddTraits(.isHeader)
      Text("本月 \(presentation.entryCount) 次盛开，已经自动排好。")
        .font(.subheadline)
        .foregroundStyle(AdonisTheme.secondaryInk)
    }
    .multilineTextAlignment(.center)
  }

  private var monthTitle: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy 年 M 月"
    return formatter.string(from: presentation.month)
  }
}
