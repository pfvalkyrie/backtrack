import SwiftUI

struct WaypointsView: View {
    @Environment(AppState.self) private var appState
    @State private var editMode: EditMode = .inactive
    @State private var selected: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if appState.waypoints.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Waypoints")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if editMode == .active && !selected.isEmpty {
                        Button("Remove (\(selected.count))") { removeSelected() }
                            .foregroundColor(.sOrange)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !appState.waypoints.isEmpty {
                        if editMode == .active {
                            Button("Done") { editMode = .inactive; selected.removeAll() }
                                .foregroundColor(.sOrange)
                        } else {
                            Button("Edit") { editMode = .active }
                                .foregroundColor(.sOrange)
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
        }
    }

    var list: some View {
        List {
            ForEach(appState.waypoints) { wp in
                WaypointRow(wp: wp, isSelected: selected.contains(wp.id))
                    .listRowBackground(
                        wp.isSleep
                            ? Color(red: 0.15, green: 0.12, blue: 0.04)
                            : Color.sS1
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                    .onTapGesture {
                        if editMode == .active {
                            if selected.contains(wp.id) { selected.remove(wp.id) }
                            else { selected.insert(wp.id) }
                        } else {
                            appState.jumpToWaypoint(wp)
                        }
                    }
            }
            .onDelete { idx in
                idx.forEach { appState.waypoints.remove(at: $0) }
                appState.save()
            }
        }
        .listStyle(.plain)
        .background(Color.black)
        .scrollContentBackground(.hidden)
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.circle")
                .font(.system(size: 52)).foregroundColor(.sMuted)
            Text("No waypoints yet").font(.headline).foregroundColor(.sDim)
            Text("Tap Mark in the player\nto save your place")
                .font(.subheadline).foregroundColor(.sMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    func removeSelected() {
        appState.waypoints.removeAll { selected.contains($0.id) }
        appState.save()
        selected.removeAll()
        editMode = .inactive
    }
}

// MARK: - Waypoint Row

private struct WaypointRow: View {
    let wp: Waypoint
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.sOrange).font(.system(size: 20))
            }

            AsyncImage(url: URL(string: wp.artUrl)) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: { Color.sS3 }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if wp.isSleep {
                        Text("🌙")
                    }
                    Text(wp.showName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(wp.isSleep ? Color(red: 0.96, green: 0.72, blue: 0.24) : .sDim)
                        .lineLimit(1)
                }
                Text(wp.epTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let num = wp.epNum { Text("Ep \(num) ·").font(.system(size: 11)) }
                    Text(wp.pos.hmsFormatted).font(.system(size: 11).monospacedDigit())
                }
                .foregroundColor(.sDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }
}
