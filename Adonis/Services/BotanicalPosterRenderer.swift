import UIKit

struct BotanicalPosterRenderer {
  static let provenance = VisualContentProvenance.programmaticComposition
  static let provenanceFooter =
    "人物与衣物来自原图贴纸 · ADONIS 本机排版 · 不含 AI 重绘"

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
      drawBotanicalField(in: context)
      drawTypography(bloomNumber: bloomNumber, date: date)
      drawSticker(sticker, in: context)
      drawFooter()
      sealTransparentRemainder(in: context)
    }
  }

  private func drawBackground(in context: CGContext) {
    Self.ink.setFill()
    context.fill(CGRect(origin: .zero, size: size))

    Self.pomegranate.setFill()
    context.fillEllipse(in: CGRect(x: 620, y: -178, width: 616, height: 616))

    context.saveGState()
    context.setStrokeColor(Self.paper.withAlphaComponent(0.24).cgColor)
    context.setLineWidth(3)
    context.setLineDash(phase: 0, lengths: [13, 14])
    context.addPath(
      UIBezierPath(
        roundedRect: CGRect(x: 58, y: 56, width: 964, height: 1_328),
        cornerRadius: 62
      ).cgPath
    )
    context.strokePath()
    context.restoreGState()

    Self.butter.setFill()
    UIBezierPath(
      roundedRect: CGRect(x: 74, y: 278, width: 148, height: 408),
      cornerRadius: 74
    ).fill()
  }

  private func drawBotanicalField(in context: CGContext) {
    context.saveGState()
    context.translateBy(x: 858, y: 862)
    context.rotate(by: -0.34)

    context.setStrokeColor(Self.leaf.withAlphaComponent(0.78).cgColor)
    context.setLineWidth(18)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: -40, y: 372))
    context.addCurve(
      to: CGPoint(x: 32, y: -350),
      control1: CGPoint(x: 90, y: 170),
      control2: CGPoint(x: -84, y: -80)
    )
    context.strokePath()

    context.setFillColor(Self.leaf.cgColor)
    drawLeaf(
      center: CGPoint(x: 72, y: 116),
      size: CGSize(width: 270, height: 116),
      angle: -0.32,
      in: context
    )
    drawLeaf(
      center: CGPoint(x: -74, y: -40),
      size: CGSize(width: 238, height: 102),
      angle: 0.28,
      in: context
    )
    drawLeaf(
      center: CGPoint(x: 66, y: -190),
      size: CGSize(width: 204, height: 88),
      angle: -0.38,
      in: context
    )
    context.restoreGState()

    drawFlower(center: CGPoint(x: 900, y: 1_160), radius: 60, in: context)
    drawFlower(center: CGPoint(x: 176, y: 1_166), radius: 42, in: context)

    context.saveGState()
    context.setFillColor(Self.paper.withAlphaComponent(0.16).cgColor)
    for row in 0..<6 {
      for column in 0..<4 {
        context.fillEllipse(
          in: CGRect(
            x: 786 + CGFloat(column) * 54,
            y: 486 + CGFloat(row) * 54,
            width: 9,
            height: 9
          )
        )
      }
    }
    context.restoreGState()
  }

  private func drawTypography(bloomNumber: Int, date: Date) {
    let left = NSMutableParagraphStyle()
    left.alignment = .left

    ("ADONIS" as NSString).draw(
      in: CGRect(x: 100, y: 90, width: 520, height: 76),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 54, weight: .black),
        .kern: 8,
        .foregroundColor: Self.paper,
        .paragraphStyle: left,
      ]
    )

    ("REBLOOM" as NSString).draw(
      in: CGRect(x: 100, y: 158, width: 620, height: 96),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 76, weight: .black),
        .kern: 2.8,
        .foregroundColor: Self.paper,
        .paragraphStyle: left,
      ]
    )

    let dateFormatter = DateFormatter()
    dateFormatter.calendar = Calendar(identifier: .gregorian)
    dateFormatter.locale = Locale(identifier: "zh_CN")
    dateFormatter.dateFormat = "yyyy.MM.dd"
    let metadata =
      "\(dateFormatter.string(from: date))  /  BLOOM \(String(format: "%03d", bloomNumber))"
    (metadata as NSString).draw(
      in: CGRect(x: 104, y: 242, width: 590, height: 42),
      withAttributes: [
        .font: UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .bold),
        .kern: 1.2,
        .foregroundColor: Self.butter,
        .paragraphStyle: left,
      ]
    )

    let vertical = NSMutableParagraphStyle()
    vertical.alignment = .center
    ("花\n影\n重\n生" as NSString).draw(
      in: CGRect(x: 108, y: 332, width: 80, height: 292),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 42, weight: .black),
        .foregroundColor: Self.ink,
        .paragraphStyle: vertical,
      ]
    )

    ("LET TODAY BLOOM AGAIN" as NSString).draw(
      in: CGRect(x: 102, y: 1_236, width: 760, height: 56),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 31, weight: .heavy),
        .kern: 3.2,
        .foregroundColor: Self.paper,
        .paragraphStyle: left,
      ]
    )
  }

  private func drawSticker(_ sticker: UIImage, in context: CGContext) {
    let target = CGRect(x: 206, y: 292, width: 724, height: 924)
    let fitted = aspectFit(sticker.size, inside: target)

    drawTintedSilhouette(
      sticker,
      frame: fitted.offsetBy(dx: 56, dy: 18),
      color: Self.pomegranate.withAlphaComponent(0.92),
      in: context
    )
    drawTintedSilhouette(
      sticker,
      frame: fitted.offsetBy(dx: -34, dy: 28),
      color: Self.butter.withAlphaComponent(0.76),
      in: context
    )

    context.saveGState()
    context.interpolationQuality = .high
    context.setShadow(
      offset: CGSize(width: 0, height: 24),
      blur: 36,
      color: Self.ink.withAlphaComponent(0.42).cgColor
    )
    sticker.draw(in: fitted)
    context.restoreGState()
  }

  private func drawTintedSilhouette(
    _ sticker: UIImage,
    frame: CGRect,
    color: UIColor,
    in context: CGContext
  ) {
    context.saveGState()
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    sticker.draw(in: frame)
    context.setBlendMode(.sourceAtop)
    color.setFill()
    context.fill(frame)
    context.setBlendMode(.normal)
    context.endTransparencyLayer()
    context.restoreGState()
  }

  private func drawLeaf(center: CGPoint, size: CGSize, angle: CGFloat, in context: CGContext) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: angle)
    context.fillEllipse(
      in: CGRect(
        x: -size.width / 2,
        y: -size.height / 2,
        width: size.width,
        height: size.height
      )
    )
    context.restoreGState()
  }

  private func drawFlower(center: CGPoint, radius: CGFloat, in context: CGContext) {
    for index in 0..<5 {
      context.saveGState()
      context.translateBy(x: center.x, y: center.y)
      context.rotate(by: CGFloat(index) * .pi * 2 / 5)
      (index.isMultiple(of: 2) ? Self.pomegranate : Self.butter).setFill()
      UIBezierPath(
        ovalIn: CGRect(x: -radius * 0.28, y: -radius, width: radius * 0.56, height: radius)
      ).fill()
      context.restoreGState()
    }
    Self.paper.setFill()
    context.fillEllipse(
      in: CGRect(
        x: center.x - radius * 0.2,
        y: center.y - radius * 0.2,
        width: radius * 0.4,
        height: radius * 0.4
      )
    )
  }

  private func drawFooter() {
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center
    (Self.provenanceFooter as NSString).draw(
      in: CGRect(x: 96, y: 1_318, width: 888, height: 34),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
        .kern: 0.4,
        .foregroundColor: Self.paper.withAlphaComponent(0.66),
        .paragraphStyle: centered,
      ]
    )
  }

  private func sealTransparentRemainder(in context: CGContext) {
    context.saveGState()
    context.setBlendMode(.destinationOver)
    Self.ink.setFill()
    context.fill(CGRect(origin: .zero, size: size))
    context.restoreGState()
  }

  private func aspectFit(_ imageSize: CGSize, inside rect: CGRect) -> CGRect {
    let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
    let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    return CGRect(
      x: rect.midX - fittedSize.width / 2,
      y: rect.midY - fittedSize.height / 2,
      width: fittedSize.width,
      height: fittedSize.height
    )
  }

  private static let ink = UIColor(red: 0.102, green: 0.071, blue: 0.094, alpha: 1)
  private static let paper = UIColor(red: 1, green: 0.973, blue: 0.925, alpha: 1)
  private static let pomegranate = UIColor(red: 0.902, green: 0.333, blue: 0.392, alpha: 1)
  private static let leaf = UIColor(red: 0.510, green: 0.686, blue: 0.471, alpha: 1)
  private static let butter = UIColor(red: 0.957, green: 0.847, blue: 0.541, alpha: 1)
}
