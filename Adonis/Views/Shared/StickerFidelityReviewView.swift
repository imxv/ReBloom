import SwiftUI

enum StickerFidelityReviewSheetDestination: String, Identifiable {
  case review

  var id: String { rawValue }
}

struct StickerFidelityReviewEntry: View {
  let review: StickerFidelityReview?
  let onMatches: () -> Void
  let onChanged: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "person.crop.rectangle.stack.fill")
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
          .frame(width: 42, height: 42)
          .background(AdonisTheme.lavender.opacity(0.62), in: Circle())
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 3) {
          Text("这张还像你吗？")
            .font(.system(.headline, design: .rounded, weight: .black))
            .foregroundStyle(AdonisTheme.ink)
            .accessibilityIdentifier("sticker-fidelity-review-entry")
          Text("可选。只比较原图和 AI 贴纸形象，不评价白边。")
            .font(.footnote)
            .foregroundStyle(AdonisTheme.secondaryInk)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 0)
      }

      if let review {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          Image(systemName: review.verdict == .matches ? "checkmark.circle.fill" : "eye.fill")
            .foregroundStyle(AdonisTheme.ink)
            .accessibilityHidden(true)
          Text(review.summary)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AdonisTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("sticker-fidelity-review-summary")
          Spacer(minLength: 0)
          Button("修改", action: onChanged)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AdonisTheme.ink)
            .frame(minWidth: 52, minHeight: 44)
            .accessibilityIdentifier("sticker-fidelity-review-changed")
        }
        .padding(.horizontal, 12)
        .background(
          AdonisTheme.leaf.opacity(0.16),
          in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
      } else {
        AccessibilityAdaptiveStack(spacing: 10) {
          Button(action: onMatches) {
            Label("像我", systemImage: "checkmark.circle.fill")
              .font(.system(.subheadline, design: .rounded, weight: .bold))
              .foregroundStyle(AdonisTheme.ink)
              .frame(maxWidth: .infinity, minHeight: 48)
              .background(
                AdonisTheme.leaf.opacity(0.28),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
              )
          }
          .buttonStyle(StickerButtonStyle())
          .accessibilityIdentifier("sticker-fidelity-review-matches")

          Button(action: onChanged) {
            Label("有些变了", systemImage: "eye.fill")
              .font(.system(.subheadline, design: .rounded, weight: .bold))
              .foregroundStyle(AdonisTheme.ink)
              .frame(maxWidth: .infinity, minHeight: 48)
              .background(
                AdonisTheme.butter.opacity(0.72),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
              )
          }
          .buttonStyle(StickerButtonStyle())
          .accessibilityIdentifier("sticker-fidelity-review-changed")
        }
      }

      Text("评价只保存在这台设备；没有自由文本，也不会自动上传。")
        .font(.caption)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(15)
    .background(
      AdonisTheme.paper,
      in: RoundedRectangle(cornerRadius: 20, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(AdonisTheme.lavender.opacity(0.58), lineWidth: 1)
    }
  }
}

struct StickerFidelityReviewSheet: View {
  let originalImage: UIImage
  let generatedImage: UIImage
  let initialReview: StickerFidelityReview?
  let onSave: (StickerFidelityReview) throws -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var selectedIssues: Set<StickerFidelityIssue>
  @State private var saveError: String?

