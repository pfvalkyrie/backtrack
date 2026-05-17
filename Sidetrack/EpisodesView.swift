import SwiftUI

struct EpisodesView: View {
    @Environment(AppState.self) private var appState
    let podcast: Podcast

    @State private var episodes: [Episode] = []
    @State private var isLoading = false
    @State private var selectedEpisode: Episode?
    @State private var filter = ""
    @State private var errorMessage: String?

    var isSubscribed: Bool { appState.isSubscribed(podcast.id) }

    var filteredEpisodes: [Episode] {
        filter.isEmpty ? episodes : episodes.filter { $0.title.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        Group {
            if isLoading && episodes.isEmpty {
                ProgressView().tint(.sOrange)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
        .navigationTitle(podcast.name)
        .navigationBarTitleDisplayMode(.large)
        .background(Color.black)
        .searchable(text: $filter, prompt: "Filter episodes")
        .sheet(item: $selectedEpisode) { ep in
            EpisodeDetailSheet(ep: ep)
        }
        .task { await loadEpisodes() }
    }

    var list: some View {
        List {
            Section {
                podcastHeader
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)

            if let errorMessage {
                VStack(alignment: .leading, spacing: 10) {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.sOrange)
                    Button {
                        Task { await loadEpisodes(forceRefresh: true) }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.sOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .listRowBackground(Color.sS1)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 8, trailing: 12))
                .listRowSeparator(.hidden)
            }

            if filteredEpisodes.isEmpty && !isLoading && errorMessage == nil {
                Text(filter.isEmpty ? "No episodes found" : "No matching episodes")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.sDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            ForEach(filteredEpisodes) { ep in
                EpisodeRow(ep: ep,
                           isInQueue: appState.isInQueue(ep.id),
                           isListened: appState.listened[ep.id] == true)
                    .listRowBackground(Color.sS1)
                    .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                    .listRowSeparator(.hidden)
                    .onTapGesture { selectedEpisode = ep }
            }
        }
        .listStyle(.plain)
        .background(Color.black)
        .scrollContentBackground(.hidden)
        .refreshable { await loadEpisodes(forceRefresh: true) }
    }

    var podcastHeader: some View {
        VStack(spacing: 12) {
            AsyncImage(url: URL(string: podcast.artUrl)) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: { Color.sS3 }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if !podcast.author.isEmpty {
                Text(podcast.author)
                    .font(.system(size: 13))
                    .foregroundColor(.sDim)
            }
            if !podcast.desc.isEmpty {
                Text(podcast.desc)
                    .font(.system(size: 13))
                    .foregroundColor(.sDim)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            Button {
                if isSubscribed { appState.unsubscribe(podcast.id) }
                else { appState.subscribe(podcast) }
            } label: {
                Text(isSubscribed ? "Subscribed" : "Subscribe")
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(isSubscribed
                                ? AnyShapeStyle(Color.sS3)
                                : AnyShapeStyle(LinearGradient.sGradient))
                    .foregroundColor(isSubscribed ? .sDim : .black)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }

    func loadEpisodes(forceRefresh: Bool = false) async {
        let cached = appState.episodesFor(podcast.id)
        if !cached.isEmpty && !forceRefresh { episodes = cached }
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await FeedService.fetchFeed(podcast: podcast)
            appState.storeFeed(fetched, for: podcast)
            episodes = fetched
        } catch {
            if episodes.isEmpty {
                errorMessage = "Could not load episodes. Check your connection and try again."
            } else {
                appState.toast("Could not refresh episodes")
            }
        }
        isLoading = false
    }
}

// MARK: - Episode Row

private struct EpisodeRow: View {
    @Environment(AppState.self) private var appState
    let ep: Episode
    let isInQueue: Bool
    let isListened: Bool
    @State private var showQueueMenu = false

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: ep.artUrl)) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: { Color.sS3 }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(ep.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .foregroundColor(isListened ? .sDim : .white)
                HStack(spacing: 6) {
                    if isListened {
                        Circle().fill(Color.sOrange.opacity(0.6)).frame(width: 6, height: 6)
                    }
                    if let num = ep.epNum {
                        Text("Ep \(num)").font(.system(size: 11)).foregroundColor(.sDim)
                    }
                    if ep.duration > 0 {
                        Text(ep.duration.hmsFormatted).font(.system(size: 11)).foregroundColor(.sDim)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                guard !isInQueue else { return }
                showQueueMenu = true
            } label: {
                Image(systemName: isInQueue ? "checkmark" : "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isInQueue ? .sDim : .sOrange)
                    .frame(width: 32, height: 32)
                    .background(Color.sS3)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .confirmationDialog("Add to Queue", isPresented: $showQueueMenu) {
                Button("Play Next") {
                    appState.playNext(ep)
                    appState.toast("Playing next")
                }
                Button("Add to End") {
                    appState.addToQueue(ep)
                    appState.toast("Added to queue")
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Episode Detail Sheet

struct EpisodeDetailSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let ep: Episode
    @State private var showQueueMenu = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(spacing: 14) {
                        AsyncImage(url: URL(string: ep.artUrl)) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { Color.sS3 }
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(ep.title)
                                .font(.system(size: 15, weight: .bold))
                                .lineLimit(3)
                            Text(ep.podName)
                                .font(.system(size: 13))
                                .foregroundColor(.sDim)
                            if ep.duration > 0 {
                                Text(ep.duration.hmsFormatted)
                                    .font(.system(size: 12))
                                    .foregroundColor(.sMuted)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Action buttons
                    HStack(spacing: 12) {
                        Button {
                            appState.playNow(ep)
                            dismiss()
                        } label: {
                            Label("Play", systemImage: "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(LinearGradient.sGradient)
                                .foregroundColor(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button { showQueueMenu = true } label: {
                            Label("Queue", systemImage: "plus")
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.sS2)
                                .foregroundColor(.sOrange)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.sOrange.opacity(0.4), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog("Add to Queue", isPresented: $showQueueMenu) {
                            Button("Play Next") { appState.playNext(ep); dismiss() }
                            Button("Add to End") { appState.addToQueue(ep); dismiss() }
                        }
                    }
                    .padding(.horizontal)

                    // Show notes
                    Divider().background(Color.sS2).padding(.horizontal)

                    if let notes = ep.descHtml ?? (ep.desc.isEmpty ? nil : ep.desc) {
                        Group {
                            if let attr = notes.notesAttributedString {
                                Text(attr)
                                    .tint(.sOrange)
                                    .textSelection(.enabled)
                            } else {
                                Text(notes.strippingHTML).foregroundColor(.sDim)
                            }
                        }
                        .font(.body)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.sDim)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
