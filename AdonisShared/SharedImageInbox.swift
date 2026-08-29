import Foundation
import ImageIO

struct SharedImageInboxItem: Equatable, Identifiable, Sendable {
  let id: String
  let url: URL
  let createdAt: Date
}

struct SharedImageInbox {
  static let version = "wardrobe-share-inbox-v1"
  static let appGroupIdentifier = "group.studio.adonis.localdemo"
  static let directoryName = "SharedWardrobeInbox"
  static let filenameExtension = "adonis-image"
  static let maximumImageBytes = 40 * 1_024 * 1_024
  static let maximumQueuedImageCount = 50
  static let maximumQueuedBytes = 250 * 1_024 * 1_024
  static let minimumPixelLength = 64
  static let maximumPixelLength = 16_384
  static let maximumImagePixelCount: Int64 = 60_000_000

  private let baseURL: URL
  private let fileManager: FileManager
  private let queuedImageCountLimit: Int
  private let queuedImageBytesLimit: Int
  private let maximumPixelLength: Int
  private let maximumImagePixelCount: Int64

  init(
    baseURL: URL,
    fileManager: FileManager = .default,
    queuedImageCountLimit: Int = Self.maximumQueuedImageCount,
    queuedImageBytesLimit: Int = Self.maximumQueuedBytes,
    maximumPixelLength: Int = Self.maximumPixelLength,
    maximumImagePixelCount: Int64 = Self.maximumImagePixelCount
  ) throws {
    self.baseURL = baseURL
    self.fileManager = fileManager
    self.queuedImageCountLimit = queuedImageCountLimit
    self.queuedImageBytesLimit = queuedImageBytesLimit
    self.maximumPixelLength = maximumPixelLength
    self.maximumImagePixelCount = maximumImagePixelCount
    try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
    applyDirectoryProtection()
  }

  static func live(fileManager: FileManager = .default) throws -> SharedImageInbox {
    guard
      let containerURL = fileManager.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupIdentifier
      )
    else {
      throw SharedImageInboxError.sharedContainerUnavailable
    }
    return try SharedImageInbox(
      baseURL: containerURL.appendingPathComponent(directoryName, isDirectory: true),
      fileManager: fileManager
    )
  }

  @discardableResult
  func enqueue(data: Data, createdAt: Date = .now) throws -> SharedImageInboxItem {
    try Self.validate(
      data: data,
      maximumPixelLength: maximumPixelLength,
      maximumImagePixelCount: maximumImagePixelCount
    )
    try validateQueueCapacity(addingBytes: data.count)

    let milliseconds = Int64(createdAt.timeIntervalSince1970 * 1_000)
    let filename = "\(milliseconds)-\(UUID().uuidString.lowercased()).\(Self.filenameExtension)"
    let targetURL = baseURL.appendingPathComponent(filename, isDirectory: false)
    try data.write(to: targetURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    return SharedImageInboxItem(id: filename, url: targetURL, createdAt: createdAt)
  }

  func pendingItems() throws -> [SharedImageInboxItem] {
    let urls = try fileManager.contentsOfDirectory(
      at: baseURL,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
    return
      urls
      .filter { $0.pathExtension == Self.filenameExtension }
      .map { url in
        SharedImageInboxItem(
          id: url.lastPathComponent,
          url: url,
          createdAt: Self.createdAt(from: url.lastPathComponent)
        )
      }
      .sorted {
        if $0.createdAt == $1.createdAt { return $0.id < $1.id }
        return $0.createdAt < $1.createdAt
      }
  }

  func data(for item: SharedImageInboxItem) throws -> Data {
    try Data(contentsOf: item.url, options: .mappedIfSafe)
  }

  func remove(_ item: SharedImageInboxItem) throws {
    guard fileManager.fileExists(atPath: item.url.path) else { return }
    try fileManager.removeItem(at: item.url)
  }

  func removeAll() throws {
    if fileManager.fileExists(atPath: baseURL.path) {
      try fileManager.removeItem(at: baseURL)
    }
    try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
    applyDirectoryProtection()
  }

  static func validate(data: Data) throws {
    try validate(
      data: data,
      maximumPixelLength: maximumPixelLength,
      maximumImagePixelCount: maximumImagePixelCount
    )
  }

  private static func validate(
    data: Data,
    maximumPixelLength: Int,
    maximumImagePixelCount: Int64
  ) throws {
    guard !data.isEmpty, data.count <= maximumImageBytes else {
      throw data.isEmpty ? SharedImageInboxError.unreadableImage : .imageTooLarge
    }
    guard
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      CGImageSourceGetCount(source) > 0,
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
        as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
      let height = properties[kCGImagePropertyPixelHeight] as? NSNumber
    else {
      throw SharedImageInboxError.unreadableImage
    }
    let pixelWidth = width.int64Value
    let pixelHeight = height.int64Value
    guard
      pixelWidth >= Int64(minimumPixelLength),
      pixelHeight >= Int64(minimumPixelLength)
    else {
      throw SharedImageInboxError.imageTooSmall
    }
    let (pixelCount, overflow) = pixelWidth.multipliedReportingOverflow(by: pixelHeight)
    guard
      !overflow,
      pixelWidth <= Int64(maximumPixelLength),
      pixelHeight <= Int64(maximumPixelLength),
      pixelCount <= maximumImagePixelCount
    else {
      throw SharedImageInboxError.imageDimensionsTooLarge
    }
  }

  private static func createdAt(from filename: String) -> Date {
    let prefix = filename.split(separator: "-", maxSplits: 1).first
    guard let prefix, let milliseconds = Int64(prefix) else { return .distantPast }
    return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1_000)
  }

  private func validateQueueCapacity(addingBytes: Int) throws {
    let pending = try pendingItems()
    guard pending.count < queuedImageCountLimit else {
      throw SharedImageInboxError.inboxFull
    }
    let existingBytes = try pending.reduce(into: 0) { total, item in
      let values = try item.url.resourceValues(forKeys: [.fileSizeKey])
      total += values.fileSize ?? 0
    }
    guard existingBytes + addingBytes <= queuedImageBytesLimit else {
      throw SharedImageInboxError.inboxFull
    }
  }

  private func applyDirectoryProtection() {
    try? fileManager.setAttributes(
      [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
      ofItemAtPath: baseURL.path
    )
  }
}

enum SharedImageInboxError: Equatable, LocalizedError {
  case sharedContainerUnavailable
  case unreadableImage
  case imageTooSmall
  case imageTooLarge
  case imageDimensionsTooLarge
  case inboxFull

  var errorDescription: String? {
    switch self {
    case .sharedContainerUnavailable:
      "Adonis 的共享空间暂时不可用，请先打开 App 后再试。"
    case .unreadableImage:
      "没有读到可以保存的图片，请改为分享商品图或截图。"
    case .imageTooSmall:
      "这张图片太小了，请分享一张更清楚的商品图。"
    case .imageTooLarge:
      "这张图片太大了，请先保存截图后再分享。"
    case .imageDimensionsTooLarge:
      "这张图片尺寸太大了，请先保存较小的版本或截图后再分享。"
    case .inboxFull:
      "Adonis 里还有一些图片没处理，请先打开 App 收进衣橱后再试。"
    }
  }
}
