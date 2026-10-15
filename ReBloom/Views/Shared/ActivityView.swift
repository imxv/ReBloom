import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
  private enum Content {
    case items([Any])
    case itemProviders([NSItemProvider])
  }

  private let content: Content

  init(items: [Any]) {
    content = .items(items)
  }

  init(itemProviders: [NSItemProvider]) {
    content = .itemProviders(itemProviders)
  }

  func makeUIViewController(context: Context) -> UIActivityViewController {
    switch content {
    case .items(let items):
      return UIActivityViewController(activityItems: items, applicationActivities: nil)
    case .itemProviders(let itemProviders):
      let configuration = UIActivityItemsConfiguration(itemProviders: itemProviders)
      return UIActivityViewController(activityItemsConfiguration: configuration)
    }
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
