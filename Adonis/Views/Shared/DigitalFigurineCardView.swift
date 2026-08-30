import SwiftUI
import UIKit

struct DigitalFigurineCardPresentation: Identifiable {
  let id = UUID()
  let image: UIImage
  let bloomNumber: Int
  let date: Date
  let stickerProvenance: VisualContentProvenance
}

struct DigitalFigurineCardEntry: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        ZStack {
          RoundedRectangle(cornerRadius: 17, style: .continuous)
            .fill(AdonisTheme.lavender.opacity(0.46))
            .frame(width: 58, height: 58)
          Image(systemName: "cube.transparent")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(AdonisTheme.pomegranateInk)
        }
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 5) {
          Text("把这张贴纸立起来")
            .font(.system(.headline, design: .rounded, weight: .black))
            .foregroundStyle(AdonisTheme.ink)
          Text("一键放进 2.5D 手办展台，贴纸内容保持不变。")
            .font(.footnote)
            .foregroundStyle(AdonisTheme.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 0)

        Image(systemName: "arrow.up.right")
          .font(.system(size: 15, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .frame(width: 38, height: 38)
          .background(AdonisTheme.butter.opacity(0.64), in: Circle())
          .accessibilityHidden(true)
      }
      .padding(15)
      .background(
        LinearGradient(
          colors: [AdonisTheme.lavender.opacity(0.18), AdonisTheme.butter.opacity(0.23)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(AdonisTheme.pomegranate.opacity(0.14), lineWidth: 1)
      }
    }
    .buttonStyle(StickerButtonStyle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("制作数字手办收藏卡，一键放进 2.5D 展台，贴纸内容保持不变")
    .accessibilityIdentifier("digital-figurine-card-entry")
  }
}

struct DigitalFigurineCardView: View {
  let presentation: DigitalFigurineCardPresentation
  let onShare: () -> Void

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
                "数字手办收藏卡，Bloom No. \(String(format: "%03d", presentation.bloomNumber))"
              )
              .accessibilityIdentifier("digital-figurine-card-preview")

            AccessibilityAdaptiveStack(spacing: 8) {
              StickerTag(
                title: "1080 × 1440",
                color: AdonisTheme.butter,
                icon: "rectangle.portrait"
              )
              StickerTag(
                title: "2.5D 程序展台",
                color: AdonisTheme.lavender.opacity(0.55),
                icon: "cube.transparent"
              )
            }

            ContentProvenanceNotice(
              provenance: DigitalFigurineCardRenderer.provenance(
                for: presentation.stickerProvenance
              ),
              detail: presentation.stickerProvenance.containsAIGeneratedPixels
                ? "人物、衣物、姿势与纯白边沿用 AI 贴纸像素；Adonis 只添加展台、透明罩、投影和文字，没有再次重绘人物或衣物。"
                : "人物、衣物、姿势与纯白边沿用原图贴纸像素；Adonis 只添加展台、透明罩、投影和文字，没有重绘人物或衣物。",
              identifier: "digital-figurine-card-provenance"
            )

            boundaryNotice

            Button {
              onShare()
              showShare = true
            } label: {
              PrimaryActionLabel(title: "分享手办收藏卡", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(StickerButtonStyle())
            .accessibilityIdentifier("share-digital-figurine-card")
          }
          .padding(.horizontal, 20)
          .padding(.top, 12)
          .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
      }
      .navigationTitle("数字手办")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") {
            dismiss()
          }
          .accessibilityIdentifier("close-digital-figurine-card")
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
      Text("今天的贴纸，站上展台了")
        .font(.system(.title2, design: .rounded, weight: .black))
        .foregroundStyle(AdonisTheme.ink)
        .multilineTextAlignment(.center)
        .accessibilityAddTraits(.isHeader)
      Text(
        "Bloom No. \(String(format: "%03d", presentation.bloomNumber)) · \(AdonisDateText.longDate(presentation.date))"
      )
      .font(.subheadline)
      .foregroundStyle(AdonisTheme.secondaryInk)
      .multilineTextAlignment(.center)
    }
  }

  private var boundaryNotice: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "view.3d")
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(AdonisTheme.ink)
        .frame(width: 40, height: 40)
        .background(AdonisTheme.leaf.opacity(0.24), in: Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text("这是 2.5D 展台卡")
          .font(.system(.subheadline, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
        Text("当前不是可旋转的 3D 模型，也没有补出照片里看不见的身体或衣服。")
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
      "这是 2.5D 展台卡。当前不是可旋转的 3D 模型，也没有补出照片里看不见的身体或衣服。"
    )
    .accessibilityIdentifier("digital-figurine-card-boundary")
  }
}
