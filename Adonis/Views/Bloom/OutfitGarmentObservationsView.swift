import SwiftData
import SwiftUI

struct OutfitGarmentObservationsView: View {
  let observations: [GarmentObservation]

  @Environment(\.modelContext) private var modelContext
  @Query(sort: \WardrobeItem.createdAt, order: .reverse) private var wardrobeItems: [WardrobeItem]
  @State private var errorMessage: String?

  private let matcher = WardrobeCandidateMatcher()

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header

      if observations.isEmpty {
        noObservationCard
      } else {
        ForEach(sortedObservations) { observation in
          GarmentObservationCard(
            observation: observation,
            candidates: matcher.candidates(for: observation, among: wardrobeItems),
            linkedItem: linkedItem(for: observation),
            onLink: { item in link(observation, to: item) },
            onReject: { rejectLinkedItem(for: observation) },
            onCreate: { createWardrobeItem(from: observation) },
            onDismiss: { dismiss(observation) },
            onResume: { resume(observation) }
          )
        }
      }
    }
    .alert(
      "没有保存成功",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )
    ) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "请稍后再试。")
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text("这天穿了什么")
          .font(.system(.title3, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .accessibilityIdentifier("garment-observation-section")
        Spacer()
        if !observations.isEmpty {
          StickerTag(
            title: "\(pendingCount) 个待确认",
            color: pendingCount == 0
              ? AdonisTheme.leaf.opacity(0.35)
              : AdonisTheme.butter.opacity(0.72),
            icon: pendingCount == 0 ? "checkmark" : "sparkles"
          )
        }
      }
      Text("只把画面里的衣服留成线索，点一下确认后才会影响衣橱。")
        .font(.footnote)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .lineSpacing(2)
    }
  }

  private var noObservationCard: some View {
    HStack(spacing: 12) {
      Image(systemName: "eye.slash")
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(AdonisTheme.secondaryInk)
        .frame(width: 44, height: 44)
        .background(AdonisTheme.lavender.opacity(0.2), in: Circle())
      VStack(alignment: .leading, spacing: 3) {
        Text("这次没有强行猜")
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
        Text("姿势或遮挡太复杂时，保持空白比写错更好。")
          .font(.footnote)
          .foregroundStyle(AdonisTheme.secondaryInk)
      }
    }
    .padding(16)
    .paperSurface(radius: 20)
  }

  private var sortedObservations: [GarmentObservation] {
    observations.sorted { lhs, rhs in
      if lhs.state == .pending, rhs.state != .pending { return true }
      if lhs.state != .pending, rhs.state == .pending { return false }
      return slotOrder(lhs.slot) < slotOrder(rhs.slot)
    }
  }

  private func slotOrder(_ slot: GarmentObservationSlot) -> Int {
    switch slot {
    case .upperBody: 0
    case .lowerBody: 1
    }
  }

  private var pendingCount: Int {
    observations.filter { $0.state == .pending }.count
  }

  private func linkedItem(for observation: GarmentObservation) -> WardrobeItem? {
    guard let id = observation.matchedWardrobeItemID else { return nil }
    return wardrobeItems.first(where: { $0.id == id })
  }

  @MainActor
  private func link(_ observation: GarmentObservation, to item: WardrobeItem) {
    observation.matchedWardrobeItemID = item.id
    observation.state = .linkedExisting
    do {
      try modelContext.save()
      EventLogger.log(
        .garmentObservationLinked,
        detail: "slot=\(observation.slot.rawValue);source=existing",
        processingVersion: WardrobeCandidateMatcher.version,
        in: modelContext
      )
    } catch {
      modelContext.rollback()
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func rejectLinkedItem(for observation: GarmentObservation) {
    if let itemID = observation.matchedWardrobeItemID {
      observation.rejectWardrobeItem(id: itemID)
    }
    observation.matchedWardrobeItemID = nil
    observation.state = .pending
    do {
      try modelContext.save()
      EventLogger.log(
        .garmentObservationRejected,
        detail: "slot=\(observation.slot.rawValue)",
        processingVersion: WardrobeCandidateMatcher.version,
        in: modelContext
      )
    } catch {
      modelContext.rollback()
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func createWardrobeItem(from observation: GarmentObservation) {
    guard let image = MediaStore.shared.image(filename: observation.previewImageFilename) else {
      errorMessage = "这条衣物线索的预览图已经不在当前设备上。"
      return
    }

    let id = UUID()
    var filename: String?
    do {
      let savedFilename = try MediaStore.shared.savePNG(
        image,
        filename: "\(id.uuidString.lowercased())-wardrobe.png"
      )
      filename = savedFilename
      let item = WardrobeItem(
        id: id,
        name: observation.displayName,
        category: observation.suggestedCategory,
        imageFilename: savedFilename,
        sourceKind: .outfitObservation,
        dominantColorName: observation.dominantColorName,
        dominantColorHex: observation.dominantColorHex,
        suggestedCategory: observation.suggestedCategory,
        imageWidth: image.cgImage?.width ?? 0,
        imageHeight: image.cgImage?.height ?? 0,
        analysisVersion: observation.observerVersion
      )
      modelContext.insert(item)
      observation.matchedWardrobeItemID = item.id
      observation.state = .createdNew
      try modelContext.save()
      EventLogger.log(
        .wardrobeItemAdded,
        detail: "source=ootd_observation;category=\(item.category.rawValue)",
        processingVersion: observation.observerVersion,
        in: modelContext
      )
      EventLogger.log(
        .garmentObservationCreatedItem,
        detail: "slot=\(observation.slot.rawValue)",
        processingVersion: WardrobeCandidateMatcher.version,
        in: modelContext
      )
    } catch {
      modelContext.rollback()
      if let filename { MediaStore.shared.delete(filename: filename) }
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func dismiss(_ observation: GarmentObservation) {
    observation.state = .dismissed
    do {
      try modelContext.save()
      EventLogger.log(
        .garmentObservationDismissed,
        detail: "slot=\(observation.slot.rawValue)",
        processingVersion: observation.observerVersion,
        in: modelContext
      )
    } catch {
      modelContext.rollback()
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func resume(_ observation: GarmentObservation) {
    observation.state = .pending
    do {
      try modelContext.save()
    } catch {
      modelContext.rollback()
      errorMessage = error.localizedDescription
    }
  }
}

private struct GarmentObservationCard: View {
  @Bindable var observation: GarmentObservation
  let candidates: [WardrobeMatchCandidate]
  let linkedItem: WardrobeItem?
  let onLink: (WardrobeItem) -> Void
  let onReject: () -> Void
  let onCreate: () -> Void
  let onDismiss: () -> Void
  let onResume: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      observationHeader
      stateContent
    }
    .padding(16)
    .paperSurface(radius: 24)
    .animation(.easeOut(duration: 0.18), value: observation.stateRawValue)
  }

  private var observationHeader: some View {
    HStack(spacing: 13) {
      StoredImageView(filename: observation.previewImageFilename, contentMode: .fit)
        .frame(width: 88, height: 94)
        .background(AdonisTheme.canvas.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(AdonisTheme.ink.opacity(0.08), lineWidth: 1)
        }

      VStack(alignment: .leading, spacing: 7) {
        Text(observation.slot.title)
          .font(.caption.weight(.bold))
          .foregroundStyle(AdonisTheme.secondaryInk)
          .accessibilityIdentifier("garment-observation-\(observation.slot.rawValue)")
        Text(observation.displayName)
          .font(.system(.headline, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
          .lineLimit(2)
        HStack(spacing: 7) {
          WardrobeColorDot(hex: observation.dominantColorHex)
          Text("画面线索")
          Text("·")
          Text("待你确认")
        }
        .font(.caption2)
        .foregroundStyle(AdonisTheme.secondaryInk)
      }
      Spacer(minLength: 0)
    }
  }

  @ViewBuilder
  private var stateContent: some View {
    switch observation.state {
    case .pending:
      pendingContent
    case .linkedExisting, .createdNew:
      linkedContent
    case .dismissed:
      dismissedContent
    }
  }

  private var pendingContent: some View {
    VStack(alignment: .leading, spacing: 11) {
      if candidates.isEmpty {
        Text("衣橱里暂时没有足够像的单品。")
          .font(.footnote)
          .foregroundStyle(AdonisTheme.secondaryInk)
      } else {
        Text("衣橱里看起来有点像")
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
        ForEach(candidates) { candidate in
          Button {
            onLink(candidate.item)
          } label: {
            CandidateRow(candidate: candidate)
          }
          .buttonStyle(StickerButtonStyle())
          .accessibilityLabel("就是\(candidate.item.name)")
          .accessibilityIdentifier("garment-candidate-\(candidate.item.name)")
        }
      }

      HStack(spacing: 10) {
        Button(action: onCreate) {
          Label("这是新衣服", systemImage: "plus")
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
              AdonisTheme.butter,
              in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityIdentifier("garment-new-\(observation.slot.rawValue)")

        Button(action: onDismiss) {
          Text("先不管")
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.secondaryInk)
            .frame(minWidth: 88, minHeight: 46)
            .background(
              .white.opacity(0.7),
              in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityIdentifier("garment-dismiss-\(observation.slot.rawValue)")
      }
    }
  }

  private var linkedContent: some View {
    VStack(alignment: .leading, spacing: 11) {
      HStack(spacing: 10) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 21, weight: .bold))
          .foregroundStyle(AdonisTheme.leaf)
        VStack(alignment: .leading, spacing: 2) {
          Text(observation.state == .createdNew ? "已收进衣橱" : "已关联到衣橱")
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.ink)
            .accessibilityIdentifier("garment-linked-\(observation.slot.rawValue)")
          Text(linkedItem?.name ?? "原单品已不在衣橱，可以重新选择。")
            .font(.footnote)
            .foregroundStyle(AdonisTheme.secondaryInk)
        }
        Spacer()
      }
      .padding(13)
      .background(
        AdonisTheme.leaf.opacity(0.14),
        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
      )

      if observation.state == .linkedExisting || linkedItem == nil {
        Button("不是这件", action: onReject)
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.secondaryInk)
          .frame(minHeight: 44)
          .accessibilityIdentifier("garment-reject-\(observation.slot.rawValue)")
      }
    }
  }

  private var dismissedContent: some View {
    HStack(spacing: 10) {
      Image(systemName: "tray")
        .foregroundStyle(AdonisTheme.secondaryInk)
      Text("已经先放着，不会影响衣橱。")
        .font(.footnote)
        .foregroundStyle(AdonisTheme.secondaryInk)
      Spacer()
      Button("再看看", action: onResume)
        .font(.system(.subheadline, design: .rounded, weight: .bold))
        .foregroundStyle(AdonisTheme.ink)
        .frame(minHeight: 44)
        .accessibilityIdentifier("garment-resume-\(observation.slot.rawValue)")
    }
  }
}

private struct CandidateRow: View {
  let candidate: WardrobeMatchCandidate

  var body: some View {
    HStack(spacing: 11) {
      StoredImageView(filename: candidate.item.imageFilename)
        .frame(width: 54, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(AdonisTheme.ink.opacity(0.08), lineWidth: 1)
        }

      VStack(alignment: .leading, spacing: 3) {
        Text(candidate.item.name)
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .foregroundStyle(AdonisTheme.ink)
          .lineLimit(1)
        Text(candidate.reasonText.isEmpty ? "信息有限，需要你确认" : candidate.reasonText)
          .font(.caption2)
          .foregroundStyle(AdonisTheme.secondaryInk)
          .lineLimit(1)
      }
      Spacer(minLength: 4)
      Text("就是它")
        .font(.system(.caption, design: .rounded, weight: .black))
        .foregroundStyle(AdonisTheme.pomegranate)
    }
    .padding(9)
    .background(
      .white.opacity(0.72),
      in: RoundedRectangle(cornerRadius: 16, style: .continuous)
    )
  }
}
