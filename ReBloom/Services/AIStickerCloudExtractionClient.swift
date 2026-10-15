import Foundation
import UIKit

struct AIStickerExtractionEndpointConfiguration: Equatable, Sendable {
  static let endpointKey = "ADONIS_STICKER_EXTRACTION_URL"
  static let proxyTokenKey = "ADONIS_STICKER_PROXY_TOKEN"

  let endpoint: URL
  let proxyToken: String?

  static func resolve(
    bundle: Bundle = .main,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> AIStickerExtractionEndpointConfiguration? {
    let endpointValue = resolvedValue(
      key: endpointKey,
      bundle: bundle,
      environment: environment
    )
    guard let endpointValue,
      let endpoint = URL(string: endpointValue),
      ["http", "https"].contains(endpoint.scheme?.lowercased() ?? "")
    else {
      return nil
    }
    return AIStickerExtractionEndpointConfiguration(
      endpoint: endpoint,
      proxyToken: resolvedValue(
        key: proxyTokenKey,
        bundle: bundle,
        environment: environment
      )
    )
  }

  private static func resolvedValue(
    key: String,
    bundle: Bundle,
    environment: [String: String]
  ) -> String? {
    let value = environment[key] ?? bundle.object(forInfoDictionaryKey: key) as? String
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
    return trimmed
  }
}

enum AIStickerCloudExtractionError: LocalizedError {
  case notConfigured
  case sourceEncodingFailed
  case sourceTooLarge
  case requestFailed
  case invalidResponse
  case serviceRejected(statusCode: Int)
  case responseTooLarge
  case invalidImage

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      "透明贴纸 AI 服务还没有配置。这次不会改用本机抠图，请稍后再试。"
    case .sourceEncodingFailed:
      "AI 贴纸底图暂时无法发送，请重新生成一张。"
    case .sourceTooLarge:
      "AI 贴纸底图太大，暂时无法继续透明处理。"
    case .requestFailed:
      "透明贴纸服务暂时连接不上，请检查网络后再试。"
    case .invalidResponse:
      "透明贴纸服务返回了无法识别的结果，请再试一次。"
    case .serviceRejected:
      "透明贴纸服务这次没有处理成功，请稍后再试。"
    case .responseTooLarge:
      "透明贴纸结果异常过大，这次没有继续保存。"
    case .invalidImage:
      "透明贴纸服务没有返回可用的 PNG 图片，请再试一次。"
    }
  }
}

@MainActor
struct AIStickerCloudExtractionClient {
  private static let maximumUploadBytes = 12 * 1_024 * 1_024
  private static let maximumResponseBytes = 20 * 1_024 * 1_024

  private let configuration: AIStickerExtractionEndpointConfiguration?
  private let session: URLSession

  init(
    configuration: AIStickerExtractionEndpointConfiguration? = .resolve(),
    session: URLSession = .shared
  ) {
    self.configuration = configuration
    self.session = session
  }

  func extractTransparentSubject(from generatedSource: UIImage) async throws -> UIImage {
    guard let configuration else {
      throw AIStickerCloudExtractionError.notConfigured
    }
    guard let pngData = generatedSource.pngData() else {
      throw AIStickerCloudExtractionError.sourceEncodingFailed
    }
    guard pngData.count <= Self.maximumUploadBytes else {
      throw AIStickerCloudExtractionError.sourceTooLarge
    }

    let payload = AIStickerExtractionRequest(
      schemaVersion: 1,
      imageMimeType: "image/png",
      imageBase64: pngData.base64EncodedString()
    )
    var request = URLRequest(url: configuration.endpoint)
    request.httpMethod = "POST"
    request.timeoutInterval = 140
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("image/png", forHTTPHeaderField: "Accept")
    request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
    request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Adonis-Request-ID")
    if let proxyToken = configuration.proxyToken {
      request.setValue("Bearer \(proxyToken)", forHTTPHeaderField: "Authorization")
    }
    request.httpBody = try JSONEncoder().encode(payload)

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw AIStickerCloudExtractionError.requestFailed
    }
    guard let response = response as? HTTPURLResponse else {
      throw AIStickerCloudExtractionError.invalidResponse
    }
    guard 200..<300 ~= response.statusCode else {
      throw AIStickerCloudExtractionError.serviceRejected(statusCode: response.statusCode)
    }
    guard data.count <= Self.maximumResponseBytes else {
      throw AIStickerCloudExtractionError.responseTooLarge
    }
    let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased()
    guard contentType?.hasPrefix("image/png") == true,
      let image = UIImage(data: data),
      image.cgImage != nil
    else {
      throw AIStickerCloudExtractionError.invalidImage
    }
    return image
  }
}

private struct AIStickerExtractionRequest: Encodable {
  let schemaVersion: Int
  let imageMimeType: String
  let imageBase64: String
}
