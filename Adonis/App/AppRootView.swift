import SwiftUI

struct AppRootView: View {
  @State private var selection: AppTab = .create

  var body: some View {
    TabView(selection: $selection) {
      NavigationStack {
        CreateView()
      }
      .tabItem {
        Label("创作", systemImage: "sparkles.rectangle.stack.fill")
      }
      .tag(AppTab.create)

      NavigationStack {
        WardrobeView()
      }
      .tabItem {
        Label("衣橱", systemImage: "hanger")
      }
      .tag(AppTab.wardrobe)

      NavigationStack {
        BloomCalendarView()
      }
      .tabItem {
        Label("花历", systemImage: "calendar.day.timeline.leading")
      }
      .tag(AppTab.blooms)
    }
    .tint(AdonisTheme.pomegranate)
  }
}

private enum AppTab: Hashable {
  case create
  case wardrobe
  case blooms
}

#Preview {
  AppRootView()
    .modelContainer(for: [OutfitRecord.self, WardrobeItem.self, AppEvent.self], inMemory: true)
}
