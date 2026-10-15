import SwiftData
import SwiftUI
import UIKit

struct OutfitDetailView: View {
  @Bindable var record: OutfitRecord
  let onDelete: () -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.modelContext) private var modelContext
  @State private var visualAsset: OutfitVisualAsset
  @State private var showShare = false
  @State private var fidelityReviewSheet: StickerFidelityReviewSheetDestination?
  @State private var digitalFigurineCard: DigitalFigurineCardPresentation?
  @State private var selectedCreativeWork: CreativeWorkPresentation?
  @State private var showDeleteConfirmation = false
  @State private var figurineError: String?
  @State private var creativeWorkError: String?
  @State private var fidelityReviewError: String?

  init(record: OutfitRecord, onDelete: @escaping () -> Void) {
    self.record = record
    self.onDelete = onDelete
    _visualAsset = State(
      initialValue: record.generationCompletionMode == .basicStickerFallback
        || record.stickerQualityAssessment.requiresReview ? .sticker : .shareCard
    )
  }

  var body: some View {
    ZStack {
      AdonisTheme.canvas
        .ignoresSafeArea()

      ScrollView {
        VStack(spacing: 22) {
          visualAssetPicker

          visualPreview

          if record.generationCompletionMode == .basicStickerFallback {
            GenerationFallbackNotice(
              identifier: "history-generation-fallback-notice",
              isHistory: true
            )
          }

          if record.stickerQualityAssessment.requiresReview {
            StickerQualityNotice(
              assessment: record.stickerQualityAssessment,
              detail: "这条收藏保留了当时的贴纸；边缘如果不合心意，可以回到“创作”换一张照片再做。"
            )
          }

          ContentProvenanceNotice(provenance: record.provenance(for: visualAsset))

          if fidelityGeneratedImageFilename != nil {
            StickerFidelityReviewEntry(
              review: record.stickerFidelityReview,
              onMatches: markFidelityAsMatching,
              onChanged: openFidelityReview
            )
          }

          DigitalFigurineCardEntry {
            makeDigitalFigurineCard()
          }

          if !record.creativeWorks.isEmpty {
            creativeWorksSection
          }

          OutfitGarmentObservationsView(
            observations: record.garmentObservations,
            usesAISticker: record.stickerProvenance.containsAIGeneratedPixels
          )

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
      if let image = MediaStore.shared.image(filename: selectedFilename) {
        ActivityView(items: [image])
          .presentationDetents([.medium, .large])
      }
    }
    .sheet(item: $fidelityReviewSheet) { _ in
      if let originalImage = MediaStore.shared.image(filename: record.sourceImageFilename),
        let fidelityGeneratedImageFilename,
        let generatedImage = MediaStore.shared.image(filename: fidelityGeneratedImageFilename)
      {
        StickerFidelityReviewSheet(
          originalImage: originalImage,
          generatedImage: generatedImage,
          initialReview: record.stickerFidelityReview,
          onSave: storeFidelityReview
        )
        .presentationDetents([.large])
      }
    }
    .sheet(item: $digitalFigurineCard) { presentation in
      DigitalFigurineCardView(presentation: presentation) {
        EventLogger.log(
          .digitalFigurineCardShareOpened,
          processingVersion: AdonisProcessingVersion.digitalFigurineCard,
          in: modelContext
        )
      }
    }
    .sheet(item: $selectedCreativeWork) { presentation in
      CreativeWorkView(
        presentation: presentation,
        onShareOpened: {
          EventLogger.log(
            .creativeWorkShareOpened,
            detail: presentation.draft.eventDetail,
            processingVersion: presentation.draft.recipe.version,
            in: modelContext
          )
        }
      )
      .presentationDetents([.large])
    }
    .alert(
      "手办卡还没做好",
      isPresented: Binding(
        get: { figurineError != nil },
        set: { if !$0 { figurineError = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(figurineError ?? "请稍后再试。")
    }
    .alert(
      "作品暂时打不开",
      isPresented: Binding(
        get: { creativeWorkError != nil },
        set: { if !$0 { creativeWorkError = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(creativeWorkError ?? "请稍后再试。")
    }
    .alert(
      "评价没有保存",
      isPresented: Binding(
        get: { fidelityReviewError != nil },
        set: { if !$0 { fidelityReviewError = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(fidelityReviewError ?? "请稍后再试。")
    }
    .confirmationDialog("删除这一天？", isPresented: $showDeleteConfirmation) {
      Button("删除", role: .destructive) {
        onDelete()
        dismiss()
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("原图、贴纸、收藏卡和这一天收藏的创作都会从当前设备移除。")
    }
  }

  private var fidelityGeneratedImageFilename: String? {
    guard
      StickerFidelityReview.canReview(
        stickerProvenance: record.stickerProvenance,
        hasAIStickerSource: record.aiStickerSourceImageFilename != nil
      )
    else { return nil }
    return record.stickerImageFilename
  }

  private func openFidelityReview() {
    guard
      let fidelityGeneratedImageFilename,
      MediaStore.shared.image(filename: record.sourceImageFilename) != nil,
      MediaStore.shared.image(filename: fidelityGeneratedImageFilename) != nil
    else {
      fidelityReviewError = "原图或最终 AI 贴纸暂时无法读取，收藏记录没有丢失。"
      return
    }
    fidelityReviewSheet = .review
  }

  private func markFidelityAsMatching() {
    do {
      try storeFidelityReview(
        StickerFidelityReview(
          verdict: .matches,
          reviewedAt: .now
        )
      )
    } catch {
      fidelityReviewError = error.localizedDescription
    }
  }

  private func storeFidelityReview(_ review: StickerFidelityReview) throws {
    do {
      record.setStickerFidelityReview(review)
      try modelContext.save()
    } catch {
      modelContext.rollback()
      throw error
    }
    EventLogger.log(
      .stickerFidelityReviewed,
      detail: review.eventDetail,
      processingVersion: StickerFidelityReview.version,
      in: modelContext
    )
  }

  private var creativeWorksSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 3) {
          Text("收藏的创作")
            .font(.system(.headline, design: .rounded, weight: .black))
            .foregroundStyle(AdonisTheme.ink)
          Text("从这一天继续长出来的版本")
            .font(.caption)
            .foregroundStyle(AdonisTheme.secondaryInk)
        }
        Spacer(minLength: 8)
        Text("\(record.creativeWorks.count) 张")
          .font(.caption.weight(.bold))
          .foregroundStyle(AdonisTheme.pomegranateInk)
      }

      ForEach(
        record.creativeWorks.sorted {
          $0.createdAt == $1.createdAt
            ? $0.id.uuidString < $1.id.uuidString : $0.createdAt > $1.createdAt
        }
      ) { work in
        Button {
          open(work)
        } label: {
          HStack(spacing: 13) {
            StoredImageView(filename: work.imageFilename, contentMode: .fill)
              .frame(width: 68, height: 88)
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
              .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
              Text(work.recipe.title)
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .foregroundStyle(AdonisTheme.ink)
              Text("\(work.provenance.title) · \(work.processingMilliseconds) 毫秒")
                .font(.caption)
                .foregroundStyle(AdonisTheme.secondaryInk)
              Text("可对照原图、再次分享")
                .font(.caption2)
                .foregroundStyle(AdonisTheme.secondaryInk)
            }

            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
              .font(.system(size: 13, weight: .black))
              .foregroundStyle(AdonisTheme.ink)
              .accessibilityHidden(true)
          }
          .padding(12)
          .background(
            AdonisTheme.lavender.opacity(0.2),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
          )
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityLabel(
          "\(work.recipe.title)，\(work.provenance.title)，可对照原图、再次分享"
        )
        .accessibilityIdentifier("creative-work-history-entry")
      }
    }
    .padding(16)
    .background(
      AdonisTheme.paper,
      in: RoundedRectangle(cornerRadius: 22, style: .continuous)
    )
  }

  @ViewBuilder
  private var visualPreview: some View {
    switch visualAsset {
    case .shareCard, .originalPhoto:
      StoredImageView(filename: selectedFilename, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(AdonisTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: AdonisTheme.ink.opacity(0.14), radius: 16, y: 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(previewAccessibilityLabel)

    case .sticker:
      TransparencyGridBackground()
        .overlay {
          StoredImageView(filename: selectedFilename, contentMode: .fit)
            .padding(24)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(AdonisTheme.ink.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(previewAccessibilityLabel)
    }
  }

  @ViewBuilder
  private var visualAssetPicker: some View {
    if dynamicTypeSize.isAccessibilitySize {
      Picker("查看图片", selection: $visualAsset) {
        ForEach(OutfitVisualAsset.allCases) { asset in
          Text(asset.title)
            .tag(asset)
        }
      }
      .pickerStyle(.menu)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .frame(minHeight: 52)
      .background(
        AdonisTheme.paper,
        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
      )
      .accessibilityIdentifier("history-visual-menu")
    } else {
      Picker("查看图片", selection: $visualAsset) {
        ForEach(OutfitVisualAsset.allCases) { asset in
          Text(asset.title)
            .tag(asset)
        }
      }
      .pickerStyle(.segmented)
      .accessibilityIdentifier("history-visual-picker")
    }
  }

  private var previewAccessibilityLabel: String {
    switch visualAsset {
    case .shareCard: "收藏卡预览，\(record.provenance(for: .shareCard).summary)"
    case .sticker: "透明贴纸预览，\(record.provenance(for: .sticker).summary)"
    case .originalPhoto: "这条记录的原始照片预览"
    }
  }

  private var selectedFilename: String {
    switch visualAsset {
    case .shareCard: record.cardImageFilename
    case .sticker: record.stickerImageFilename
    case .originalPhoto: record.sourceImageFilename
    }
  }

  private func makeDigitalFigurineCard() {
    guard let sticker = MediaStore.shared.image(filename: record.stickerImageFilename) else {
      figurineError = "这条收藏的透明贴纸暂时无法读取。原记录没有丢失，可以稍后再试。"
      return
    }
    guard
      let image = DigitalFigurineCardRenderer().render(
        sticker: sticker,
        bloomNumber: record.bloomNumber,
        date: record.createdAt,
        stickerProvenance: record.stickerProvenance
      )
    else {
      figurineError = "这张透明贴纸暂时无法放进展台，可以稍后再试。"
      return
    }

    EventLogger.log(
      .digitalFigurineCardCreated,
      processingVersion: AdonisProcessingVersion.digitalFigurineCard,
      in: modelContext
    )
    digitalFigurineCard = DigitalFigurineCardPresentation(
      image: image,
      bloomNumber: record.bloomNumber,
      date: record.createdAt,
      stickerProvenance: record.stickerProvenance
    )
  }

  private func open(_ work: CreativeWork) {
    guard let workImage = MediaStore.shared.image(filename: work.imageFilename),
      let sourceImage = MediaStore.shared.image(filename: record.sourceImageFilename)
    else {
      creativeWorkError = "这张作品或它的原始照片暂时无法读取。原记录没有丢失，可以稍后再试。"
      return
    }

    selectedCreativeWork = CreativeWorkPresentation(
      draft: CreativeWorkDraft(
        id: work.id,
        createdAt: work.createdAt,
        recipe: work.recipe,
        image: workImage,
        processingMilliseconds: work.processingMilliseconds,
        executionMetadata: work.executionMetadata,
        provenance: work.provenance
      ),
      sourceImage: sourceImage,
      isSaved: true
    )
  }
}
