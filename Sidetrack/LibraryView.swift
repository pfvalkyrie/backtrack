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
    }

    var list: some View {
        List {
            ForEach(appState.subscriptions) { podcast in
                NavigationLink(destination: EpisodesView(podcast: podcast)) {
                    LibraryRow(podcast: podcast)
                }
                .listRowBackground(Color.sS1)
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
}

private struct LibraryRow: View {
    @Environment(AppState.self) private var appState
    let podcast: Podcast

    var episodeCount: Int { appState.episodesFor(podcast.id).count }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: podcast.artUrl)) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: { Color.sS3 }
            .frame(width: 62, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(podcast.name)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(2)
                    .foregroundColor(.white)
                if !podcast.author.isEmpty {
                    Text(podcast.author)
                        .font(.system(size: 12))
                        .foregroundColor(.sDim)
                        .lineLimit(1)
                }
                if episodeCount > 0 {
                    Text("\(episodeCount) episodes")
                        .font(.system(size: 11))
                        .foregroundColor(.sMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }
}
