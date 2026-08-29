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

  var category: WardrobeCategory {
    get { WardrobeCategory(rawValue: categoryRawValue) ?? .uncategorized }
    set { categoryRawValue = newValue.rawValue }
  }

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    name: String = "新单品",
    category: WardrobeCategory = .uncategorized,
    imageFilename: String,
    note: String = ""
  ) {
    self.id = id
    self.createdAt = createdAt
    self.name = name
    self.categoryRawValue = category.rawValue
    self.imageFilename = imageFilename
    self.note = note
  }
}

enum WardrobeCategory: String, CaseIterable, Identifiable {
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
