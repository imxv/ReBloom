import SwiftUI

struct GenerationResultView: View {
  enum PreviewMode: String, CaseIterable, Identifiable {
    case card = "收藏卡"
    case sticker = "透明贴纸"

    var id: String { rawValue }
  }

  let draft: GenerationDraft
  let initiallySaved: Bool
  let onSave: () throws -> Void
  let onReset: () -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var mode: PreviewMode = .card
  @State private var isSaved: Bool
  @State private var showShare = false
  @State private var saveError: String?

  init(
    draft: GenerationDraft,
    initiallySaved: Bool,
    onSave: @escaping () throws -> Void,
    onReset: @escaping () -> Void
  ) {
    self.draft = draft
    self.initiallySaved = initiallySaved
    self.onSave = onSave
    self.onReset = onReset
    _isSaved = State(initialValue: initiallySaved)
  }

  var body: some View {
    ZStack {
      AdonisTheme.canvas
        .ignoresSafeArea()

      ScrollView {
        VStack(spacing: 20) {
          resultHeader

          Picker("预览方式", selection: $mode) {
            ForEach(PreviewMode.allCases) { mode in
              Text(mode.rawValue).tag(mode)
            }
          }
          .pickerStyle(.segmented)
          .accessibilityIdentifier("result-mode-picker")

          preview

          HStack(spacing: 8) {
            StickerTag(
              title: mode == .sticker ? "真实透明 PNG" : "1080 × 1440",
              color: mode == .sticker ? AdonisTheme.leaf.opacity(0.5) : AdonisTheme.butter,
              icon: mode == .sticker ? "checkerboard.rectangle" : "rectangle.portrait"
            )
            StickerTag(
              title: draft.usesPreparedSample
                ? "样片已预处理"
                : "\(draft.processingMilliseconds) ms",
              color: AdonisTheme.lavender.opacity(0.55),
              icon: draft.usesPreparedSample ? "checkmark.seal.fill" : "bolt.fill"
            )
          }

          if !draft.garmentObservations.isEmpty {
            wardrobeObservationHint
          }

          actionButtons
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 34)
      }
    }
    .sheet(isPresented: $showShare) {
      ActivityView(items: [mode == .card ? draft.cardImage : draft.stickerImage])
        .presentationDetents([.medium, .large])
    }
    .alert(
      "保存失败",
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

  private var wardrobeObservationHint: some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack {
        Circle()
          .fill(AdonisTheme.leaf.opacity(0.24))
          .frame(width: 44, height: 44)
        Image(systemName: "hanger")
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(isSaved ? "衣橱线索已经留好" : "还看到了穿搭里的衣服")
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
        Text(
          isSaved
            ? "有 \(draft.garmentObservations.count) 个待确认线索，确认前不会变成衣橱单品。"
            : "收藏今天后留下 \(draft.garmentObservations.count) 个线索，不需要现在整理。"
        )
        .font(.footnote)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .lineSpacing(2)
      }
      Spacer(minLength: 0)
    }
    .padding(15)
    .background(
      AdonisTheme.leaf.opacity(0.1),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("garment-observation-hint")
  }

  private var resultHeader: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("今天开了一朵花")
          .font(.system(.title2, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .accessibilityIdentifier("result-title")
        Text("Bloom No. \(String(format: "%03d", draft.bloomNumber))")
          .font(.system(.subheadline, design: .monospaced, weight: .semibold))
          .foregroundStyle(AdonisTheme.secondaryInk)
      }

      Spacer()

      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
          .frame(width: 44, height: 44)
          .background(.white.opacity(0.8), in: Circle())
      }
      .buttonStyle(StickerButtonStyle())
      .accessibilityLabel("关闭结果")
    }
  }

  @ViewBuilder
  private var preview: some View {
    switch mode {
    case .card:
      Image(uiImage: draft.cardImage)
        .resizable()
        .scaledToFit()
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: AdonisTheme.ink.opacity(0.15), radius: 18, y: 10)
        .overlay {
          RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(AdonisTheme.ink.opacity(0.08), lineWidth: 1)
        }
        .transition(.opacity)

    case .sticker:
      CheckerboardBackground()
        .overlay {
          Image(uiImage: draft.stickerImage)
            .resizable()
            .scaledToFit()
            .padding(24)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(AdonisTheme.ink.opacity(0.08), lineWidth: 1)
        }
        .transition(.opacity)
    }
  }

  private var actionButtons: some View {
    VStack(spacing: 12) {
      Button {
        do {
          try onSave()
          isSaved = true
        } catch {
          saveError = error.localizedDescription
        }
      } label: {
        PrimaryActionLabel(
          title: isSaved ? "今天已经收藏" : "收藏今天",
          systemImage: isSaved ? "checkmark.circle.fill" : "heart.fill"
        )
      }
      .buttonStyle(StickerButtonStyle())
      .disabled(isSaved)
      .accessibilityIdentifier("save-today")

      HStack(spacing: 12) {
        Button {
          showShare = true
        } label: {
          Label("分享", systemImage: "square.and.arrow.up")
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
              .white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityIdentifier("share-result")

        Button {
          onReset()
          dismiss()
        } label: {
          Label("再做一张", systemImage: "arrow.clockwise")
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
              AdonisTheme.butter.opacity(0.72),
              in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityIdentifier("make-another")
      }
    }
  }
}

private struct CheckerboardBackground: View {
  private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 10)

  var body: some View {
    GeometryReader { proxy in
      let cell = proxy.size.width / 10
      LazyVGrid(columns: columns, spacing: 0) {
        ForEach(0..<140, id: \.self) { index in
          Rectangle()
            .fill((index + index / 10).isMultiple(of: 2) ? Color.white : Color(hex: 0xE8E4E1))
            .frame(height: cell)
        }
      }
    }
    .clipped()
    .accessibilityHidden(true)
  }
}
