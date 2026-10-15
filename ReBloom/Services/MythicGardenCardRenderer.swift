import UIKit

struct SystemCreativeCardRenderer {
  static let provenance = VisualContentProvenance.aiGenerated
  static let provenanceFooter = "AI 生成画面 · 仅作风格创作 · 非真实照片"

  private let size = CGSize(width: 1_080, height: 1_440)

  func render(
    generatedImage: UIImage,
    recipe: CreativeRecipe,
    bloomNumber: Int,
    date: Date
  ) -> UIImage? {
    guard recipe.requiresSystemImageGeneration else { return nil }
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
      let theme = theme(for: recipe)
      theme.ink.setFill()
      context.fill(CGRect(origin: .zero, size: size))
      drawHeader(bloomNumber: bloomNumber, date: date, theme: theme)
      drawGeneratedImage(generatedImage)
      drawFooter(theme: theme)
    }
  }

  private func drawHeader(
    bloomNumber: Int,
    date: Date,
    theme: Theme
  ) {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy.MM.dd"

    (theme.eyebrow as NSString).draw(
      in: CGRect(x: 78, y: 58, width: 924, height: 56),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 30, weight: .black),
        .kern: 3.4,
        .foregroundColor: theme.paper,
      ]
    )
    ("\(formatter.string(from: date))  ·  BLOOM \(String(format: "%03d", bloomNumber))"
      as NSString).draw(
        in: CGRect(x: 80, y: 112, width: 880, height: 36),
        withAttributes: [
          .font: UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .bold),
          .foregroundColor: theme.accent,
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

  private func drawFooter(theme: Theme) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (theme.caption as NSString).draw(
      in: CGRect(x: 82, y: 1_278, width: 916, height: 42),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 26, weight: .black),
        .foregroundColor: theme.paper,
        .paragraphStyle: paragraph,
      ]
    )
    (Self.provenanceFooter as NSString).draw(
      in: CGRect(x: 82, y: 1_334, width: 916, height: 30),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
        .foregroundColor: theme.paper.withAlphaComponent(0.7),
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

  private func theme(for recipe: CreativeRecipe) -> Theme {
    switch recipe {
    case .floralSketch:
      Theme(
        ink: UIColor(red: 0.16, green: 0.12, blue: 0.10, alpha: 1),
        paper: UIColor(red: 1, green: 0.96, blue: 0.87, alpha: 1),
        accent: UIColor(red: 0.91, green: 0.36, blue: 0.32, alpha: 1),
        eyebrow: "REBLOOM / FLORAL SKETCH",
        caption: "花神速写 · 纸上的轻盈新生"
      )
    case .moonlitTheater:
      Theme(
        ink: UIColor(red: 0.045, green: 0.075, blue: 0.20, alpha: 1),
        paper: UIColor(red: 0.96, green: 0.94, blue: 0.80, alpha: 1),
        accent: UIColor(red: 1, green: 0.42, blue: 0.42, alpha: 1),
        eyebrow: "REBLOOM / MOONLIT THEATER",
        caption: "月光剧场 · 在蓝夜里重新登场"
      )
    case .mythicGarden:
      Theme(
        ink: UIColor(red: 0.09, green: 0.055, blue: 0.08, alpha: 1),
        paper: UIColor(red: 1, green: 0.973, blue: 0.925, alpha: 1),
        accent: UIColor(red: 0.957, green: 0.847, blue: 0.541, alpha: 1),
        eyebrow: "REBLOOM / MYTHIC GARDEN",
        caption: "永生花园 · 青春、欲望与再次盛开"
      )
    case .aiStickerSource, .botanicalPoster, .stickerTryOn:
      Theme(
        ink: .black,
        paper: .white,
        accent: .white,
        eyebrow: "REBLOOM",
        caption: recipe.title
      )
    }
  }

  private struct Theme {
    let ink: UIColor
    let paper: UIColor
    let accent: UIColor
    let eyebrow: String
    let caption: String
  }
}

struct MythicGardenCardRenderer {
  static let provenance = SystemCreativeCardRenderer.provenance
  static let provenanceFooter = SystemCreativeCardRenderer.provenanceFooter

  func render(generatedImage: UIImage, bloomNumber: Int, date: Date) -> UIImage? {
    SystemCreativeCardRenderer().render(
      generatedImage: generatedImage,
      recipe: .mythicGarden,
      bloomNumber: bloomNumber,
      date: date
    )
  }
}
