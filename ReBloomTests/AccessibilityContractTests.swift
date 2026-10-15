import SwiftUI
import UIKit
import XCTest

@testable import Adonis

final class AccessibilityContractTests: XCTestCase {
  func testTextColorsMeetAAContrastOnAppSurfaces() throws {
    let textColors = [
      ("ink", AdonisTheme.ink),
      ("secondaryInk", AdonisTheme.secondaryInk),
      ("pomegranateInk", AdonisTheme.pomegranateInk),
      ("leafInk", AdonisTheme.leafInk),
    ]
    let surfaces = [
      ("canvas", AdonisTheme.canvas),
      ("paper", AdonisTheme.paper),
    ]

    for (textName, textColor) in textColors {
      for (surfaceName, surfaceColor) in surfaces {
        let ratio = try contrastRatio(textColor, surfaceColor)
        XCTAssertGreaterThanOrEqual(
          ratio,
          4.5,
          "\(textName) on \(surfaceName) has only \(ratio):1 contrast"
        )
      }
    }
  }

  private func contrastRatio(_ first: Color, _ second: Color) throws -> Double {
    let firstLuminance = try relativeLuminance(first)
    let secondLuminance = try relativeLuminance(second)
    let lighter = max(firstLuminance, secondLuminance)
    let darker = min(firstLuminance, secondLuminance)
    return (lighter + 0.05) / (darker + 0.05)
  }

  private func relativeLuminance(_ color: Color) throws -> Double {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    XCTAssertTrue(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))

    func linearized(_ component: CGFloat) -> Double {
      let value = Double(component)
      return value <= 0.03928
        ? value / 12.92
        : pow((value + 0.055) / 1.055, 2.4)
    }

    return 0.2126 * linearized(red)
      + 0.7152 * linearized(green)
      + 0.0722 * linearized(blue)
  }
}
