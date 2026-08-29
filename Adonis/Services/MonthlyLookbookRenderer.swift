import UIKit

struct MonthlyLookbookEntry {
  let sticker: UIImage
  let bloomNumber: Int
  let date: Date
}

struct MonthlyLookbookRenderer {
  static let provenanceFooter = "人物与衣物来自已收藏原图 · 画册由 ADONIS 排版"

  private let size = CGSize(width: 1080, height: 1440)

  func entriesForRendering(
    _ entries: [MonthlyLookbookEntry],
    month: Date,
    calendar: Calendar = .current
  ) -> [MonthlyLookbookEntry] {
    Array(
      entries
        .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
        .sorted { $0.date > $1.date }
        .prefix(6)
    )
  }

  func render(
    entries: [MonthlyLookbookEntry],
    month: Date,
    calendar: Calendar = .current
  ) -> UIImage? {
    let monthEntries = entries.filter {
      calendar.isDate($0.date, equalTo: month, toGranularity: .month)
    }
    let selectedEntries = entriesForRendering(entries, month: month, calendar: calendar)
    guard !selectedEntries.isEmpty else { return nil }

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true

    return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
      let context = rendererContext.cgContext
      drawBackground(in: context)
      drawHeader(month: month, entryCount: monthEntries.count)

      let frames = entryFrames(count: selectedEntries.count)
      for (index, entry) in selectedEntries.enumerated() {
        drawEntry(entry, index: index, in: frames[index], context: context)
      }

      drawFooter(showingLatestSix: monthEntries.count > selectedEntries.count)
    }
  }

  private func drawBackground(in context: CGContext) {
    Self.canvas.setFill()
    context.fill(CGRect(origin: .zero, size: size))

    let pageRect = CGRect(x: 42, y: 42, width: size.width - 84, height: size.height - 84)
    let pagePath = UIBezierPath(roundedRect: pageRect, cornerRadius: 72)
    Self.paper.setFill()
    pagePath.fill()

    context.saveGState()
    context.setStrokeColor(Self.ink.withAlphaComponent(0.13).cgColor)
    context.setLineWidth(3)
    context.setLineDash(phase: 0, lengths: [12, 13])
    context.addPath(pagePath.cgPath)
    context.strokePath()
    context.restoreGState()

    drawFlower(center: CGPoint(x: 128, y: 130), radius: 28, in: context)
    drawFlower(center: CGPoint(x: 950, y: 1228), radius: 24, in: context)

    Self.leaf.setFill()
    drawLeaf(
      center: CGPoint(x: 925, y: 142),
      size: CGSize(width: 82, height: 36),
      rotation: -0.34,
      in: context
    )
    drawLeaf(
      center: CGPoint(x: 958, y: 177),
      size: CGSize(width: 68, height: 31),
      rotation: 0.24,
      in: context
    )
  }

  private func drawHeader(month: Date, entryCount: Int) {
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center

    ("ADONIS" as NSString).draw(
      in: CGRect(x: 250, y: 82, width: 580, height: 66),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 47, weight: .black),
        .kern: 8,
        .foregroundColor: Self.ink,
        .paragraphStyle: centered,
      ]
    )

    ("MONTHLY BLOOM BOOK" as NSString).draw(
      in: CGRect(x: 180, y: 148, width: 720, height: 62),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 34, weight: .heavy),
        .kern: 3.4,
        .foregroundColor: Self.pomegranate,
        .paragraphStyle: centered,
      ]
    )

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy 年 M 月"
    let metadata = "\(formatter.string(from: month))  ·  \(entryCount) 次盛开"
    (metadata as NSString).draw(
      in: CGRect(x: 190, y: 216, width: 700, height: 42),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
        .foregroundColor: Self.secondaryInk,
        .paragraphStyle: centered,
      ]
    )
  }

  private func entryFrames(count: Int) -> [CGRect] {
    let contentRect = CGRect(x: 88, y: 292, width: 904, height: 880)
    guard count > 1 else {
      return [CGRect(x: 166, y: 292, width: 748, height: 880)]
    }

    let columns = 2
    let rows = Int(ceil(Double(count) / Double(columns)))
    let horizontalSpacing: CGFloat = 28
    let verticalSpacing: CGFloat = 24
    let itemWidth = (contentRect.width - horizontalSpacing) / 2
    let itemHeight =
      (contentRect.height - (CGFloat(rows - 1) * verticalSpacing)) / CGFloat(rows)

    return (0..<count).map { index in
      let row = index / columns
      let column = index % columns
      let isCenteredLastItem = count.isMultiple(of: 2) == false && index == count - 1
      let x =
        isCenteredLastItem
        ? contentRect.midX - itemWidth / 2
        : contentRect.minX + CGFloat(column) * (itemWidth + horizontalSpacing)
      let y = contentRect.minY + CGFloat(row) * (itemHeight + verticalSpacing)
      return CGRect(x: x, y: y, width: itemWidth, height: itemHeight)
    }
  }

  private func drawEntry(
    _ entry: MonthlyLookbookEntry,
    index: Int,
    in frame: CGRect,
    context: CGContext
  ) {
    context.saveGState()

    let rotations: [CGFloat] = [-0.012, 0.009, 0.006, -0.009, -0.005, 0.012]
    context.translateBy(x: frame.midX, y: frame.midY)
    context.rotate(by: rotations[index % rotations.count])
    context.translateBy(x: -frame.midX, y: -frame.midY)

    let panelPath = UIBezierPath(roundedRect: frame, cornerRadius: 34)
    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 0, height: 13),
      blur: 20,
      color: Self.ink.withAlphaComponent(0.12).cgColor
    )
    Self.panelColors[index % Self.panelColors.count].setFill()
    panelPath.fill()
    context.restoreGState()

    Self.ink.withAlphaComponent(0.10).setStroke()
    panelPath.lineWidth = 2
    panelPath.stroke()

    drawTape(on: frame, index: index)

    let metadataHeight: CGFloat = frame.height < 320 ? 54 : 68
    let stickerRect = frame.insetBy(dx: 18, dy: 18).inset(
      by: UIEdgeInsets(top: 12, left: 6, bottom: metadataHeight, right: 6)
    )
    drawSticker(entry.sticker, in: stickerRect, context: context)
    drawEntryMetadata(entry, in: frame, compact: frame.height < 320)

    context.restoreGState()
  }

  private func drawTape(on frame: CGRect, index: Int) {
    let tapeWidth = min(frame.width * 0.28, 126)
    let tapeRect = CGRect(
      x: frame.midX - tapeWidth / 2,
      y: frame.minY - 9,
      width: tapeWidth,
      height: 34
    )
    let tape = UIBezierPath(roundedRect: tapeRect, cornerRadius: 5)
    let colors = [Self.tape, Self.pinkTape, Self.greenTape]
    colors[index % colors.count].withAlphaComponent(0.84).setFill()
    tape.fill()
  }

  private func drawSticker(_ sticker: UIImage, in target: CGRect, context: CGContext) {
    let fitted = aspectFit(size: sticker.size, in: target)
    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 0, height: 10),
      blur: 15,
      color: Self.ink.withAlphaComponent(0.16).cgColor
    )
    sticker.draw(in: fitted)
    context.restoreGState()
  }

  private func drawEntryMetadata(
    _ entry: MonthlyLookbookEntry,
    in frame: CGRect,
    compact: Bool
  ) {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "zh_CN")
    dateFormatter.dateFormat = "MM.dd"

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let metadata =
      "\(dateFormatter.string(from: entry.date))  ·  BLOOM \(String(format: "%03d", entry.bloomNumber))"
    (metadata as NSString).draw(
      in: CGRect(
        x: frame.minX + 12,
        y: frame.maxY - (compact ? 49 : 58),
        width: frame.width - 24,
        height: 36
      ),
      withAttributes: [
        .font: UIFont.monospacedDigitSystemFont(
          ofSize: compact ? 17 : 21,
          weight: .bold
        ),
        .kern: compact ? 0.4 : 0.9,
        .foregroundColor: Self.ink.withAlphaComponent(0.82),
        .paragraphStyle: paragraph,
      ]
    )
  }

  private func drawFooter(showingLatestSix: Bool) {
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center

    let subtitle = showingLatestSix ? "本月最近 6 次盛开" : "把穿过的日子，收藏成一座花园"
    (subtitle as NSString).draw(
      in: CGRect(x: 170, y: 1210, width: 740, height: 48),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 26, weight: .heavy),
        .foregroundColor: Self.ink,
        .paragraphStyle: centered,
      ]
    )

    (Self.provenanceFooter as NSString).draw(
      in: CGRect(x: 130, y: 1280, width: 820, height: 40),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 19, weight: .semibold),
        .foregroundColor: Self.secondaryInk.withAlphaComponent(0.88),
        .paragraphStyle: centered,
      ]
    )

    ("LET YOUR DAYS BLOOM AGAIN" as NSString).draw(
      in: CGRect(x: 180, y: 1331, width: 720, height: 36),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 18, weight: .bold),
        .kern: 2.2,
        .foregroundColor: Self.pomegranate.withAlphaComponent(0.86),
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

  private static let canvas = UIColor(red: 0.986, green: 0.914, blue: 0.815, alpha: 1)
  private static let paper = UIColor(red: 1, green: 0.989, blue: 0.957, alpha: 1)
  private static let ink = UIColor(red: 0.16, green: 0.12, blue: 0.14, alpha: 1)
  private static let secondaryInk = UIColor(red: 0.44, green: 0.38, blue: 0.41, alpha: 1)
  private static let pomegranate = UIColor(red: 0.77, green: 0.16, blue: 0.25, alpha: 1)
  private static let leaf = UIColor(red: 0.44, green: 0.63, blue: 0.40, alpha: 1)
  private static let tape = UIColor(red: 0.96, green: 0.82, blue: 0.43, alpha: 1)
  private static let pinkTape = UIColor(red: 0.96, green: 0.70, blue: 0.72, alpha: 1)
  private static let greenTape = UIColor(red: 0.69, green: 0.82, blue: 0.61, alpha: 1)
  private static let panelColors = [
    UIColor(red: 1, green: 0.93, blue: 0.84, alpha: 1),
    UIColor(red: 0.91, green: 0.95, blue: 0.84, alpha: 1),
    UIColor(red: 0.98, green: 0.87, blue: 0.86, alpha: 1),
    UIColor(red: 0.89, green: 0.92, blue: 0.97, alpha: 1),
    UIColor(red: 0.95, green: 0.89, blue: 0.96, alpha: 1),
    UIColor(red: 0.94, green: 0.92, blue: 0.82, alpha: 1),
  ]
}
