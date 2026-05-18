import SwiftUI

struct QueueView: View {
    @Environment(AppState.self) private var appState
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            Group {
                if appState.queue.isEmpty {
                    emptyState
                } else {
                    queueList
                }
            }
            .navigationTitle("Queue")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if editMode == .active {
                        Button("Keep Current") { appState.keepCurrent(); editMode = .inactive }
                            .foregroundColor(.sOrange)
                            .disabled(appState.currentEpisode == nil)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !appState.queue.isEmpty {
                        EditButton().tint(.sOrange)
                    }
                }
            }
            .environment(\.editMode, $editMode)
        }
    }

    var queueList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(appState.queue.enumerated()), id: \.element.id) { idx, ep in
                    QueueRow(ep: ep, idx: idx, isCurrent: idx == appState.queueIndex)
                        .id(ep.id)
                        .listRowBackground(
                            Group {
                                if idx == appState.queueIndex {
                                    Color.sS2.overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.sOrange.opacity(0.5), lineWidth: 1.5)
                                    )
                                } else {
                                    Color.sS1
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .listRowSeparator(.hidden)
                }
                .onMove { appState.moveQueue(from: $0, to: $1) }
                .onDelete { idx in idx.sorted().reversed().forEach { appState.removeFromQueue(at: $0) } }
            }
            .listStyle(.plain)
            .background(Color.black)
            .scrollContentBackground(.hidden)
            .onAppear {
                scrollToCurrent(proxy)
            }
            .onChange(of: appState.queueScrollTarget) { _, _ in
                scrollToCurrent(proxy)
            }
            .onChange(of: appState.selectedTab) { _, newValue in
                if newValue == 0 {
                    scrollToCurrent(proxy)
                }
            }
        }
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        guard let ep = appState.currentEpisode else { return }
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                proxy.scrollTo(ep.id, anchor: .center)
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.number")
                .font(.system(size: 52))
                .foregroundColor(.sMuted)
            Text("Your queue is empty")
                .font(.headline).foregroundColor(.sDim)
            Text("Search for a podcast to get started")
                .font(.subheadline).foregroundColor(.sMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - Queue Row

private struct QueueRow: View {
    @Environment(AppState.self) private var appState
    let ep: Episode
    let idx: Int
    let isCurrent: Bool

    var hasSleepWaypoint: Bool {
        appState.waypoints.contains { $0.isSleep && $0.epId == ep.id }
    }

    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: URL(string: ep.artUrl)) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: { Color.sS3 }
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(ep.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .foregroundColor(.white)
                Text(ep.podName)
                    .font(.system(size: 11))
                    .foregroundColor(.sDim)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if isCurrent {
                        chip(appState.isPlaying ? "Playing" : "Current", gradient: true)
                    }
                    if hasSleepWaypoint {
                        chip("🌙", gradient: false)
                            .foregroundColor(.black)
                            .background(Color(red: 0.96, green: 0.72, blue: 0.24))
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            appState.playAt(idx)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                appState.isPlayerExpanded = true
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func chip(_ label: String, gradient: Bool) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(gradient
                ? AnyShapeStyle(LinearGradient.sGradient)
                : AnyShapeStyle(Color.sS3))
            .foregroundColor(gradient ? .black : .sDim)
            .clipShape(Capsule())
    }
}
