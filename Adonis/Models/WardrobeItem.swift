import Foundation
import SwiftData

@Model
final class WardrobeItem {
  @Attribute(.unique) var id: UUID
  var createdAt: Date
  var name: String
  var categoryRawValue: String
  var imageFilename: String
  var note: String
  var sourceKindRawValue: String = WardrobeSourceKind.unknown.rawValue
  var dominantColorName: String?
  var dominantColorHex: String?
  var suggestedCategoryRawValue: String?
  var categoryConfidence: Double?
  var cleanBackgroundScore: Double?
  var imageWidth: Int = 0
  var imageHeight: Int = 0
  var imageFingerprint: String?
  var analysisVersion: String?

  var category: WardrobeCategory {
    get { WardrobeCategory(rawValue: categoryRawValue) ?? .uncategorized }
    set { categoryRawValue = newValue.rawValue }
  }

  var sourceKind: WardrobeSourceKind {
    get { WardrobeSourceKind(rawValue: sourceKindRawValue) ?? .unknown }
    set { sourceKindRawValue = newValue.rawValue }
  }

  var suggestedCategory: WardrobeCategory? {
    guard let suggestedCategoryRawValue else { return nil }
    return WardrobeCategory(rawValue: suggestedCategoryRawValue)
  }

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    name: String = "新单品",
    category: WardrobeCategory = .uncategorized,
    imageFilename: String,
    note: String = "",
    sourceKind: WardrobeSourceKind = .unknown,
    dominantColorName: String? = nil,
    dominantColorHex: String? = nil,
    suggestedCategory: WardrobeCategory? = nil,
    categoryConfidence: Double? = nil,
    cleanBackgroundScore: Double? = nil,
    imageWidth: Int = 0,
    imageHeight: Int = 0,
    imageFingerprint: String? = nil,
    analysisVersion: String? = nil
  ) {
    self.id = id
    self.createdAt = createdAt
    self.name = name
    self.categoryRawValue = category.rawValue
    self.imageFilename = imageFilename
    self.note = note
    self.sourceKindRawValue = sourceKind.rawValue
    self.dominantColorName = dominantColorName
    self.dominantColorHex = dominantColorHex
    self.suggestedCategoryRawValue = suggestedCategory?.rawValue
    self.categoryConfidence = categoryConfidence
    self.cleanBackgroundScore = cleanBackgroundScore
    self.imageWidth = imageWidth
    self.imageHeight = imageHeight
    self.imageFingerprint = imageFingerprint
    self.analysisVersion = analysisVersion
  }
}

enum WardrobeCategory: String, CaseIterable, Identifiable, Sendable {
  case uncategorized = "未分类"
  case top = "上装"
  case bottom = "下装"
  case dress = "连衣裙"
  case outerwear = "外套"
  case shoes = "鞋"
  case bag = "包"
  case accessory = "配饰"

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .uncategorized: "sparkles"
    case .top: "tshirt"
    case .bottom: "figure.walk"
    case .dress: "hanger"
    case .outerwear: "jacket"
    case .shoes: "shoe"
    case .bag: "handbag"
    case .accessory: "sunglasses"
    }
  }
}

enum WardrobeSourceKind: String, CaseIterable, Identifiable, Sendable {
  case catalogImage
  case flatLay
  case unknown

  var id: String { rawValue }

  var title: String {
    switch self {
    case .catalogImage: "像商品图"
    case .flatLay: "像实拍 / 平铺"
    case .unknown: "图片"
    }
  }

  var symbol: String {
    switch self {
    case .catalogImage: "bag.fill"
    case .flatLay: "camera.fill"
    case .unknown: "photo.fill"
    }
  }
}
