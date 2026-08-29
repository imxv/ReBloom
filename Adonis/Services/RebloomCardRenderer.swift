import UIKit

struct RebloomCardRenderer {
  static let provenanceFooter = "真实衣橱图片 · ADONIS 本机组合建议 · 非试穿效果"
  static let provenance = VisualContentProvenance.programmaticComposition

  private let size = CGSize(width: 1080, height: 1440)

  func render(
    topImage: UIImage,
    topName: String,
    bottomImage: UIImage,
    bottomName: String,
    reasonTitle: String
  ) -> UIImage? {
    guard hasPixels(topImage), hasPixels(bottomImage) else { return nil }

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true

    return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
      let context = rendererContext.cgContext
      drawBackground(in: context)
      drawHeader()
      drawItem(
        topImage,
        name: topName,
        role: "上装 · TOP",
        frame: CGRect(x: 84, y: 350, width: 432, height: 650),
        color: Self.pinkPanel,
        context: context
      )
      drawItem(
        bottomImage,
        name: bottomName,
        role: "下装 · BOTTOM",
        frame: CGRect(x: 564, y: 350, width: 432, height: 650),
        color: Self.greenPanel,
        context: context
      )
      drawPairMark()
      drawReason(reasonTitle)
      drawFooter()
    }
  }

  private func hasPixels(_ image: UIImage) -> Bool {
    image.size.width > 0 && image.size.height > 0 && (image.cgImage != nil || image.ciImage != nil)
  }

  private func drawBackground(in context: CGContext) {
    Self.canvas.setFill()
    context.fill(CGRect(origin: .zero, size: size))

    let page = UIBezierPath(
      roundedRect: CGRect(x: 42, y: 42, width: 996, height: 1356),
      cornerRadius: 72
    )
    Self.paper.setFill()
    page.fill()

    context.saveGState()
    context.setStrokeColor(Self.ink.withAlphaComponent(0.12).cgColor)
    context.setLineWidth(3)
    context.setLineDash(phase: 0, lengths: [12, 13])
    context.addPath(page.cgPath)
    context.strokePath()
    context.restoreGState()

    drawFlower(center: CGPoint(x: 132, y: 136), radius: 28, in: context)
    drawSprig(in: context)
  }

  private func drawHeader() {
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center

    ("ADONIS" as NSString).draw(
      in: CGRect(x: 250, y: 82, width: 580, height: 58),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 46, weight: .black),
        .kern: 8,
        .foregroundColor: Self.ink,
        .paragraphStyle: centered,
      ]
    )
    ("再次盛开" as NSString).draw(
      in: CGRect(x: 160, y: 154, width: 760, height: 78),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 56, weight: .black),
        .foregroundColor: Self.pomegranate,
        .paragraphStyle: centered,
      ]
    )
    ("TODAY'S REBLOOM" as NSString).draw(
      in: CGRect(x: 190, y: 238, width: 700, height: 42),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 24, weight: .heavy),
        .kern: 3.2,
        .foregroundColor: Self.secondaryInk,
        .paragraphStyle: centered,
      ]
    )
  }

  private func drawItem(
    _ image: UIImage,
    name: String,
    role: String,
    frame: CGRect,
    color: UIColor,
    context: CGContext
  ) {
    let panel = UIBezierPath(roundedRect: frame, cornerRadius: 42)
    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 0, height: 14),
      blur: 24,
      color: Self.ink.withAlphaComponent(0.13).cgColor
    )
    color.setFill()
    panel.fill()
    context.restoreGState()

    Self.ink.withAlphaComponent(0.09).setStroke()
    panel.lineWidth = 2
    panel.stroke()

    let imagePanel = UIBezierPath(
      roundedRect: CGRect(
        x: frame.minX + 28, y: frame.minY + 74, width: frame.width - 56, height: 430),
      cornerRadius: 30
    )
    UIColor.white.withAlphaComponent(0.94).setFill()
    imagePanel.fill()

    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 0, height: 8),
      blur: 14,
      color: Self.ink.withAlphaComponent(0.12).cgColor
    )
    image.draw(
      in: aspectFit(
        size: image.size,
        in: CGRect(x: frame.minX + 50, y: frame.minY + 96, width: frame.width - 100, height: 386)
      )
    )
    context.restoreGState()

    let centered = NSMutableParagraphStyle()
    centered.alignment = .center
    centered.lineBreakMode = .byTruncatingTail
    (role as NSString).draw(
      in: CGRect(x: frame.minX + 20, y: frame.minY + 22, width: frame.width - 40, height: 38),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 21, weight: .black),
        .kern: 1.1,
        .foregroundColor: Self.pomegranate,
        .paragraphStyle: centered,
      ]
    )
    (name as NSString).draw(
      in: CGRect(x: frame.minX + 24, y: frame.minY + 535, width: frame.width - 48, height: 82),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 31, weight: .black),
        .foregroundColor: Self.ink,
        .paragraphStyle: centered,
      ]
    )
  }

  private func drawPairMark() {
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center
    ("×" as NSString).draw(
      in: CGRect(x: 506, y: 610, width: 68, height: 76),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 56, weight: .black),
        .foregroundColor: Self.pomegranate,
        .paragraphStyle: centered,
      ]
    )
  }

  private func drawReason(_ reasonTitle: String) {
    let frame = CGRect(x: 105, y: 1046, width: 870, height: 138)
    let path = UIBezierPath(roundedRect: frame, cornerRadius: 34)
    Self.butter.withAlphaComponent(0.32).setFill()
    path.fill()

    let centered = NSMutableParagraphStyle()
    centered.alignment = .center
    centered.lineBreakMode = .byWordWrapping
    (reasonTitle as NSString).draw(
      in: frame.insetBy(dx: 34, dy: 25),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 25, weight: .bold),
        .foregroundColor: Self.ink,
        .paragraphStyle: centered,
      ]
    )
  }

  private func drawFooter() {
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center

    ("今天可以直接照着穿" as NSString).draw(
      in: CGRect(x: 170, y: 1218, width: 740, height: 46),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 27, weight: .heavy),
        .foregroundColor: Self.ink,
        .paragraphStyle: centered,
      ]
    )
    (Self.provenanceFooter as NSString).draw(
      in: CGRect(x: 105, y: 1280, width: 870, height: 38),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
        .foregroundColor: Self.secondaryInk,
        .paragraphStyle: centered,
      ]
    )
    ("LET WHAT RESTED BLOOM AGAIN" as NSString).draw(
      in: CGRect(x: 170, y: 1332, width: 740, height: 34),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 18, weight: .bold),
        .kern: 2.0,
        .foregroundColor: Self.pomegranate,
        .paragraphStyle: centered,
      ]
    )
  }

  private func drawFlower(center: CGPoint, radius: CGFloat, in context: CGContext) {
    for index in 0..<5 {
      context.saveGState()
      context.translateBy(x: center.x, y: center.y)
      context.rotate(by: CGFloat(index) * .pi * 2 / 5)
      (index.isMultiple(of: 2) ? Self.pomegranate : Self.butter).setFill()
      UIBezierPath(
        ovalIn: CGRect(x: -radius * 0.3, y: -radius, width: radius * 0.6, height: radius)
      ).fill()
      context.restoreGState()
    }

    Self.ink.setFill()
    context.fillEllipse(
      in: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)
    )
  }

  private func drawSprig(in context: CGContext) {
    context.saveGState()
    context.setStrokeColor(Self.leaf.withAlphaComponent(0.75).cgColor)
    context.setLineWidth(7)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: 915, y: 105))
    context.addCurve(
      to: CGPoint(x: 970, y: 212),
      control1: CGPoint(x: 946, y: 138),
      control2: CGPoint(x: 960, y: 178)
    )
    context.strokePath()

    Self.leaf.setFill()
    drawLeaf(center: CGPoint(x: 936, y: 140), rotation: -0.35)
    drawLeaf(center: CGPoint(x: 961, y: 181), rotation: 0.30)
    context.restoreGState()
  }

  private func drawLeaf(center: CGPoint, rotation: CGFloat) {
    UIGraphicsGetCurrentContext()?.saveGState()
    UIGraphicsGetCurrentContext()?.translateBy(x: center.x, y: center.y)
    UIGraphicsGetCurrentContext()?.rotate(by: rotation)
    UIBezierPath(ovalIn: CGRect(x: -35, y: -15, width: 70, height: 30)).fill()
    UIGraphicsGetCurrentContext()?.restoreGState()
  }

  private func aspectFit(size source: CGSize, in target: CGRect) -> CGRect {
    let scale = min(target.width / source.width, target.height / source.height)
    let fittedSize = CGSize(width: source.width * scale, height: source.height * scale)
    return CGRect(
      x: target.midX - fittedSize.width / 2,
      y: target.midY - fittedSize.height / 2,
      width: fittedSize.width,
      height: fittedSize.height
    )
  }

  private static let canvas = UIColor(red: 0.986, green: 0.914, blue: 0.815, alpha: 1)
  private static let paper = UIColor(red: 1, green: 0.989, blue: 0.957, alpha: 1)
  private static let ink = UIColor(red: 0.16, green: 0.12, blue: 0.14, alpha: 1)
  private static let secondaryInk = UIColor(red: 0.44, green: 0.38, blue: 0.41, alpha: 1)
  private static let pomegranate = UIColor(red: 0.77, green: 0.16, blue: 0.25, alpha: 1)
  private static let leaf = UIColor(red: 0.44, green: 0.63, blue: 0.40, alpha: 1)
  private static let butter = UIColor(red: 0.96, green: 0.82, blue: 0.43, alpha: 1)
  private static let pinkPanel = UIColor(red: 0.98, green: 0.88, blue: 0.87, alpha: 1)
  private static let greenPanel = UIColor(red: 0.91, green: 0.95, blue: 0.84, alpha: 1)
}
