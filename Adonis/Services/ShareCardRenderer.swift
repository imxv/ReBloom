import UIKit

struct ShareCardRenderer {
  private let size = CGSize(width: 1080, height: 1440)

  func render(sticker: UIImage, bloomNumber: Int, date: Date) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true

    return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
      let context = rendererContext.cgContext
      drawBackground(in: context)
      drawDecorations(in: context)
      drawSticker(sticker, in: context)
      drawTypography(bloomNumber: bloomNumber, date: date)
    }
  }

  private func drawBackground(in context: CGContext) {
    UIColor(red: 1, green: 0.973, blue: 0.925, alpha: 1).setFill()
    context.fill(CGRect(origin: .zero, size: size))

    let inner = CGRect(x: 54, y: 54, width: size.width - 108, height: size.height - 108)
    let path = UIBezierPath(roundedRect: inner, cornerRadius: 66)
    UIColor(red: 1, green: 0.992, blue: 0.969, alpha: 1).setFill()
    path.fill()

    context.saveGState()
    context.setStrokeColor(UIColor(red: 0.16, green: 0.12, blue: 0.14, alpha: 0.12).cgColor)
    context.setLineWidth(3)
    context.setLineDash(phase: 0, lengths: [10, 11])
    context.addPath(path.cgPath)
    context.strokePath()
    context.restoreGState()
  }

  private func drawDecorations(in context: CGContext) {
    drawFlower(center: CGPoint(x: 150, y: 178), radius: 34, in: context)
    drawFlower(center: CGPoint(x: 930, y: 1165), radius: 26, in: context)

    let leafColor = UIColor(red: 0.51, green: 0.69, blue: 0.47, alpha: 1)
    leafColor.setFill()
    drawLeaf(
      center: CGPoint(x: 916, y: 194),
      size: CGSize(width: 92, height: 44),
      rotation: -0.38,
      in: context
    )
    drawLeaf(
      center: CGPoint(x: 948, y: 230),
      size: CGSize(width: 76, height: 36),
      rotation: 0.28,
      in: context
    )

    let bubble = UIBezierPath(
      roundedRect: CGRect(x: 92, y: 1075, width: 226, height: 76), cornerRadius: 38)
    UIColor(red: 0.956, green: 0.847, blue: 0.541, alpha: 1).setFill()
    bubble.fill()

    let bubbleText = "OOTD  ♡" as NSString
    bubbleText.draw(
      in: CGRect(x: 127, y: 1092, width: 170, height: 44),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 29, weight: .heavy),
        .foregroundColor: UIColor(red: 0.16, green: 0.12, blue: 0.14, alpha: 1),
      ]
    )
  }

  private func drawFlower(center: CGPoint, radius: CGFloat, in context: CGContext) {
    let colors = [
      UIColor(red: 0.90, green: 0.33, blue: 0.39, alpha: 1),
      UIColor(red: 0.96, green: 0.85, blue: 0.54, alpha: 1),
    ]

    for index in 0..<5 {
      context.saveGState()
      context.translateBy(x: center.x, y: center.y)
      context.rotate(by: CGFloat(index) * .pi * 2 / 5)
      colors[index % colors.count].setFill()
      UIBezierPath(
        ovalIn: CGRect(x: -radius * 0.28, y: -radius, width: radius * 0.56, height: radius)
      ).fill()
      context.restoreGState()
    }

    UIColor(red: 0.16, green: 0.12, blue: 0.14, alpha: 1).setFill()
    context.fillEllipse(
      in: CGRect(
        x: center.x - radius * 0.22,
        y: center.y - radius * 0.22,
        width: radius * 0.44,
        height: radius * 0.44
      ))
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

  private func drawSticker(_ sticker: UIImage, in context: CGContext) {
    let target = CGRect(x: 142, y: 260, width: 796, height: 820)
    let fitted = aspectFit(size: sticker.size, in: target)

    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 0, height: 24),
      blur: 30,
      color: UIColor(red: 0.16, green: 0.12, blue: 0.14, alpha: 0.18).cgColor
    )
    sticker.draw(in: fitted)
    context.restoreGState()
  }

  private func drawTypography(bloomNumber: Int, date: Date) {
    let ink = UIColor(red: 0.16, green: 0.12, blue: 0.14, alpha: 1)
    let secondary = UIColor(red: 0.44, green: 0.38, blue: 0.41, alpha: 1)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    ("ADONIS" as NSString).draw(
      in: CGRect(x: 250, y: 102, width: 580, height: 74),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 52, weight: .black),
        .kern: 7,
        .foregroundColor: ink,
        .paragraphStyle: paragraph,
      ]
    )

    ("TODAY'S BLOOM" as NSString).draw(
      in: CGRect(x: 230, y: 1180, width: 620, height: 62),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 42, weight: .black),
        .kern: 3,
        .foregroundColor: ink,
        .paragraphStyle: paragraph,
      ]
    )

    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "zh_CN")
    dateFormatter.dateFormat = "yyyy.MM.dd"
    let metadata =
      "BLOOM NO. \(String(format: "%03d", bloomNumber))   ·   \(dateFormatter.string(from: date))"
    (metadata as NSString).draw(
      in: CGRect(x: 150, y: 1244, width: 780, height: 50),
      withAttributes: [
        .font: UIFont.monospacedDigitSystemFont(ofSize: 25, weight: .semibold),
        .kern: 1.5,
        .foregroundColor: secondary,
        .paragraphStyle: paragraph,
      ]
    )

    ("让每一个你，重新盛开" as NSString).draw(
      in: CGRect(x: 280, y: 1322, width: 520, height: 42),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 24, weight: .medium),
        .foregroundColor: secondary,
        .paragraphStyle: paragraph,
      ]
    )
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
}
