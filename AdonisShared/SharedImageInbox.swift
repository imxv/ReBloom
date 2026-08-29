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
  static let minimumPixelLength = 64

  private let baseURL: URL
  private let fileManager: FileManager

  init(baseURL: URL, fileManager: FileManager = .default) throws {
    self.baseURL = baseURL
    self.fileManager = fileManager
    try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
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
    try Self.validate(data: data)

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
  }

  static func validate(data: Data) throws {
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
    guard
      width.intValue >= minimumPixelLength,
      height.intValue >= minimumPixelLength
    else {
      throw SharedImageInboxError.imageTooSmall
    }
  }

  private static func createdAt(from filename: String) -> Date {
    let prefix = filename.split(separator: "-", maxSplits: 1).first
    guard let prefix, let milliseconds = Int64(prefix) else { return .distantPast }
    return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1_000)
  }
}

enum SharedImageInboxError: Equatable, LocalizedError {
  case sharedContainerUnavailable
  case unreadableImage
  case imageTooSmall
  case imageTooLarge

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
    }
  }
}
