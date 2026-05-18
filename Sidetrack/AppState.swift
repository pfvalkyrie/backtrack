import Foundation
import SwiftUI
import AVFoundation
import MediaPlayer
import UIKit
import Observation

@Observable
final class AppState {

    // MARK: - Persisted state

    var subscriptions: [Podcast]               = []
    var library:       [String: [Episode]]     = [:]
    var queue:         [Episode]               = []
    var queueIndex:    Int                     = 0
    var currentPos:    TimeInterval            = 0
    var savedPos:      [String: TimeInterval]  = [:]
    var speed:         Float                   = 1.0
    var waypoints:     [Waypoint]              = []
    var listened:      [String: Bool]          = [:]

    // MARK: - Session state (not persisted)

    var browseCache:       [String: [Episode]] = [:]
    var isPlaying:         Bool                = false
    var duration:          TimeInterval        = 0
    var sleepMinutes:      Int                 = 0
    var chaptersState:     ChaptersLoadState   = .idle
    var isPlayerExpanded:  Bool                = false
    var toastMessage:      String              = ""
    var isShowingToast:    Bool                = false
    var selectedTab:       Int                 = 0
    var queueScrollTarget: String?

    private var toastTask: Task<Void, Never>?

    // MARK: - Computed

    var currentEpisode: Episode? {
        guard !queue.isEmpty, queueIndex >= 0, queueIndex < queue.count else { return nil }
        return queue[queueIndex]
    }

    var sleepWaypointForCurrent: Waypoint? {
        guard let ep = currentEpisode else { return nil }
        return waypoints.first { $0.isSleep && $0.epId == ep.id }
    }

    func artworkCandidates(for podcast: Podcast) -> [String] {
        var candidates = [podcast.artUrl]
        candidates.append(contentsOf: episodesFor(podcast.id).map(\.artUrl))
        return dedupedNonEmpty(candidates)
    }

    func artworkCandidates(for episode: Episode) -> [String] {
        var candidates = [episode.artUrl]
        if let podcast = subscriptions.first(where: { $0.id == episode.podId }) {
            candidates.append(podcast.artUrl)
        }
        return dedupedNonEmpty(candidates)
    }

