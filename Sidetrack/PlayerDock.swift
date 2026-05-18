import SwiftUI

struct PlayerDock: View {
    @Environment(AppState.self) private var appState
    @State private var isExpanded = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                if isExpanded {
                    PlayerSheet(isExpanded: $isExpanded)
                        .ignoresSafeArea()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .move(edge: .bottom)
                        ))
                        .zIndex(2)
                }

                // Floating mini card — visible when collapsed
                if !isExpanded {
                    miniCard
                        .padding(.horizontal, 12)
                        .padding(.bottom, 58)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                        ))
                        .zIndex(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.88), value: isExpanded)
        .onAppear { isExpanded = appState.isPlayerExpanded }
        .onChange(of: appState.isPlayerExpanded) { _, new in isExpanded = new }
        .onChange(of: isExpanded) { _, new in appState.isPlayerExpanded = new }
    }

    // MARK: - Mini Card

    @ViewBuilder
    var miniCard: some View {
        if let ep = appState.currentEpisode {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    RemoteArtworkView(urls: appState.artworkCandidates(for: ep), cornerRadius: 10)
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(ep.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .foregroundColor(.white)
                        Text(ep.podName)
                            .font(.system(size: 12))
                            .foregroundColor(.sDim)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        appState.skipBack()
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 18))
                            .foregroundColor(.sDim)
                    }
                    .frame(width: 36, height: 44)

                    Button {
                        appState.togglePlay()
                    } label: {
                        Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.sOrange)
                    }
                    .frame(width: 36, height: 44)

                    Button {
                        appState.skipForward()
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.system(size: 18))
                            .foregroundColor(.sDim)
                    }
                    .frame(width: 36, height: 44)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)

                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.sS3).frame(height: 3)
                        Capsule()
                            .fill(LinearGradient.sGradient)
                            .frame(
                                width: g.size.width * progress,
                                height: 3
                            )
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 18).fill(Color.sS1.opacity(0.76)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.24), .white.opacity(0.06), .sOrange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .sOrange.opacity(0.14), radius: 18, y: 4)
            .shadow(color: .black.opacity(0.55), radius: 22, y: 8)
            .onTapGesture {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
                    isExpanded = true
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { v in
                        if v.translation.height < -30 {
                            withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
                                isExpanded = true
                            }
                        }
                    }
            )
            .buttonStyle(.plain)
        }
    }

    private var progress: CGFloat {
        guard appState.duration > 0 else { return 0 }
        return CGFloat(min(1, max(0, appState.currentPos / appState.duration)))
    }
}
