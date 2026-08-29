import SwiftData
import SwiftUI

struct WardrobeHistorySuggestionsView: View {
  let item: WardrobeItem

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \GarmentObservation.createdAt, order: .reverse)
  private var observations: [GarmentObservation]

  @State private var errorMessage: String?

  private let matcher = WardrobeHistoryMatcher()

  var body: some View {
    if shouldShow {
      VStack(alignment: .leading, spacing: 15) {
        header

        ForEach(candidates) { candidate in
          candidateRow(candidate)
        }

        if candidates.isEmpty, linkedHistoricalCount > 0 {
          HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 20, weight: .bold))
              .foregroundStyle(AdonisTheme.leaf)
            Text("已经确认出现在 \(linkedHistoricalCount) 天穿搭里")
              .font(.system(.subheadline, design: .rounded, weight: .bold))
              .foregroundStyle(AdonisTheme.ink)
              .accessibilityIdentifier("wardrobe-history-linked")
          }
          .padding(13)
          .background(
            AdonisTheme.leaf.opacity(0.14),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
          )

          Text("如果认错了，可以回到那天的花历记录里点“不是这件”。")
            .font(.footnote)
            .foregroundStyle(AdonisTheme.secondaryInk)
        }
      }
      .padding(18)
      .paperSurface(radius: 24)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: candidates.count)
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
  }

  private var candidates: [WardrobeHistoryCandidate] {
    matcher.candidates(for: item, among: observations)
  }

  private var linkedHistoricalCount: Int {
    Set(
      observations.compactMap { observation -> Date? in
        guard
          observation.state == .linkedExisting,
          observation.matchedWardrobeItemID == item.id,
          let outfitDate = observation.outfit?.createdAt
        else {
          return nil
        }
        return Calendar.current.startOfDay(for: outfitDate)
      }
    ).count
  }

  private var shouldShow: Bool {
    !candidates.isEmpty || linkedHistoricalCount > 0
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: candidates.isEmpty ? "calendar.badge.checkmark" : "clock.arrow.circlepath")
        .font(.system(size: 19, weight: .bold))
        .foregroundStyle(candidates.isEmpty ? AdonisTheme.leaf : AdonisTheme.pomegranate)
        .frame(width: 42, height: 42)
        .background(
          (candidates.isEmpty ? AdonisTheme.leaf : AdonisTheme.butter).opacity(0.18),
          in: Circle()
        )

      VStack(alignment: .leading, spacing: 4) {
        Text(candidates.isEmpty ? "已经连回过去的穿搭" : "过去是不是也穿过它？")
          .font(.system(.headline, design: .rounded, weight: .black))
          .foregroundStyle(AdonisTheme.ink)
        Text(
          candidates.isEmpty
            ? "只记录你亲自确认过的关系。"
            : "只找到一些画面相似的记录，要你确认后才会关联。"
        )
        .font(.footnote)
        .foregroundStyle(AdonisTheme.secondaryInk)
        .lineSpacing(2)
      }
      Spacer(minLength: 0)
    }
  }

  private func candidateRow(_ candidate: WardrobeHistoryCandidate) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        StoredImageView(filename: candidate.observation.previewImageFilename, contentMode: .fit)
          .frame(width: 72, height: 78)
          .background(AdonisTheme.canvas.opacity(0.72))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(AdonisTheme.ink.opacity(0.08), lineWidth: 1)
          }

        VStack(alignment: .leading, spacing: 4) {
          Text(AdonisDateText.longDate(candidate.outfitDate))
            .font(.caption.weight(.bold))
            .foregroundStyle(AdonisTheme.secondaryInk)
            .accessibilityIdentifier("wardrobe-history-candidate")
          Text(candidate.observation.displayName)
            .font(.system(.subheadline, design: .rounded, weight: .black))
            .foregroundStyle(AdonisTheme.ink)
          Text(candidate.reasonText.isEmpty ? "信息有限，需要你确认" : candidate.reasonText)
            .font(.caption2)
            .foregroundStyle(AdonisTheme.secondaryInk)
            .lineLimit(1)
        }
        Spacer(minLength: 0)
      }

      HStack(spacing: 10) {
        Button {
          confirm(candidate.observation)
        } label: {
          Label("是这件", systemImage: "checkmark")
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
              AdonisTheme.butter,
              in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityIdentifier("wardrobe-history-confirm")

        Button {
          reject(candidate.observation)
        } label: {
          Text("不是它")
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(AdonisTheme.secondaryInk)
            .frame(minWidth: 92, minHeight: 46)
            .background(
              .white.opacity(0.72),
              in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
        }
        .buttonStyle(StickerButtonStyle())
        .accessibilityIdentifier("wardrobe-history-reject")
      }
    }
    .padding(13)
    .background(
      AdonisTheme.canvas.opacity(0.58),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
  }

  @MainActor
  private func confirm(_ observation: GarmentObservation) {
    do {
      try WardrobeHistoryLinker.confirm(
        observation: observation,
        as: item,
        in: modelContext
      )
      EventLogger.log(
        .garmentObservationLinked,
        detail: "slot=\(observation.slot.rawValue);source=wardrobe_history",
        processingVersion: WardrobeHistoryMatcher.version,
        in: modelContext
      )
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func reject(_ observation: GarmentObservation) {
    do {
      try WardrobeHistoryLinker.reject(
        observation: observation,
        for: item,
        in: modelContext
      )
      EventLogger.log(
        .garmentObservationRejected,
        detail: "slot=\(observation.slot.rawValue);source=wardrobe_history",
        processingVersion: WardrobeHistoryMatcher.version,
        in: modelContext
      )
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
