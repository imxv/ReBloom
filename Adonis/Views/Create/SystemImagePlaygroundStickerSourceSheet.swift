import SwiftUI
import UIKit

#if canImport(ImagePlayground)
  import ImagePlayground
#endif

@MainActor
enum SystemImagePlaygroundStickerSourceCapability {
  static var isAvailable: Bool {
    #if canImport(ImagePlayground)
      if #available(iOS 18.1, *) {
        return ImagePlaygroundViewController.isAvailable
      }
    #endif
    return false
  }
}

@MainActor
struct SystemImagePlaygroundStickerSourceSheet: View {
  let sourceImage: UIImage
  let usesFixture: Bool
  let onCompletion: (CreativeProviderOutput) -> Void
  let onFailure: (CreativeGenerationError) -> Void
  let onCancellation: () -> Void

  var body: some View {
    #if DEBUG
      if usesFixture {
        SystemImagePlaygroundStickerSourceFixture(
          sourceImage: sourceImage,
          onCompletion: onCompletion,
          onFailure: onFailure,
          onCancellation: onCancellation
        )
      } else {
        liveContent
      }
    #else
      liveContent
    #endif
  }

  @ViewBuilder
  private var liveContent: some View {
    #if canImport(ImagePlayground)
      if #available(iOS 18.1, *) {
        SystemImagePlaygroundStickerSourceController(
          sourceImage: sourceImage,
          onCompletion: onCompletion,
          onFailure: onFailure,
          onCancellation: onCancellation
        )
        .ignoresSafeArea()
      } else {
        SystemImagePlaygroundUnavailableView(onFailure: onFailure)
      }
    #else
      SystemImagePlaygroundUnavailableView(onFailure: onFailure)
    #endif
  }
}

@MainActor
private struct SystemImagePlaygroundUnavailableView: View {
  @State private var hasReportedFailure = false

  let onFailure: (CreativeGenerationError) -> Void

  var body: some View {
    Color.clear
      .onAppear {
        guard !hasReportedFailure else { return }
        hasReportedFailure = true
        Task { @MainActor in
          await Task.yield()
          onFailure(.unavailable)
        }
      }
  }
}

#if canImport(ImagePlayground)
  @available(iOS 18.1, *)
  @MainActor
  private struct SystemImagePlaygroundStickerSourceController: UIViewControllerRepresentable {
    let sourceImage: UIImage
    let onCompletion: (CreativeProviderOutput) -> Void
    let onFailure: (CreativeGenerationError) -> Void
    let onCancellation: () -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(
        onCompletion: onCompletion,
        onFailure: onFailure,
        onCancellation: onCancellation
      )
    }

    func makeUIViewController(context: Context) -> ImagePlaygroundViewController {
      let controller = ImagePlaygroundViewController()
      controller.sourceImage = sourceImage
      controller.concepts = [.text(CreativeRecipe.aiStickerSource.systemConcept)]
      controller.delegate = context.coordinator
      controller.isModalInPresentation = true

      if #available(iOS 18.4, *) {
        controller.allowedGenerationStyles = [.animation]
        controller.selectedGenerationStyle = .animation
      }
      if #available(iOS 26.4, *) {
        var options = ImagePlaygroundOptions()
        options.creationVariety = .low
        options.personalization = .automatic
        controller.options = options
      }
      return controller
    }

    func updateUIViewController(
      _ uiViewController: ImagePlaygroundViewController,
      context _: Context
    ) {
      uiViewController.sourceImage = sourceImage
    }

    @MainActor
    final class Coordinator: NSObject, ImagePlaygroundViewController.Delegate {
      private let onCompletion: (CreativeProviderOutput) -> Void
      private let onFailure: (CreativeGenerationError) -> Void
      private let onCancellation: () -> Void
      private var hasFinished = false

      init(
        onCompletion: @escaping (CreativeProviderOutput) -> Void,
        onFailure: @escaping (CreativeGenerationError) -> Void,
        onCancellation: @escaping () -> Void
      ) {
        self.onCompletion = onCompletion
        self.onFailure = onFailure
        self.onCancellation = onCancellation
      }

      func imagePlaygroundViewController(
        _: ImagePlaygroundViewController,
        didCreateImageAt imageURL: URL
      ) {
        finish {
          do {
            let data = try Data(contentsOf: imageURL, options: .mappedIfSafe)
            guard let image = UIImage(data: data) else {
              onFailure(.noImage)
              return
            }
            onCompletion(
              CreativeProviderOutput(
                image: image,
                executionMetadata: .appleImagePlaygroundSheet
              )
            )
          } catch {
            onFailure(.noImage)
          }
        }
      }

      func imagePlaygroundViewControllerDidCancel(
        _: ImagePlaygroundViewController
      ) {
        finish(onCancellation)
      }

      private func finish(_ action: () -> Void) {
        guard !hasFinished else { return }
        hasFinished = true
        action()
      }
    }
  }
