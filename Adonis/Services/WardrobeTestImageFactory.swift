import UIKit

enum WardrobeTestImageFactory {
  static func brownCatalogShirt() -> UIImage {
    catalogShirt(color: UIColor(red: 0.42, green: 0.24, blue: 0.12, alpha: 1))
  }

  static func blueCatalogShirt() -> UIImage {
    catalogShirt(color: UIColor(red: 0.12, green: 0.34, blue: 0.72, alpha: 1))
  }

  private static func catalogShirt(color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: CGSize(width: 480, height: 640), format: format).image {
      context in
      UIColor.white.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 480, height: 640))

      let shirt = UIBezierPath()
      shirt.move(to: CGPoint(x: 175, y: 135))
      shirt.addLine(to: CGPoint(x: 110, y: 170))
      shirt.addLine(to: CGPoint(x: 52, y: 270))
      shirt.addLine(to: CGPoint(x: 130, y: 315))
      shirt.addLine(to: CGPoint(x: 155, y: 275))
      shirt.addLine(to: CGPoint(x: 155, y: 520))
      shirt.addLine(to: CGPoint(x: 325, y: 520))
      shirt.addLine(to: CGPoint(x: 325, y: 275))
      shirt.addLine(to: CGPoint(x: 350, y: 315))
      shirt.addLine(to: CGPoint(x: 428, y: 270))
      shirt.addLine(to: CGPoint(x: 370, y: 170))
      shirt.addLine(to: CGPoint(x: 305, y: 135))
      shirt.addCurve(
        to: CGPoint(x: 175, y: 135),
        controlPoint1: CGPoint(x: 286, y: 210),
        controlPoint2: CGPoint(x: 194, y: 210)
      )
      shirt.close()
      color.setFill()
      shirt.fill()
    }
  }
}
