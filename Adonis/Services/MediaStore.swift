import Foundation
import UIKit

final class MediaStore {
  static let shared = MediaStore()

  let baseURL: URL
  private let fileManager: FileManager

  init(baseURL: URL? = nil, fileManager: FileManager = .default) {
    self.fileManager = fileManager

    if let baseURL {
      self.baseURL = baseURL
    } else {
      let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
      self.baseURL = documents.appendingPathComponent("AdonisMedia", isDirectory: true)
    }

    try? fileManager.createDirectory(
      at: self.baseURL,
      withIntermediateDirectories: true
    )
  }

  @discardableResult
  func savePNG(_ image: UIImage, filename: String) throws -> String {
    guard let data = image.pngData() else {
      throw MediaStoreError.encodingFailed
    }
    try data.write(to: url(for: filename), options: .atomic)
    return filename
  }

  @discardableResult
  func saveJPEG(_ image: UIImage, filename: String, quality: CGFloat = 0.92) throws -> String {
    guard let data = image.jpegData(compressionQuality: quality) else {
      throw MediaStoreError.encodingFailed
    }
    try data.write(to: url(for: filename), options: .atomic)
    return filename
  }

  func image(filename: String) -> UIImage? {
    UIImage(contentsOfFile: url(for: filename).path)
  }

  func data(filename: String) -> Data? {
    try? Data(contentsOf: url(for: filename))
  }

  func delete(filename: String) {
    let target = url(for: filename)
    guard fileManager.fileExists(atPath: target.path) else { return }
    try? fileManager.removeItem(at: target)
  }

  func delete(filenames: [String]) {
    filenames.forEach(delete(filename:))
  }

  func removeAll() throws {
    if fileManager.fileExists(atPath: baseURL.path) {
      try fileManager.removeItem(at: baseURL)
    }
    try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
  }

  func url(for filename: String) -> URL {
    baseURL.appendingPathComponent(filename, isDirectory: false)
  }
}

enum MediaStoreError: LocalizedError {
  case encodingFailed

  var errorDescription: String? {
    switch self {
    case .encodingFailed:
      "图片编码失败，请换一张照片再试。"
    }
  }
}
