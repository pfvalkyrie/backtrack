import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: Bindable(appState).selectedTab) {
                QueueView()
                    .tabItem { Label("Queue",     systemImage: "list.number") }
                    .tag(0)
                NavigationStack { LibraryView() }
                    .tabItem { Label("Library",   systemImage: "books.vertical") }
                    .tag(1)
                NavigationStack { SearchView() }
                    .tabItem { Label("Search",    systemImage: "magnifyingglass") }
                    .tag(2)
                WaypointsView()
                    .tabItem { Label("Waypoints", systemImage: "mappin.circle") }
                    .tag(3)
            }
            .tint(.sOrange)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if appState.currentEpisode != nil {
                    Color.clear.frame(height: 90)
                }
            }

            if appState.currentEpisode != nil {
                PlayerDock()
            }

            if appState.isShowingToast {
                VStack {
                    Spacer()
                    Text(appState.toastMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 150)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(false)
                .zIndex(20)
            }
        }
        .task {
            appState.load()
            appState.setupAudio()
            if let ep = appState.currentEpisode {
                appState.loadChapters(for: ep)
            }
        }
    }
}
