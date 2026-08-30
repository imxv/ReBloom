import UIKit

struct MythicGardenCardRenderer {
  static let provenance = VisualContentProvenance.aiGenerated
  static let provenanceFooter = "AI 生成画面 · 仅作风格创作 · 非真实照片"

  private let size = CGSize(width: 1_080, height: 1_440)

  func render(generatedImage: UIImage, bloomNumber: Int, date: Date) -> UIImage? {
    guard generatedImage.size.width.isFinite,
      generatedImage.size.height.isFinite,
      generatedImage.size.width > 0,
      generatedImage.size.height > 0
    else {
      return nil
    }

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
      Self.ink.setFill()
      context.fill(CGRect(origin: .zero, size: size))
      drawHeader(bloomNumber: bloomNumber, date: date)
      drawGeneratedImage(generatedImage)
      drawFooter()
    }
  }

  private func drawHeader(bloomNumber: Int, date: Date) {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy.MM.dd"

    ("ADONIS / MYTHIC GARDEN" as NSString).draw(
      in: CGRect(x: 78, y: 58, width: 924, height: 56),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 30, weight: .black),
        .kern: 3.4,
        .foregroundColor: Self.paper,
      ]
    )
    ("\(formatter.string(from: date))  ·  BLOOM \(String(format: "%03d", bloomNumber))"
      as NSString).draw(
        in: CGRect(x: 80, y: 112, width: 880, height: 36),
        withAttributes: [
          .font: UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .bold),
          .foregroundColor: Self.butter,
        ]
      )
  }

  private func drawGeneratedImage(_ image: UIImage) {
    let frame = CGRect(x: 78, y: 176, width: 924, height: 1_066)
    let path = UIBezierPath(roundedRect: frame, cornerRadius: 52)
    path.addClip()
    image.draw(in: aspectFill(image.size, inside: frame))

    UIColor.white.withAlphaComponent(0.18).setStroke()
    path.lineWidth = 3
    path.stroke()
  }

  private func drawFooter() {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    ("永生花园 · 青春、欲望与再次盛开" as NSString).draw(
      in: CGRect(x: 82, y: 1_278, width: 916, height: 42),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 26, weight: .black),
        .foregroundColor: Self.paper,
        .paragraphStyle: paragraph,
      ]
    )
    (Self.provenanceFooter as NSString).draw(
      in: CGRect(x: 82, y: 1_334, width: 916, height: 30),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
        .foregroundColor: Self.paper.withAlphaComponent(0.7),
        .paragraphStyle: paragraph,
      ]
    )
  }

  private func aspectFill(_ imageSize: CGSize, inside rect: CGRect) -> CGRect {
    let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
    let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    return CGRect(
      x: rect.midX - fittedSize.width / 2,
      y: rect.midY - fittedSize.height / 2,
      width: fittedSize.width,
      height: fittedSize.height
    )
  }

  private static let ink = UIColor(red: 0.09, green: 0.055, blue: 0.08, alpha: 1)
  private static let paper = UIColor(red: 1, green: 0.973, blue: 0.925, alpha: 1)
  private static let butter = UIColor(red: 0.957, green: 0.847, blue: 0.541, alpha: 1)
}