#endif

#if DEBUG
  @MainActor
  private struct SystemImagePlaygroundStickerSourceFixture: View {
    let sourceImage: UIImage
    let onCompletion: (CreativeProviderOutput) -> Void
    let onFailure: (CreativeGenerationError) -> Void
    let onCancellation: () -> Void

    var body: some View {
      ZStack {
        AdonisTheme.canvas
          .ignoresSafeArea()

        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            Text("系统 Image Playground 测试替身")
              .font(.system(.title2, design: .rounded, weight: .bold))
              .foregroundStyle(AdonisTheme.ink)

            Text("仅用于自动化测试：下面模拟用户确认一张不透明 AI 贴纸底图，不代表真实 Apple 生图效果。")
              .font(.body)
              .foregroundStyle(AdonisTheme.secondaryInk)
              .lineSpacing(4)

            HStack(alignment: .center, spacing: 12) {
              fixturePreview(
                image: sourceImage,
                title: "上传参考",
                accessibilityLabel: "上传的参考照片"
              )

              Image(systemName: "arrow.right")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AdonisTheme.pomegranate)
                .accessibilityHidden(true)

              if let generatedImage = makeFixtureOutput() {
                fixturePreview(
                  image: generatedImage,
                  title: "模拟 AI 底图",
                  accessibilityLabel: "模拟的 AI 贴纸底图"
                )
                .accessibilityIdentifier("image-playground-fixture-generated-preview")
              }
            }

            Text("确认后，Adonis 会先接收模拟的 AI 生成图，再交给第二段 AI 生成透明贴纸。")
              .font(.footnote)
              .foregroundStyle(AdonisTheme.secondaryInk)

            Button {
              guard let image = makeFixtureOutput() else {
                onFailure(.noImage)
                return
              }
              onCompletion(
                CreativeProviderOutput(
                  image: image,
                  executionMetadata: .uiTestFixture
                )
              )
            } label: {
              Text("采用这张 AI 贴纸图")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                  AdonisTheme.pomegranate,
                  in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            }
            .buttonStyle(StickerButtonStyle())
            .accessibilityIdentifier("image-playground-fixture-accept")

            Button("取消") {
              onCancellation()
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("image-playground-fixture-cancel")
          }
          .padding(24)
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel("系统 Image Playground 测试替身")
      .accessibilityIdentifier("image-playground-fixture-sheet")
    }

    private func fixturePreview(
      image: UIImage,
      title: String,
      accessibilityLabel: String
    ) -> some View {
      VStack(spacing: 8) {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 230)
          .background(.white.opacity(0.7))
          .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
              .stroke(.white, lineWidth: 5)
          }
        Text(title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(AdonisTheme.secondaryInk)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(accessibilityLabel)
    }

    private func makeFixtureOutput() -> UIImage? {
      guard let sticker = SampleCatalog.showcasePhotos.first?.preparedStickerImage() else {
        return nil
      }
      let canvasSize = CGSize(width: 1_080, height: 1_440)
      let inset = CGRect(x: 90, y: 54, width: 900, height: 1_332)
      let scale = min(inset.width / sticker.size.width, inset.height / sticker.size.height)
      let stickerSize = CGSize(
        width: sticker.size.width * scale,
        height: sticker.size.height * scale
      )
      let stickerFrame = CGRect(
        x: inset.midX - stickerSize.width / 2,
        y: inset.midY - stickerSize.height / 2,
        width: stickerSize.width,
        height: stickerSize.height
      )
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      format.opaque = true
      return UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
        UIColor(red: 0.965, green: 0.949, blue: 0.925, alpha: 1).setFill()
        context.fill(CGRect(origin: .zero, size: canvasSize))
        sticker.draw(in: stickerFrame)
      }
    }
  }
#endif
