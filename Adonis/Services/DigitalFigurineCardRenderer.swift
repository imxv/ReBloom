import UIKit

struct DigitalFigurineCardRenderer {
  static let provenance = VisualContentProvenance.programmaticComposition
  static let provenanceFooter = "人物与衣物来自原图贴纸 · 展台由 ADONIS 排版"

  private let size = CGSize(width: 1080, height: 1440)

  func render(sticker: UIImage, bloomNumber: Int, date: Date) -> UIImage? {
    guard sticker.size.width.isFinite,
      sticker.size.height.isFinite,
      sticker.size.width > 0,
      sticker.size.height > 0
    else {
      return nil
    }

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true

    return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
      let context = rendererContext.cgContext
      drawBackground(in: context)
      drawHeader(bloomNumber: bloomNumber, date: date)
      drawDisplayCase(sticker: sticker, in: context)
      drawCollectionMetadata(bloomNumber: bloomNumber)
    }
  }

  private func drawBackground(in context: CGContext) {
    Self.canvas.setFill()
    context.fill(CGRect(origin: .zero, size: size))

    let pageRect = CGRect(x: 42, y: 42, width: size.width - 84, height: size.height - 84)
    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 0, height: 20),
      blur: 42,
      color: Self.ink.withAlphaComponent(0.10).cgColor
    )
    Self.paper.setFill()
    UIBezierPath(roundedRect: pageRect, cornerRadius: 72).fill()
    context.restoreGState()

    context.saveGState()
    context.setStrokeColor(Self.ink.withAlphaComponent(0.12).cgColor)
    context.setLineWidth(3)
    context.setLineDash(phase: 0, lengths: [12, 13])
    context.addPath(UIBezierPath(roundedRect: pageRect, cornerRadius: 72).cgPath)
    context.strokePath()
    context.restoreGState()

    drawFlower(center: CGPoint(x: 126, y: 128), radius: 28, in: context)
    drawFlower(center: CGPoint(x: 956, y: 1240), radius: 24, in: context)
    drawSprig(in: context)
  }

  private func drawHeader(bloomNumber: Int, date: Date) {
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center

    ("ADONIS" as NSString).draw(
      in: CGRect(x: 260, y: 78, width: 560, height: 62),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 45, weight: .black),
        .kern: 8,
        .foregroundColor: Self.ink,
        .paragraphStyle: centered,
      ]
    )

    ("DIGITAL FIGURINE" as NSString).draw(
      in: CGRect(x: 170, y: 145, width: 740, height: 62),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 36, weight: .heavy),
        .kern: 3.2,
        .foregroundColor: Self.pomegranate,
        .paragraphStyle: centered,
      ]
    )

    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "zh_CN")
    dateFormatter.dateFormat = "yyyy.MM.dd"
    let line =
      "\(dateFormatter.string(from: date))  ·  BLOOM \(String(format: "%03d", bloomNumber))"
    (line as NSString).draw(
      in: CGRect(x: 190, y: 215, width: 700, height: 40),
      withAttributes: [
        .font: UIFont.monospacedDigitSystemFont(ofSize: 23, weight: .bold),
        .kern: 1.1,
        .foregroundColor: Self.secondaryInk,
        .paragraphStyle: centered,
      ]
    )
  }

  private func drawDisplayCase(sticker: UIImage, in context: CGContext) {
    let caseRect = CGRect(x: 128, y: 286, width: 824, height: 792)
    let casePath = UIBezierPath(roundedRect: caseRect, cornerRadius: 94)

    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 0, height: 22),
      blur: 34,
      color: Self.ink.withAlphaComponent(0.17).cgColor
    )
    Self.caseBorder.setFill()
    casePath.fill()
    context.restoreGState()

    let interiorRect = caseRect.insetBy(dx: 18, dy: 18)
    let interiorPath = UIBezierPath(roundedRect: interiorRect, cornerRadius: 78)
    context.saveGState()
    interiorPath.addClip()
    if let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: [
        Self.caseTop.cgColor,
        Self.caseMiddle.cgColor,
        Self.caseBottom.cgColor,
      ] as CFArray,
      locations: [0, 0.58, 1]
    ) {
      context.drawLinearGradient(
        gradient,
        start: CGPoint(x: interiorRect.midX, y: interiorRect.minY),
        end: CGPoint(x: interiorRect.midX, y: interiorRect.maxY),
        options: []
      )
    }
    drawCasePattern(in: interiorRect, context: context)
    context.restoreGState()

    drawPedestal(in: context)
    drawSticker(sticker, in: context)
    drawGlass(in: interiorRect, context: context)
  }

  private func drawCasePattern(in rect: CGRect, context: CGContext) {
    context.saveGState()
    context.setStrokeColor(Self.ink.withAlphaComponent(0.055).cgColor)
    context.setLineWidth(2)
    for index in 0..<9 {
      let y = rect.minY + 54 + CGFloat(index) * 72
      context.move(to: CGPoint(x: rect.minX + 34, y: y))
      context.addLine(to: CGPoint(x: rect.maxX - 34, y: y - 38))
    }
    context.strokePath()
    context.restoreGState()
  }

  private func drawPedestal(in context: CGContext) {
    let contactShadow = CGRect(x: 267, y: 916, width: 546, height: 80)
    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 0, height: 8),
      blur: 24,
      color: Self.ink.withAlphaComponent(0.24).cgColor
    )
    Self.ink.withAlphaComponent(0.12).setFill()
    context.fillEllipse(in: contactShadow)
    context.restoreGState()

    let lowerEllipse = CGRect(x: 218, y: 920, width: 644, height: 134)
    Self.pedestalSide.setFill()
    context.fillEllipse(in: lowerEllipse)

    Self.pedestalSide.setFill()
    context.fill(CGRect(x: 218, y: 878, width: 644, height: 110))

    let topEllipse = CGRect(x: 218, y: 826, width: 644, height: 136)
    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 0, height: 10),
      blur: 18,
      color: Self.ink.withAlphaComponent(0.15).cgColor
    )
    Self.pedestalTop.setFill()
    context.fillEllipse(in: topEllipse)
    context.restoreGState()

    let insetEllipse = topEllipse.insetBy(dx: 24, dy: 18)
    Self.pedestalInset.setFill()
    context.fillEllipse(in: insetEllipse)

    let labelRect = CGRect(x: 365, y: 947, width: 350, height: 58)
    Self.ink.withAlphaComponent(0.86).setFill()
    UIBezierPath(roundedRect: labelRect, cornerRadius: 17).fill()

    let centered = NSMutableParagraphStyle()
    centered.alignment = .center
    ("ADONIS · BLOOM EDITION" as NSString).draw(
      in: CGRect(x: 378, y: 963, width: 324, height: 30),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 17, weight: .heavy),
        .kern: 1.3,
        .foregroundColor: UIColor.white,
        .paragraphStyle: centered,
      ]
    )
  }

  private func drawSticker(_ sticker: UIImage, in context: CGContext) {
    let target = CGRect(x: 232, y: 336, width: 616, height: 594)
    let fitted = aspectFit(size: sticker.size, in: target)

    let floorY: CGFloat = 888
    let groundedFrame = fitted.offsetBy(dx: 0, dy: floorY - fitted.maxY)

    context.saveGState()
    context.interpolationQuality = .high
    context.setShadow(
      offset: CGSize(width: 0, height: 18),
      blur: 25,
      color: Self.ink.withAlphaComponent(0.23).cgColor
    )
    sticker.draw(in: groundedFrame)
    context.restoreGState()
  }

  private func drawGlass(in rect: CGRect, context: CGContext) {
    let glassPath = UIBezierPath(roundedRect: rect, cornerRadius: 78)

    context.saveGState()
    context.setStrokeColor(UIColor.white.withAlphaComponent(0.74).cgColor)
    context.setLineWidth(5)
    context.addPath(glassPath.cgPath)
    context.strokePath()
    context.restoreGState()

    let highlight = UIBezierPath(
      roundedRect: CGRect(
        x: rect.minX + 34,
        y: rect.minY + 44,
        width: 30,
        height: 455
      ),
      cornerRadius: 15
    )
    UIColor.white.withAlphaComponent(0.48).setFill()
    highlight.fill()

    let cornerGlow = UIBezierPath(
      ovalIn: CGRect(x: rect.maxX - 134, y: rect.minY + 28, width: 82, height: 82)
    )
    UIColor.white.withAlphaComponent(0.28).setFill()
    cornerGlow.fill()

    context.saveGState()
    context.setStrokeColor(Self.ink.withAlphaComponent(0.11).cgColor)
    context.setLineWidth(2)
    context.setLineDash(phase: 0, lengths: [8, 10])
    context.addPath(glassPath.cgPath)
    context.strokePath()
    context.restoreGState()
  }

  private func drawCollectionMetadata(bloomNumber: Int) {
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center

    let badgeRect = CGRect(x: 326, y: 1110, width: 428, height: 54)
    Self.leaf.withAlphaComponent(0.20).setFill()
    UIBezierPath(roundedRect: badgeRect, cornerRadius: 27).fill()
    ("ORIGINAL OUTFIT · 2.5D DISPLAY" as NSString).draw(
      in: CGRect(x: 340, y: 1126, width: 400, height: 28),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 17, weight: .heavy),
        .kern: 0.8,
        .foregroundColor: Self.ink,
        .paragraphStyle: centered,
      ]
    )

    ("BLOOM \(String(format: "%03d", bloomNumber)) · COLLECTIBLE" as NSString).draw(
      in: CGRect(x: 170, y: 1190, width: 740, height: 45),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 27, weight: .black),
        .kern: 1.2,
        .foregroundColor: Self.ink,
        .paragraphStyle: centered,
      ]
    )

    (Self.provenanceFooter as NSString).draw(
      in: CGRect(x: 120, y: 1260, width: 840, height: 40),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 19, weight: .semibold),
        .foregroundColor: Self.secondaryInk.withAlphaComponent(0.90),
        .paragraphStyle: centered,
      ]
    )

    ("A MOMENT, MADE TO STAND" as NSString).draw(
      in: CGRect(x: 190, y: 1324, width: 700, height: 34),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 18, weight: .bold),
        .kern: 2.1,
        .foregroundColor: Self.pomegranate.withAlphaComponent(0.88),
        .paragraphStyle: centered,
      ]
    )
  }

  private func drawFlower(center: CGPoint, radius: CGFloat, in context: CGContext) {
    for index in 0..<5 {
      context.saveGState()
      context.translateBy(x: center.x, y: center.y)
      context.rotate(by: CGFloat(index) * .pi * 2 / 5)
      (index.isMultiple(of: 2) ? Self.pomegranate : Self.tape).setFill()
      UIBezierPath(
        ovalIn: CGRect(x: -radius * 0.3, y: -radius, width: radius * 0.6, height: radius)
      ).fill()
      context.restoreGState()
    }

    Self.ink.setFill()
    context.fillEllipse(
      in: CGRect(
        x: center.x - radius * 0.2,
        y: center.y - radius * 0.2,
        width: radius * 0.4,
        height: radius * 0.4
      ))
  }

  private func drawSprig(in context: CGContext) {
    context.saveGState()
    context.setStrokeColor(Self.leaf.withAlphaComponent(0.74).cgColor)
    context.setLineWidth(7)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: 916, y: 111))
    context.addCurve(
      to: CGPoint(x: 970, y: 211),
      control1: CGPoint(x: 946, y: 138),
      control2: CGPoint(x: 957, y: 178)
    )
    context.strokePath()

    Self.leaf.setFill()
    drawLeaf(
      center: CGPoint(x: 937, y: 139),
      size: CGSize(width: 74, height: 33),
      rotation: -0.35,
      in: context
    )
    drawLeaf(
      center: CGPoint(x: 958, y: 179),
      size: CGSize(width: 68, height: 30),
      rotation: 0.30,
      in: context
    )
    context.restoreGState()
  }

  private func drawLeaf(
    center: CGPoint,
    size: CGSize,
    rotation: CGFloat,
    in context: CGContext
  ) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: rotation)
    UIBezierPath(
      ovalIn: CGRect(
        x: -size.width / 2,
        y: -size.height / 2,
        width: size.width,
        height: size.height
      )
    ).fill()
    context.restoreGState()
  }

  private func aspectFit(size source: CGSize, in target: CGRect) -> CGRect {
    guard source.width > 0, source.height > 0 else { return target }
    let scale = min(target.width / source.width, target.height / source.height)
    let fittedSize = CGSize(width: source.width * scale, height: source.height * scale)
    return CGRect(
      x: target.midX - fittedSize.width / 2,
      y: target.midY - fittedSize.height / 2,
      width: fittedSize.width,
      height: fittedSize.height
    )
  }

  private static let canvas = UIColor(red: 0.982, green: 0.908, blue: 0.824, alpha: 1)
  private static let paper = UIColor(red: 1, green: 0.990, blue: 0.962, alpha: 1)
  private static let ink = UIColor(red: 0.16, green: 0.12, blue: 0.14, alpha: 1)
  private static let secondaryInk = UIColor(red: 0.44, green: 0.38, blue: 0.41, alpha: 1)
  private static let pomegranate = UIColor(red: 0.77, green: 0.16, blue: 0.25, alpha: 1)
  private static let leaf = UIColor(red: 0.44, green: 0.63, blue: 0.40, alpha: 1)
  private static let tape = UIColor(red: 0.96, green: 0.82, blue: 0.43, alpha: 1)
  private static let caseBorder = UIColor(red: 0.88, green: 0.81, blue: 0.84, alpha: 1)
  private static let caseTop = UIColor(red: 0.96, green: 0.93, blue: 0.98, alpha: 1)
  private static let caseMiddle = UIColor(red: 0.99, green: 0.96, blue: 0.91, alpha: 1)
  private static let caseBottom = UIColor(red: 0.91, green: 0.94, blue: 0.86, alpha: 1)
  private static let pedestalTop = UIColor(red: 0.99, green: 0.88, blue: 0.70, alpha: 1)
  private static let pedestalInset = UIColor(red: 1, green: 0.94, blue: 0.82, alpha: 1)
  private static let pedestalSide = UIColor(red: 0.78, green: 0.56, blue: 0.40, alpha: 1)
}
