import SwiftUI

struct LibraryView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.subscriptions.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Library")
        .background(Color.black)
        .scrollContentBackground(.hidden)
        .task { await fillMissingPodcastDescriptions() }
        .refreshable { await refreshLibrary() }
    }

    var list: some View {
        List {
            ForEach(appState.subscriptions) { podcast in
                NavigationLink(destination: EpisodesView(podcast: podcast)) {
                    LibraryRow(podcast: podcast)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 16).fill(Color.sS1.opacity(0.72)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.1), lineWidth: 0.6)
                        )
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                .listRowSeparator(.hidden)
            }
            .onDelete { idx in idx.forEach { appState.unsubscribe(appState.subscriptions[$0].id) } }
        }
        .listStyle(.plain)
        .background(Color.black)
        .scrollContentBackground(.hidden)
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 52)).foregroundColor(.sMuted)
            Text("No podcasts yet").font(.headline).foregroundColor(.sDim)
            Text("Search for shows to subscribe").font(.subheadline).foregroundColor(.sMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func fillMissingPodcastDescriptions() async {
        let missing = appState.subscriptions.filter { $0.desc.isEmpty || $0.artUrl.isEmpty }
        for podcast in missing {
            guard let detailed = try? await FeedService.fetchPodcastDetails(podcast: podcast) else { continue }
            appState.updatePodcastDetails(detailed)
        }
    }

    func refreshLibrary() async {
        for podcast in appState.subscriptions {
            let detailed = (try? await FeedService.fetchPodcastDetails(podcast: podcast)) ?? podcast
            appState.updatePodcastDetails(detailed)
            if let episodes = try? await FeedService.fetchFeed(podcast: detailed) {
                appState.storeFeed(episodes, for: detailed)
            }
        }
    }
}

private struct LibraryRow: View {
    @Environment(AppState.self) private var appState
    let podcast: Podcast

    var body: some View {
        HStack(spacing: 12) {
            RemoteArtworkView(urls: appState.artworkCandidates(for: podcast), cornerRadius: 12)
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 4) {
                Text(podcast.name)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(2)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}