    private func dedupedNonEmpty(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, seen.insert(cleaned).inserted else { return nil }
            return cleaned
        }
    }

    // MARK: - Private

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var sleepTask: Task<Void, Never>?
    private var chapterSeq = 0
    private var didSetupAudio = false
    private var loadedEpisodeId: String?
    private var lastArtworkEpisodeId: String?
    private var nowPlayingArtwork: MPMediaItemArtwork?
    private var lastSavedPositionBucket = -1
    private var shouldResumeAfterInterruption = false

    // MARK: - Setup

    func setupAudio() {
        guard !didSetupAudio else { return }
        didSetupAudio = true
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.allowAirPlay, .allowBluetoothHFP, .allowBluetoothA2DP]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
        UIApplication.shared.beginReceivingRemoteControlEvents()
        setupTimeObserver()
        setupRemoteCommands()
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil, queue: .main
        ) { [weak self] _ in self?.handleTrackEnd() }
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(), queue: .main
        ) { [weak self] note in self?.handleAudioInterruption(note) }
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(), queue: .main
        ) { [weak self] note in self?.handleRouteChange(note) }
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let t = time.seconds
            guard !t.isNaN, !t.isInfinite else { return }
            self.currentPos = t
            if let ep = self.currentEpisode {
                self.savedPos[ep.id] = t
                let bucket = Int(t / 5)
                if bucket != self.lastSavedPositionBucket {
                    self.lastSavedPositionBucket = bucket
                    self.updateNowPlaying()
                    self.save()
                }
            }
            if self.duration > 0, t / self.duration > 0.8,
               let ep = self.currentEpisode, self.listened[ep.id] == nil {
                self.listened[ep.id] = true
                self.save()
            }
        }
    }

    // MARK: - Playback

    func loadTrack(_ ep: Episode, startAt: TimeInterval? = nil, play: Bool = true) {
        guard let url = URL(string: ep.audioUrl) else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        loadedEpisodeId = ep.id
        if lastArtworkEpisodeId != ep.id {
            nowPlayingArtwork = nil
            lastArtworkEpisodeId = nil
        }
        lastSavedPositionBucket = -1
        let pos = startAt ?? savedPos[ep.id] ?? 0
        currentPos = pos
        duration = 0
        if pos > 0 { player.seek(to: CMTime(seconds: pos, preferredTimescale: 600)) }
        if play { player.play(); player.rate = speed; isPlaying = true }
        chaptersState = .idle
        loadChapters(for: ep)
        Task {
            if let d = try? await item.asset.load(.duration) {
                let s = d.seconds
                if !s.isNaN, !s.isInfinite { self.duration = s }
            }
            self.updateNowPlaying()
        }
        updateNowPlaying()
    }

    func togglePlay() {
        if isPlaying { pause() }
        else { play() }
    }

    func play() {
        guard let ep = currentEpisode else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        if loadedEpisodeId != ep.id || player.currentItem == nil {
            loadTrack(ep, play: true)
            save()
            return
        }
        player.play()
        player.rate = speed
        isPlaying = true
        updateNowPlaying()
        save()
    }

    func pause() {
        if let ep = currentEpisode { savedPos[ep.id] = currentPos }
        player.pause()
        isPlaying = false
        updateNowPlaying()
        save()
    }

    func seek(to pos: TimeInterval) {
        player.seek(to: CMTime(seconds: pos, preferredTimescale: 600))
        currentPos = pos
        updateNowPlaying()
    }

    func skipBack()    { seek(to: max(currentPos - 15, 0)) }
    func skipForward() { seek(to: min(currentPos + 30, duration)) }

    func setSpeed(_ s: Float) {
        speed = s
        if isPlaying { player.rate = s }
        save()
    }

    func nextTrack() {
        let next = queueIndex + 1
        guard next < queue.count else { return }
        if let ep = currentEpisode { savedPos[ep.id] = currentPos }
        queueIndex = next
        loadTrack(queue[next], play: isPlaying)
        save()
    }

    func prevTrack() {
        if currentPos > 5 { seek(to: 0); return }
        let prev = queueIndex - 1
        guard prev >= 0 else { return }
        if let ep = currentEpisode { savedPos[ep.id] = currentPos }
        queueIndex = prev
        loadTrack(queue[prev], play: isPlaying)
        save()
    }

    private func handleTrackEnd() {
        if let ep = currentEpisode { savedPos[ep.id] = 0 }
        let next = queueIndex + 1
        if next < queue.count {
            queueIndex = next
            loadTrack(queue[next], play: true)
        } else {
            isPlaying = false; save()
        }
    }

    private func handleAudioInterruption(_ note: Notification) {
        guard let typeValue = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            shouldResumeAfterInterruption = isPlaying
            pause()
        case .ended:
            try? AVAudioSession.sharedInstance().setActive(true)
            let optionsValue = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if shouldResumeAfterInterruption, options.contains(.shouldResume) {
                play()
            }
            shouldResumeAfterInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ note: Notification) {
        guard let reasonValue = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
              reason == .oldDeviceUnavailable else { return }
        pause()
    }

    // MARK: - Chapters

    func loadChapters(for ep: Episode) {
        let seq = chapterSeq + 1; chapterSeq = seq
        chaptersState = .loading
        Task {
            if let urlStr = ep.chaptersUrl, !urlStr.isEmpty {
                do {
                    let ch = try await FeedService.fetchChapters(urlString: urlStr)
                    guard self.chapterSeq == seq else { return }
                    self.chaptersState = ch.isEmpty ? .noChapters : .loaded(ch)
                } catch {
                    guard self.chapterSeq == seq else { return }
                    self.chaptersState = .failed
                }
            } else {
                if let ch = try? await FeedService.fetchChaptersFromID3(audioUrl: ep.audioUrl),
                   !ch.isEmpty, self.chapterSeq == seq {
                    self.chaptersState = .loaded(ch)
                } else if self.chapterSeq == seq {
                    self.chaptersState = .noChapters
                }
            }
        }
    }

    // MARK: - Now Playing / Remote Commands

    func updateNowPlaying() {
        guard let ep = currentEpisode else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: ep.title,
            MPMediaItemPropertyArtist: ep.podName,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentPos,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(speed) : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(speed),
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if let nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = nowPlayingArtwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        guard lastArtworkEpisodeId != ep.id, nowPlayingArtwork == nil else { return }
        lastArtworkEpisodeId = ep.id
        if let url = URL(string: ep.artUrl) {
            let episodeId = ep.id
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = UIImage(data: data) {
                    let art = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
                    guard currentEpisode?.id == episodeId else { return }
                    nowPlayingArtwork = art
                    updateNowPlaying()
                }
            }
        }
    }

    private func setupRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.isEnabled = true
        cc.pauseCommand.isEnabled = true
        cc.skipBackwardCommand.isEnabled = true
        cc.skipBackwardCommand.preferredIntervals = [15]
        cc.skipForwardCommand.isEnabled = true
        cc.skipForwardCommand.preferredIntervals = [30]
        cc.changePlaybackPositionCommand.isEnabled = true
        cc.playCommand.addTarget  { [weak self] _ in self?.handleRemotePlay() ?? .commandFailed }
        cc.pauseCommand.addTarget { [weak self] _ in self?.handleRemotePause() ?? .commandFailed }
        cc.skipBackwardCommand.addTarget { [weak self] _ in self?.handleRemoteSkipBack() ?? .commandFailed }
        cc.skipForwardCommand.addTarget { [weak self] _ in self?.handleRemoteSkipForward() ?? .commandFailed }
        cc.nextTrackCommand.addTarget     { [weak self] _ in self?.handleRemoteNextTrack() ?? .commandFailed }
        cc.previousTrackCommand.addTarget { [weak self] _ in self?.handleRemotePreviousTrack() ?? .commandFailed }
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            return self.handleRemoteSeek(to: e.positionTime)
        }
    }

    private func performRemoteCommand(_ action: @escaping @MainActor () -> Bool) -> MPRemoteCommandHandlerStatus {
        if Thread.isMainThread {
            return action() ? .success : .commandFailed
        }

        var succeeded = false
        DispatchQueue.main.sync {
            succeeded = action()
        }
        return succeeded ? .success : .commandFailed
    }

    private func handleRemotePlay() -> MPRemoteCommandHandlerStatus {
        performRemoteCommand {
            guard self.currentEpisode != nil else { return false }
            self.play()
            return self.isPlaying
        }
    }

    private func handleRemotePause() -> MPRemoteCommandHandlerStatus {
        performRemoteCommand {
            guard self.currentEpisode != nil else { return false }
            self.pause()
            return true
        }
    }

    private func handleRemoteSkipBack() -> MPRemoteCommandHandlerStatus {
        performRemoteCommand {
            guard self.currentEpisode != nil else { return false }
            self.skipBack()
            return true
        }
    }

    private func handleRemoteSkipForward() -> MPRemoteCommandHandlerStatus {
        performRemoteCommand {
            guard self.currentEpisode != nil else { return false }
            self.skipForward()
            return true
        }
    }

    private func handleRemoteNextTrack() -> MPRemoteCommandHandlerStatus {
        performRemoteCommand {
            let oldId = self.currentEpisode?.id
            self.nextTrack()
            return self.currentEpisode?.id != nil && self.currentEpisode?.id != oldId
        }
    }

    private func handleRemotePreviousTrack() -> MPRemoteCommandHandlerStatus {
        performRemoteCommand {
            guard self.currentEpisode != nil else { return false }
            self.prevTrack()
            return true
        }
    }

    private func handleRemoteSeek(to position: TimeInterval) -> MPRemoteCommandHandlerStatus {
        performRemoteCommand {
            guard self.currentEpisode != nil else { return false }
            self.seek(to: position)
            return true
        }
    }

    // MARK: - Queue

    func addToQueue(_ ep: Episode) {
        guard !queue.contains(where: { $0.id == ep.id }) else { return }
        queue.append(ep); save()
    }

    func playNext(_ ep: Episode) {
        guard !queue.contains(where: { $0.id == ep.id }) else { return }
        let ins = min(queueIndex + 1, queue.count)
        queue.insert(ep, at: ins)
        save()
    }

    func playNow(_ ep: Episode) {
        if let i = queue.firstIndex(where: { $0.id == ep.id }) {
            queueIndex = i
        } else {
            let ins = min(queueIndex + 1, queue.count)
            queue.insert(ep, at: ins)
            queueIndex = ins
        }
        loadTrack(ep, play: true); save()
    }

    func removeFromQueue(at index: Int) {
        guard index < queue.count else { return }
        let ep = queue[index]
        queue.remove(at: index)
        if queue.isEmpty {
            queueIndex = 0; isPlaying = false
            loadedEpisodeId = nil
            player.replaceCurrentItem(with: nil)
        } else if index < queueIndex {
            queueIndex -= 1
        } else if queueIndex >= queue.count {
            queueIndex = queue.count - 1
        }
        if loadedEpisodeId == ep.id, let next = currentEpisode {
            loadTrack(next, play: isPlaying)
        }
        save()
    }

    func moveQueue(from: IndexSet, to: Int) {
        let curId = currentEpisode?.id
        queue.move(fromOffsets: from, toOffset: to)
        if let id = curId { queueIndex = queue.firstIndex(where: { $0.id == id }) ?? 0 }
        save()
    }

    func playAt(_ index: Int) {
        guard index < queue.count else { return }
        if let ep = currentEpisode { savedPos[ep.id] = currentPos }
        queueIndex = index
        loadTrack(queue[index], play: true); save()
    }

    func keepCurrent() {
        guard let cur = currentEpisode else { return }
        queue = [cur]; queueIndex = 0
        save()
    }

    func isInQueue(_ epId: String) -> Bool { queue.contains { $0.id == epId } }

    // MARK: - Library / Subscriptions

    func isSubscribed(_ podId: String) -> Bool { subscriptions.contains { $0.id == podId } }

    func subscribe(_ podcast: Podcast) {
        if !isSubscribed(podcast.id) { subscriptions.append(podcast) }
        if let eps = browseCache[podcast.id] { library[podcast.id] = eps }
        save()
    }

    func updatePodcastDetails(_ podcast: Podcast) {
        if let index = subscriptions.firstIndex(where: { $0.id == podcast.id }) {
            subscriptions[index] = podcast
            save()
        }
    }

    func unsubscribe(_ podId: String) {
        subscriptions.removeAll { $0.id == podId }
        library.removeValue(forKey: podId)
        save()
    }

    func episodesFor(_ podId: String) -> [Episode] {
        library[podId] ?? browseCache[podId] ?? []
    }

    func storeFeed(_ episodes: [Episode], for podcast: Podcast) {
        if isSubscribed(podcast.id) {
            library[podcast.id] = episodes
            if let i = subscriptions.firstIndex(where: { $0.id == podcast.id }) {
                var updated = podcast
                if !episodes.isEmpty,
                   let episodeArt = episodes.first(where: { !$0.artUrl.isEmpty })?.artUrl,
                   updated.artUrl.isEmpty || updated.artUrl == subscriptions[i].artUrl {
                    updated.artUrl = episodeArt
                }
                subscriptions[i] = updated
            }
            save()
        } else {
            browseCache[podcast.id] = episodes
        }
    }

    // MARK: - Waypoints

    func addWaypoint(isSleep: Bool, ep: Episode) {
        if isSleep { waypoints.removeAll { $0.isSleep && $0.epId == ep.id } }
        waypoints.insert(Waypoint(
            id: UUID().uuidString, isSleep: isSleep,
            epId: ep.id, pos: currentPos,
            epTitle: ep.title, showName: ep.podName,
            artUrl: ep.artUrl, epNum: ep.epNum, ts: Date()
        ), at: 0)
        save()
    }

    func jumpToWaypoint(_ wp: Waypoint) {
        if let i = queue.firstIndex(where: { $0.id == wp.epId }) {
            if i != queueIndex { queueIndex = i; loadTrack(queue[i], startAt: wp.pos, play: true) }
            else { seek(to: wp.pos) }
        } else if let ep = episode(withId: wp.epId) {
            queue.insert(ep, at: min(queueIndex + 1, queue.count))
            queueIndex = queue.firstIndex(where: { $0.id == wp.epId }) ?? queueIndex
            loadTrack(ep, startAt: wp.pos, play: true)
            save()
        } else {
            toast("Episode is not in your library")
        }
    }

    private func episode(withId epId: String) -> Episode? {
        if let ep = queue.first(where: { $0.id == epId }) { return ep }
        for episodes in library.values {
            if let ep = episodes.first(where: { $0.id == epId }) { return ep }
        }
        for episodes in browseCache.values {
            if let ep = episodes.first(where: { $0.id == epId }) { return ep }
        }
        return nil
    }

    // MARK: - Sleep Timer

    func cycleSleep() {
        let options = [0, 15, 30, 45, 60]
        let cur = options.firstIndex(of: sleepMinutes) ?? 0
        let next = options[(cur + 1) % options.count]
        sleepTask?.cancel(); sleepTask = nil
        if next == 0 {
            if let ep = currentEpisode { waypoints.removeAll { $0.isSleep && $0.epId == ep.id } }
            save()
        } else {
            if let ep = currentEpisode { addWaypoint(isSleep: true, ep: ep) }
            let secs = next * 60
            sleepTask = Task {
                try? await Task.sleep(for: .seconds(secs))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.player.pause(); self.isPlaying = false
                    self.sleepMinutes = 0
                    self.updateNowPlaying(); self.save()
                }
            }
        }
        sleepMinutes = next
    }

    // MARK: - Toast

    func toast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.18)) {
            toastMessage = message; isShowingToast = true
        }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.18)) { self.isShowingToast = false }
            }
        }
    }

    // MARK: - Persistence

    private static let saveURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("backtrack_v1.json")

    private static let legacySaveURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("sidetrack_v1.json")

    func save() {
        let s = AppSnapshot(subscriptions: subscriptions, library: library,
                            queue: queue, queueIndex: queueIndex, currentPos: currentPos,
                            savedPos: savedPos, speed: speed,
                            waypoints: waypoints, listened: listened)
        guard let data = try? JSONEncoder().encode(s) else { return }
        let url = Self.saveURL
        Task.detached(priority: .background) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func load() {
        let url = FileManager.default.fileExists(atPath: Self.saveURL.path) ? Self.saveURL : Self.legacySaveURL
        guard let data = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode(AppSnapshot.self, from: data) else { return }
        subscriptions = s.subscriptions; library  = s.library
        queue         = s.queue;         speed    = s.speed
        queueIndex    = max(0, min(s.queueIndex, max(0, s.queue.count - 1)))
        currentPos    = s.currentPos;    savedPos = s.savedPos
        waypoints     = s.waypoints;     listened = s.listened
    }
}

private struct AppSnapshot: Codable, Sendable {
    var subscriptions: [Podcast]; var library: [String: [Episode]]
    var queue: [Episode]; var queueIndex: Int; var currentPos: TimeInterval
    var savedPos: [String: TimeInterval]; var speed: Float
    var waypoints: [Waypoint]; var listened: [String: Bool]
}
