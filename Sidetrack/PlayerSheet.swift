import SwiftUI

private let speedOptions: [Float] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

struct PlayerSheet: View {
    @Environment(AppState.self) private var appState
    @Binding var isExpanded: Bool
    @State private var carouselPanel = 1  // 0 = chapters, 1 = artwork, 2 = notes
    @State private var dragY: CGFloat = 0
    @State private var sheetHeight: CGFloat = 0
    @GestureState(resetTransaction: Transaction(animation: .interactiveSpring(response: 0.28, dampingFraction: 0.84))) private var liveDragY: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let cardSize = min(geo.size.width * 0.88, geo.size.height * 0.42, 360)
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [
                        .black,
                        Color.sS1.opacity(0.98),
                        Color.sS2.opacity(0.96)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                VStack(spacing: 0) {
                    handle
                    Spacer(minLength: 0)
                    carousel(cardSize: cardSize)
                    dots
                        .padding(.top, 10)
                    titleSection
                        .padding(.top, 12)
                    scrubber
                        .padding(.top, 14)
                    controls
                        .padding(.top, 18)
                    utilityRow
                        .padding(.top, 16)
                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 24)
            }
            .contentShape(Rectangle())
            .onAppear { sheetHeight = geo.size.height + geo.safeAreaInsets.bottom + 80 }
        }
        .offset(y: max(dragY, liveDragY))
        .onChange(of: isExpanded) { _, _ in
            if isExpanded { dragY = 0 }
        }
    }

    // MARK: - Drag handle + dismiss

    var handle: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.sS3)
                .frame(width: 36, height: 4)
                .padding(.top, 14)
            HStack {
                Button {
                    dismissPlayer()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.sDim)
                        .padding(12)
                }
                .accessibilityLabel("Close player")
                Spacer()
            }
        }
        .frame(height: 82, alignment: .top)
        .contentShape(Rectangle())
        .highPriorityGesture(dismissDrag)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .updating($liveDragY) { value, state, _ in
                guard let translation = downwardDismissTranslation(value) else { return }
                state = translation
            }
            .onEnded { value in
                if shouldFinishDismiss(value) {
                    dragY = max(0, value.translation.height)
                    dismissPlayer(continuingFromDrag: true)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { dragY = 0 }
                }
            }
    }

    private var artworkDrag: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .updating($liveDragY) { value, state, _ in
                guard let translation = downwardDismissTranslation(value) else { return }
                state = translation
            }
            .onEnded { value in
                if shouldFinishDismiss(value) {
                    dragY = max(0, value.translation.height)
                    dismissPlayer(continuingFromDrag: true)
                } else if let targetPanel = artworkSwipeTarget(value) {
                    withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.88, blendDuration: 0.06)) {
                        carouselPanel = targetPanel
                        dragY = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { dragY = 0 }
                }
            }
    }

    private func downwardDismissTranslation(_ value: DragGesture.Value) -> CGFloat? {
        let vertical = value.translation.height
        let horizontal = abs(value.translation.width)
        guard vertical > 0 else { return nil }
        guard vertical > 10 || horizontal > 10 else { return nil }
        guard vertical > horizontal * 1.18 else { return nil }
        return vertical
    }

    private func shouldFinishDismiss(_ value: DragGesture.Value) -> Bool {
        guard downwardDismissTranslation(value) != nil else { return false }
        let predicted = max(value.translation.height, value.predictedEndTranslation.height)
        return value.translation.height > 72 || predicted > 160
    }

    private func artworkSwipeTarget(_ value: DragGesture.Value) -> Int? {
        let width = value.translation.width
        let predictedWidth = value.predictedEndTranslation.width
        let horizontal = max(abs(width), abs(predictedWidth))
        let vertical = abs(value.translation.height)
        guard horizontal > 42 || abs(predictedWidth) > 96 else { return nil }
        guard horizontal > vertical * 1.12 else { return nil }
        return predictedWidth < 0 || width < 0 ? 2 : 0
    }

    private func dismissPlayer(continuingFromDrag: Bool = false) {
        if continuingFromDrag {
            withAnimation(.easeOut(duration: 0.18)) {
                dragY = max(sheetHeight, 700)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isExpanded = false
                    dragY = 0
                }
            }
        } else {
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.9, blendDuration: 0.08)) {
                dragY = max(sheetHeight, 700)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isExpanded = false
                    dragY = 0
                }
            }
        }
    }

    // MARK: - Carousel (Chapters | Artwork | Notes)

    func carousel(cardSize: CGFloat) -> some View {
        TabView(selection: $carouselPanel) {
            chaptersPane.tag(0)
            artPane(cardSize: cardSize).tag(1)
            notesPane.tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(width: cardSize, height: cardSize)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.14), lineWidth: 0.8)
        )
        .shadow(color: .sOrange.opacity(0.12), radius: 18, y: 5)
        .shadow(color: .black.opacity(0.55), radius: 24, y: 10)
    }

    // MARK: - Artwork pane

    func artPane(cardSize: CGFloat) -> some View {
        Group {
            if let ep = appState.currentEpisode {
                RemoteArtworkView(urls: appState.artworkCandidates(for: ep), cornerRadius: 20)
                    .scaleEffect(appState.isPlaying ? 1.0 : 0.92)
                    .animation(.spring(duration: 0.4), value: appState.isPlaying)
            } else {
                Color.sS3
            }
        }
        .frame(width: cardSize, height: cardSize)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .gesture(artworkDrag, including: .gesture)
    }

    // MARK: - Chapters pane

    @ViewBuilder
    var chaptersPane: some View {
        switch appState.chaptersState {
        case .idle, .noChapters:
            placeholderLabel("No chapters")
        case .loading:
            ProgressView().tint(.sOrange)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
        case .failed:
            placeholderLabel("Couldn't load")
        case .loaded(let chapters):
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(chapters) { ch in
                            let cur = isCurrent(ch)
                            chapterRow(ch, isCurrent: cur)
                                .id(ch.id)
                        }
                    }
                }
                .onChange(of: carouselPanel) { _, new in
                    if new == 0, let ch = chapters.first(where: { isCurrent($0) }) {
                        withAnimation { proxy.scrollTo(ch.id, anchor: .center) }
                    }
                }
                .background(.ultraThinMaterial)
            }
        }
    }

    @ViewBuilder
    private func chapterRow(_ ch: Chapter, isCurrent cur: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Text(ch.startTime.hmsFormatted)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundColor(cur ? .sOrange : .sDim)
                    .frame(width: 44, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text(ch.title)
                        .font(.system(size: 13, weight: cur ? .semibold : .regular))
                        .foregroundColor(cur ? .white : .sDim)
                    if let end = ch.endTime, end > ch.startTime {
                        let dur = end - ch.startTime
                        HStack(spacing: 6) {
                            Text(dur.hmsFormatted)
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundColor(.sMuted)
                            if cur {
                                Text("−\((end - appState.currentPos).hmsFormatted)")
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundColor(.sOrange.opacity(0.8))
                            }
                        }
                        if cur {
                            let prog = (appState.currentPos - ch.startTime) / dur
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.sS3).frame(height: 2)
                                    Capsule()
                                        .fill(Color.sOrange)
                                        .frame(width: g.size.width * min(1, max(0, prog)), height: 2)
                                }
                            }
                            .frame(height: 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let urlStr = ch.url, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        Image(systemName: "link")
                            .font(.system(size: 11))
                            .foregroundColor(.sDim)
                            .padding(6)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .onTapGesture { appState.seek(to: ch.startTime) }
            Divider().background(Color.white.opacity(0.08))
        }
    }

    // MARK: - Notes pane

    @ViewBuilder
    var notesPane: some View {
        if let ep = appState.currentEpisode {
            let text = ep.descHtml ?? ep.desc
            if text.isEmpty {
                placeholderLabel("No show notes")
            } else {
                ScrollView {
                    RichPodcastText(text, font: .system(size: 13), foreground: .white)
                        .textSelection(.enabled)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(.ultraThinMaterial)
            }
        }
    }

    func placeholderLabel(_ s: String) -> some View {
        Text(s)
            .font(.subheadline).foregroundColor(.sDim)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
    }

    // MARK: - Dots

    var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i == carouselPanel ? Color.sOrange : Color.sMuted)
                    .frame(width: 6, height: 6)
                    .scaleEffect(i == carouselPanel ? 1.25 : 1.0)
                    .animation(.spring(duration: 0.2), value: carouselPanel)
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3)) { carouselPanel = i }
                    }
            }
        }
    }

    // MARK: - Title

    @ViewBuilder
    var titleSection: some View {
        if let ep = appState.currentEpisode {
            Button {
                showCurrentEpisodeInQueue(ep)
            } label: {
                VStack(spacing: 4) {
                    Text(ep.title)
                        .font(.system(size: 17, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(ep.podName)
                        .font(.system(size: 13))
                        .foregroundColor(.sDim)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show current episode in queue")
        } else {
            EmptyView()
        }
    }

    // MARK: - Scrubber

    var scrubber: some View {
        VStack(spacing: 5) {
            Slider(value: Binding(
                get: { appState.currentPos },
                set: { appState.seek(to: $0) }
            ), in: 0...(appState.duration > 1 ? appState.duration : 1))
            .tint(.sOrange)
            HStack {
                Text(appState.currentPos.hmsFormatted)
                    .font(.caption).foregroundColor(.sDim).monospacedDigit()
                Spacer()
                if appState.duration > 0 {
                    Text("-\((appState.duration - appState.currentPos).hmsFormatted)")
                        .font(.caption).foregroundColor(.sDim).monospacedDigit()
                }
            }
        }
    }

    // MARK: - Controls

    var controls: some View {
        HStack(spacing: 0) {
            Spacer()
            Button { appState.prevTrack() } label: {
                Image(systemName: "backward.fill").font(.title2).foregroundColor(.white)
            }
            Spacer()
            Button { appState.skipBack() } label: {
                Image(systemName: "gobackward.15").font(.title2).foregroundColor(.white)
            }
            Spacer()
            Button { appState.togglePlay() } label: {
                ZStack {
                    Circle().fill(LinearGradient.sGradient).frame(width: 64, height: 64)
                    Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: appState.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button { appState.skipForward() } label: {
                Image(systemName: "goforward.30").font(.title2).foregroundColor(.white)
            }
            Spacer()
            Button { appState.nextTrack() } label: {
                Image(systemName: "forward.fill").font(.title2).foregroundColor(.white)
            }
            Spacer()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Utility row

    var utilityRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(speedOptions, id: \.self) { s in
                    Button { appState.setSpeed(s) } label: {
                        Text(s == 1.0 ? "1×" : String(format: "%.4g×", s))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(appState.speed == s ? .black : .sDim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(appState.speed == s ? Color.sOrange : Color.white.opacity(0.06))
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .glassSurface(cornerRadius: 10, tintOpacity: 0.34)

            HStack(spacing: 12) {
                Spacer()
                if let ep = appState.currentEpisode {
                    Button {
                        appState.addWaypoint(isSleep: false, ep: ep)
                        appState.toast("Waypoint saved")
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bookmark.fill").font(.system(size: 13))
                            Text("Mark").font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.sDim)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .glassSurface(cornerRadius: 10, tintOpacity: 0.42)
                    }
                    .buttonStyle(.plain)
                }
                Button { appState.cycleSleep() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "moon.fill").font(.system(size: 13))
                        Text(appState.sleepMinutes == 0 ? "Sleep" : "\(appState.sleepMinutes)m")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(appState.sleepMinutes > 0
                                     ? Color(red: 0.96, green: 0.72, blue: 0.24) : .sDim)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .glassSurface(cornerRadius: 10, tintOpacity: 0.42)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private func isCurrent(_ ch: Chapter) -> Bool {
        let pos = appState.currentPos
        if let end = ch.endTime { return pos >= ch.startTime && pos < end }
        return pos >= ch.startTime
    }

    private func showCurrentEpisodeInQueue(_ ep: Episode) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            isExpanded = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            appState.selectedTab = 0
            appState.queueScrollTarget = nil
            DispatchQueue.main.async {
                appState.queueScrollTarget = ep.id
            }
        }
    }
}
