import Foundation

enum WardrobeItemNaming {
  static func generatedName(
    colorName: String?,
    category: WardrobeCategory
  ) -> String {
    switch (colorName, category) {
    case (let color?, let value) where value != .uncategorized:
      "\(color)\(value.rawValue)"
    case (let color?, _):
      "\(color)单品"
    case (_, let value) where value != .uncategorized:
      value.rawValue
    default:
      "新单品"
    }
  }

  static func isGeneratedName(
    _ name: String,
    colorName: String?,
    category: WardrobeCategory
  ) -> Bool {
    var generatedNames: Set<String> = [
      "新单品",
      generatedName(colorName: colorName, category: category),
    ]

    if let colorName, !colorName.isEmpty {
      generatedNames.insert("\(colorName)单品")
      if category != .uncategorized {
        generatedNames.insert("\(colorName)\(category.rawValue)")
      }
    }
    if category != .uncategorized {
      generatedNames.insert(category.rawValue)
    }

    return generatedNames.contains(name)
  }
}
