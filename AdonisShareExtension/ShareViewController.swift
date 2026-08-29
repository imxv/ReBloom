import OSLog
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
  private let logger = Logger(
    subsystem: "studio.adonis.localdemo.share",
    category: "image-import"
  )
  private let statusLabel = UILabel()
  private let detailLabel = UILabel()
  private let progressView = UIActivityIndicatorView(style: .medium)
  private let closeButton = UIButton(type: .system)
  private var didStart = false

  override func viewDidLoad() {
    super.viewDidLoad()
    preferredContentSize = CGSize(width: UIScreen.main.bounds.width, height: 280)
    configureView()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !didStart else { return }
    didStart = true
    Task { await receiveImages() }
  }

  private func configureView() {
    view.backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 0.91, alpha: 1)

    let mark = UILabel()
    mark.text = "✿  ADONIS"
    mark.font = .systemFont(ofSize: 14, weight: .black)
    mark.textColor = UIColor(red: 0.58, green: 0.12, blue: 0.19, alpha: 1)

    statusLabel.text = "正在收下这件衣服"
    statusLabel.font = .systemFont(ofSize: 22, weight: .black)
    statusLabel.textColor = UIColor(red: 0.11, green: 0.10, blue: 0.09, alpha: 1)
    statusLabel.textAlignment = .center
    statusLabel.numberOfLines = 0
    statusLabel.accessibilityIdentifier = "share-extension-status"

    detailLabel.text = "Adonis 不会自动上传这张图片"
    detailLabel.font = .preferredFont(forTextStyle: .subheadline)
    detailLabel.textColor = UIColor.secondaryLabel
    detailLabel.textAlignment = .center
    detailLabel.numberOfLines = 0
    detailLabel.accessibilityIdentifier = "share-extension-detail"

    progressView.color = UIColor(red: 0.58, green: 0.12, blue: 0.19, alpha: 1)
    progressView.startAnimating()

    closeButton.setTitle("完成", for: .normal)
    closeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
    closeButton.setTitleColor(.white, for: .normal)
    closeButton.backgroundColor = UIColor(red: 0.11, green: 0.10, blue: 0.09, alpha: 1)
    closeButton.layer.cornerRadius = 18
    closeButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
    closeButton.isHidden = true
    closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)

    let stack = UIStackView(arrangedSubviews: [
      mark, progressView, statusLabel, detailLabel, closeButton,
    ])
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .vertical
    stack.alignment = .fill
    stack.spacing = 15
    stack.setCustomSpacing(22, after: mark)
    stack.setCustomSpacing(20, after: detailLabel)

    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 26),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -26),
      stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
    ])
  }

  @MainActor
  private func receiveImages() async {
    let providers = imageProviders()
    guard !providers.isEmpty else {
      showFailure("没有找到图片", detail: "请分享商品图、商品截图或衣服的平铺照片。")
      return
    }

    do {
      let inbox = try SharedImageInbox.live()
      var savedCount = 0
      var failedCount = 0

      for provider in providers.prefix(5) {
        do {
          let data = try await loadImageData(from: provider)
          try inbox.enqueue(data: data)
          savedCount += 1
          statusLabel.text = "正在收下 \(savedCount) / \(providers.prefix(5).count) 张"
        } catch {
          failedCount += 1
          logger.error(
            "Unable to read image attachment: \(error.localizedDescription, privacy: .private); types=\(provider.registeredTypeIdentifiers.joined(separator: ","), privacy: .public)"
          )
        }
      }

      guard savedCount > 0 else {
        showFailure("这次没有收好", detail: "请先保存为截图，再从照片 App 分享给 Adonis。")
        return
      }

      progressView.stopAnimating()
      progressView.isHidden = true
      statusLabel.text = savedCount == 1 ? "已经交给 Adonis" : "已经交给 Adonis \(savedCount) 张"
      if failedCount == 0 {
        detailLabel.text = "下次打开 Adonis，会自动收进衣橱。"
      } else {
        detailLabel.text = "有 \(failedCount) 张没有读到；其余图片会在打开 Adonis 后自动入衣橱。"
      }

      try? await Task.sleep(for: .milliseconds(700))
      extensionContext?.completeRequest(returningItems: nil)
    } catch {
      showFailure("暂时无法保存", detail: error.localizedDescription)
    }
  }

  private func imageProviders() -> [NSItemProvider] {
    (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
      .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
  }

  private func loadImageData(from provider: NSItemProvider) async throws -> Data {
    let typeIdentifiers = provider.registeredTypeIdentifiers.filter { identifier in
      UTType(identifier)?.conforms(to: .image) == true
    }
    for typeIdentifier in typeIdentifiers {
      if let data = try? await loadDataRepresentation(
        from: provider,
        typeIdentifier: typeIdentifier
      ) {
        return data
      }
      if let data = try? await loadFileRepresentation(
        from: provider,
        typeIdentifier: typeIdentifier
      ) {
        return data
      }
      if let data = try? await loadLegacyItem(
        from: provider,
        typeIdentifier: typeIdentifier
      ) {
        return data
      }
    }

    if provider.canLoadObject(ofClass: UIImage.self) {
      let image: UIImage = try await withCheckedThrowingContinuation { continuation in
        provider.loadObject(ofClass: UIImage.self) { object, error in
          if let image = object as? UIImage {
            continuation.resume(returning: image)
          } else {
            continuation.resume(throwing: error ?? SharedImageInboxError.unreadableImage)
          }
        }
      }
      if let data = image.pngData() {
        return data
      }
    }

    if let data = try? await loadPreviewImage(from: provider) {
      return data
    }

    throw SharedImageInboxError.unreadableImage
  }

  private func loadPreviewImage(from provider: NSItemProvider) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      provider.loadPreviewImage(options: nil) { item, error in
        do {
          continuation.resume(returning: try self.imageData(from: item, error: error))
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func loadDataRepresentation(
    from provider: NSItemProvider,
    typeIdentifier: String
  ) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
        guard let data else {
          continuation.resume(throwing: error ?? SharedImageInboxError.unreadableImage)
          return
        }
        continuation.resume(returning: data)
      }
    }
  }

  private func loadFileRepresentation(
    from provider: NSItemProvider,
    typeIdentifier: String
  ) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
        do {
          guard let url else {
            throw error ?? SharedImageInboxError.unreadableImage
          }
          continuation.resume(returning: try Data(contentsOf: url))
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func loadLegacyItem(
    from provider: NSItemProvider,
    typeIdentifier: String
  ) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
        do {
          continuation.resume(returning: try self.imageData(from: item, error: error))
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func imageData(from item: Any?, error: Error?) throws -> Data {
    if let data = item as? Data {
      return data
    }
    if let image = item as? UIImage, let data = image.pngData() {
      return data
    }
    if let url = item as? URL {
      return try Data(contentsOf: url)
    }
    throw error ?? SharedImageInboxError.unreadableImage
  }

  @MainActor
  private func showFailure(_ title: String, detail: String) {
    progressView.stopAnimating()
    progressView.isHidden = true
    statusLabel.text = title
    detailLabel.text = detail
    closeButton.isHidden = false
  }

  @objc
  private func close() {
    extensionContext?.completeRequest(returningItems: nil)
  }
}