  init(
    originalImage: UIImage,
    generatedImage: UIImage,
    initialReview: StickerFidelityReview?,
    onSave: @escaping (StickerFidelityReview) throws -> Void
  ) {
    self.originalImage = originalImage
    self.generatedImage = generatedImage
    self.initialReview = initialReview
    self.onSave = onSave
    _selectedIssues = State(initialValue: Set(initialReview?.issues ?? []))
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AdonisTheme.canvas
          .ignoresSafeArea()

        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            Text("原图与 AI 贴纸源图对照")
              .font(.system(.title3, design: .rounded, weight: .black))
              .foregroundStyle(AdonisTheme.ink)
              .accessibilityIdentifier("sticker-fidelity-review-sheet")

            comparison

            Text("只比较 AI 有没有改变人物与穿搭。透明边缘是否干净由另一道质量检查负责。")
              .font(.footnote)
              .foregroundStyle(AdonisTheme.secondaryInk)
              .lineSpacing(2)
              .fixedSize(horizontal: false, vertical: true)

            Button {
              submit(
                StickerFidelityReview(
                  verdict: .matches,
                  reviewedAt: .now
                )
              )
            } label: {
              PrimaryActionLabel(
                title: "人物和穿搭都对",
                systemImage: "checkmark.circle.fill"
              )
            }
            .buttonStyle(StickerButtonStyle())
            .accessibilityIdentifier("sticker-fidelity-review-confirm-matches")

            VStack(alignment: .leading, spacing: 10) {
              Text("如果有变化，点出来")
                .font(.system(.headline, design: .rounded, weight: .black))
                .foregroundStyle(AdonisTheme.ink)
                .accessibilityAddTraits(.isHeader)
              Text("可以多选；不需要写原因。")
                .font(.footnote)
                .foregroundStyle(AdonisTheme.secondaryInk)
            }

            issueGrid

            Button {
              submit(
                StickerFidelityReview(
                  verdict: .changed,
                  issues: StickerFidelityIssue.allCases.filter(selectedIssues.contains),
                  reviewedAt: .now
                )
              )
            } label: {
              Label("记下这些变化", systemImage: "bookmark.fill")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(AdonisTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                  AdonisTheme.butter.opacity(0.78),
                  in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            }
            .buttonStyle(StickerButtonStyle())
            .accessibilityIdentifier("sticker-fidelity-review-save")
          }
          .padding(20)
        }
      }
      .navigationTitle("检查这张贴纸")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("关闭") {
            dismiss()
          }
        }
      }
    }
    .alert(
      "评价没有保存",
      isPresented: Binding(
        get: { saveError != nil },
        set: { if !$0 { saveError = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(saveError ?? "请稍后再试。")
    }
  }

  @ViewBuilder
  private var comparison: some View {
    if dynamicTypeSize.isAccessibilitySize {
      VStack(spacing: 12) {
        reviewImage(
          title: "你的原图",
          image: originalImage,
          identifier: "sticker-fidelity-original-preview"
        )
        reviewImage(
          title: "AI 贴纸源图",
          image: generatedImage,
          identifier: "sticker-fidelity-generated-preview"
        )
      }
    } else {
      HStack(spacing: 12) {
        reviewImage(
          title: "你的原图",
          image: originalImage,
          identifier: "sticker-fidelity-original-preview"
        )
        reviewImage(
          title: "AI 贴纸源图",
          image: generatedImage,
          identifier: "sticker-fidelity-generated-preview"
        )
      }
    }
  }

  private var issueGrid: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 142), spacing: 10)],
      alignment: .leading,
      spacing: 10
    ) {
      ForEach(StickerFidelityIssue.allCases, id: \.self) { issue in
        let isSelected = selectedIssues.contains(issue)
        Button {
          if isSelected {
            selectedIssues.remove(issue)
          } else {
            selectedIssues.insert(issue)
          }
        } label: {
          HStack(spacing: 8) {
            Image(systemName: issue.symbol)
              .frame(width: 22)
            Text(issue.title)
              .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(AdonisTheme.ink)
          .padding(.horizontal, 12)
          .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
          .background(
            isSelected ? AdonisTheme.lavender.opacity(0.48) : .white.opacity(0.74),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
          )
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityLabel(issue.title)
        .accessibilityValue(isSelected ? "已选择" : "未选择")
        .accessibilityIdentifier("sticker-fidelity-issue-\(issue.rawValue)")
      }
    }
  }

  private func reviewImage(
    title: String,
    image: UIImage,
    identifier: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title)
        .font(.system(.caption, design: .rounded, weight: .bold))
        .foregroundStyle(AdonisTheme.ink)
      Image(uiImage: image)
        .resizable()
        .scaledToFit()
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 220)
        .background(.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel("\(title)预览")
        .accessibilityIdentifier(identifier)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func submit(_ review: StickerFidelityReview) {
    do {
      try onSave(review)
      dismiss()
    } catch {
      saveError = error.localizedDescription
    }
  }
}
