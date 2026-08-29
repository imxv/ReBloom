import Foundation

struct WardrobeMatchCandidate: Identifiable {
  let item: WardrobeItem
  let score: Double
  let reasons: [String]

  var id: UUID { item.id }

  var reasonText: String {
    reasons.joined(separator: " · ")
  }
}

struct WardrobeCandidateMatcher {
  static let version = AdonisProcessingVersion.candidateMatching

  func candidates(
    for observation: GarmentObservation,
    among items: [WardrobeItem],
    limit: Int = 3
  ) -> [WardrobeMatchCandidate] {
    items
      .filter { !observation.rejectedWardrobeItemIDs.contains($0.id) }
      .compactMap { candidate(for: observation, item: $0) }
      .sorted { lhs, rhs in
        if abs(lhs.score - rhs.score) > 0.0001 { return lhs.score > rhs.score }
        return lhs.item.createdAt > rhs.item.createdAt
      }
      .prefix(max(0, limit))
      .map { $0 }
  }

  private func candidate(
    for observation: GarmentObservation,
    item: WardrobeItem
  ) -> WardrobeMatchCandidate? {
    let categoryScore: Double
    if item.category == observation.suggestedCategory {
      categoryScore = 1
    } else if item.category == .uncategorized {
      categoryScore = 0.32
    } else {
      categoryScore = 0
    }

    let colorScore = colorSimilarity(
      observation.dominantColorHex,
      item.dominantColorHex
    )
    guard categoryScore == 1 || colorScore >= 0.7 else { return nil }

    let sourceScore: Double = item.sourceKind == .catalogImage ? 1 : 0.55
    let observationConfidence = min(1, max(0, observation.confidence))
    let score =
      (categoryScore * 0.56 + colorScore * 0.36 + sourceScore * 0.08)
      * (0.86 + observationConfidence * 0.14)
    guard score >= 0.42 else { return nil }

    var reasons: [String] = []
    if categoryScore == 1 {
      reasons.append("同为\(observation.suggestedCategory.rawValue)")
    }
    if colorScore >= 0.86 {
      reasons.append("颜色很接近")
    } else if colorScore >= 0.7 {
      reasons.append("颜色接近")
    }
    if item.sourceKind == .catalogImage {
      reasons.append("有商品图")
    }
    return WardrobeMatchCandidate(item: item, score: score, reasons: reasons)
  }

  private func colorSimilarity(_ lhs: String?, _ rhs: String?) -> Double {
    guard let lhs = rgb(from: lhs), let rhs = rgb(from: rhs) else { return 0 }
    let red = Double(lhs.red - rhs.red)
    let green = Double(lhs.green - rhs.green)
    let blue = Double(lhs.blue - rhs.blue)
    let distance = sqrt(red * red + green * green + blue * blue)
    return max(0, 1 - distance / sqrt(3 * 255 * 255))
  }

  private func rgb(from hex: String?) -> (red: Int, green: Int, blue: Int)? {
    guard var hex else { return nil }
    if hex.hasPrefix("#") { hex.removeFirst() }
    guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
    return (
      red: (value >> 16) & 0xFF,
      green: (value >> 8) & 0xFF,
      blue: value & 0xFF
    )
  }
}
