import UIKit
import XCTest

@testable import Adonis

@MainActor
final class AIStickerCloudExtractionClientTests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.requestHandler = nil
    super.tearDown()
  }

  func testConfiguredClientUploadsGeneratedSourceAndReturnsPNG() async throws {
    let generatedSource = opaqueImage(color: .brown)
    let transparentOutput = transparentImage()
    let outputData = try XCTUnwrap(transparentOutput.pngData())
    var capturedRequest: URLRequest?
    StubURLProtocol.requestHandler = { request in
      capturedRequest = request
      return (
        HTTPURLResponse(
          url: try XCTUnwrap(request.url),
          statusCode: 200,
          httpVersion: nil,
          headerFields: ["Content-Type": "image/png"]
        )!,
        outputData
      )
    }
    let client = AIStickerCloudExtractionClient(
      configuration: AIStickerExtractionEndpointConfiguration(
        endpoint: URL(string: "https://example.test/v1/sticker-extractions")!,
        proxyToken: "test-token"
      ),
      session: makeStubSession()
    )

    let result = try await client.extractTransparentSubject(from: generatedSource)

    let request = try XCTUnwrap(capturedRequest)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")
    let body = try requestBodyData(request)
    let object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: body) as? [String: Any]
    )
    XCTAssertEqual(object["schemaVersion"] as? Int, 1)
    XCTAssertEqual(object["imageMimeType"] as? String, "image/png")
    let uploadedBase64 = try XCTUnwrap(object["imageBase64"] as? String)
    XCTAssertEqual(Data(base64Encoded: uploadedBase64), generatedSource.pngData())
    XCTAssertGreaterThan(
      try XCTUnwrap(TransparentStickerInspector.inspect(result)).transparentRatio,
      0.08
    )
  }

  func testMissingConfigurationNeverStartsANetworkRequest() async {
    var requestCount = 0
    StubURLProtocol.requestHandler = { request in
      requestCount += 1
      return (
        HTTPURLResponse(
          url: request.url!,
          statusCode: 500,
          httpVersion: nil,
          headerFields: nil
        )!,
        Data()
      )
    }
    let client = AIStickerCloudExtractionClient(
      configuration: nil,
      session: makeStubSession()
    )

    do {
      _ = try await client.extractTransparentSubject(from: opaqueImage(color: .red))
      XCTFail("Expected missing proxy configuration to fail.")
    } catch AIStickerCloudExtractionError.notConfigured {
      // Expected: the product must not fall back to Vision.
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
    XCTAssertEqual(requestCount, 0)
  }

  func testConfigurationRejectsUnexpandedBuildSettingPlaceholder() {
    XCTAssertNil(
      AIStickerExtractionEndpointConfiguration.resolve(
        environment: [
          AIStickerExtractionEndpointConfiguration.endpointKey:
            "$(ADONIS_STICKER_EXTRACTION_URL)"
        ]
      )
    )
  }

  func testTransportFailureUsesStableRecoveryCopy() async {
    StubURLProtocol.requestHandler = { _ in
      throw URLError(.notConnectedToInternet)
    }
    let client = AIStickerCloudExtractionClient(
      configuration: AIStickerExtractionEndpointConfiguration(
        endpoint: URL(string: "https://example.test/v1/sticker-extractions")!,
        proxyToken: nil
      ),
      session: makeStubSession()
    )

    do {
      _ = try await client.extractTransparentSubject(from: opaqueImage(color: .brown))
      XCTFail("Expected the network failure to surface.")
    } catch AIStickerCloudExtractionError.requestFailed {
      XCTAssertTrue(AIStickerCloudExtractionError.requestFailed.localizedDescription.contains("网络"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  private func makeStubSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
  }

  private func requestBodyData(_ request: URLRequest) throws -> Data {
    if let body = request.httpBody { return body }
    let stream = try XCTUnwrap(request.httpBodyStream)
    stream.open()
    defer { stream.close() }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while stream.hasBytesAvailable {
      let count = stream.read(&buffer, maxLength: buffer.count)
      if count < 0 { throw try XCTUnwrap(stream.streamError) }
      if count == 0 { break }
      result.append(buffer, count: count)
    }
    return result
  }

  private func opaqueImage(color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96), format: format).image {
      context in
      color.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 96, height: 96))
    }
  }

  private func transparentImage() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    return UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96), format: format).image {
      context in
      UIColor.clear.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 96, height: 96))
      UIColor.red.setFill()
      context.fill(CGRect(x: 24, y: 10, width: 48, height: 78))
    }
  }
}

private final class StubURLProtocol: URLProtocol {
  nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with _: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.requestHandler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }
    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
