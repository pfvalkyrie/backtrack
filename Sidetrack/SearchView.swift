import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @State private var results: [Podcast] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.sOrange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .listRowBackground(glassRowBackground)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowSeparator(.hidden)
            }

            if results.isEmpty && !isLoading {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(results) { podcast in
                NavigationLink(destination: EpisodesView(podcast: podcast)) {
                    PodcastSearchRow(podcast: podcast)
                }
                .listRowBackground(glassRowBackground)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .background(Color.black)
        .scrollContentBackground(.hidden)
        .navigationTitle("Search")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search podcasts")
        .onSubmit(of: .search) { Task { await search() } }
        .overlay {
            if isLoading {
                ProgressView().tint(.sOrange)
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44)).foregroundColor(.sMuted)
                .padding(.top, 40)
            Text(errorMessage == nil && !query.isEmpty ? "No results" : "Find your next listen")
                .font(.headline).foregroundColor(.sDim)
            Text(errorMessage == nil && !query.isEmpty ? "Try another podcast name" : "Search by podcast name")
                .font(.subheadline).foregroundColor(.sMuted)
        }
        .frame(maxWidth: .infinity)
    }

    func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            let found = try await FeedService.searchPodcasts(query)
            results = found
            isLoading = false
            await enrichResults(found)
            return
        } catch {
            errorMessage = "Search failed. Check your connection."
            results = []
        }
        isLoading = false
    }

    func enrichResults(_ found: [Podcast]) async {
        for podcast in found.prefix(12) {
            guard let detailed = try? await FeedService.fetchPodcastDetails(podcast: podcast),
                  let index = results.firstIndex(where: { $0.id == podcast.id }) else { continue }
            results[index] = detailed
        }
    }

    private var glassRowBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 16).fill(Color.sS1.opacity(0.72)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 0.6))
    }
}

// MARK: - Podcast Search Row

private struct PodcastSearchRow: View {
    @Environment(AppState.self) private var appState
    let podcast: Podcast

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
                if !podcast.desc.isEmpty {
                    RichPodcastText(
                        podcast.desc,
                        font: .system(size: 12),
                        foreground: .sDim,
                        lineLimit: 2
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if appState.isSubscribed(podcast.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.sOrange)
                    .font(.system(size: 18))
            }
        }
        .padding(.vertical, 6)
    }
}
