import SwiftUI

enum AdonisTheme {
  static let canvas = Color(hex: 0xFFF8EE)
  static let paper = Color(hex: 0xFFFCF7)
  static let ink = Color(hex: 0x291F24)
  static let secondaryInk = Color(hex: 0x706268)
  static let pomegranate = Color(hex: 0xE65564)
  static let pomegranateInk = Color(hex: 0xA03242)
  static let leaf = Color(hex: 0x82AF78)
  static let leafInk = Color(hex: 0x477042)
  static let butter = Color(hex: 0xF4D88A)
  static let lavender = Color(hex: 0xC9B8E8)

  static let largeRadius: CGFloat = 30
  static let mediumRadius: CGFloat = 22
  static let smallRadius: CGFloat = 14
}

extension Color {
  init(hex: UInt, alpha: Double = 1) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: alpha
    )
  }
}
