import Foundation

struct Podcast: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var author: String
    var desc: String
    var artUrl: String
    var feedUrl: String
}

struct Episode: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var podId: String
    var podName: String
    var title: String
    var audioUrl: String
    var artUrl: String
    var desc: String
    var descHtml: String?
    var duration: TimeInterval
    var date: Date
    var epNum: Int?
    var chaptersUrl: String?   // nil=not fetched, ""=fetched/none, url=has chapters
    var feedUrl: String
}

struct Waypoint: Identifiable, Codable, Sendable {
    var id: String
    var isSleep: Bool
    var epId: String
    var pos: TimeInterval
    var epTitle: String
    var showName: String
    var artUrl: String
    var epNum: Int?
    var ts: Date
}

struct Chapter: Identifiable {
    var id = UUID().uuidString
    var title: String
    var startTime: TimeInterval
    var endTime: TimeInterval?
    var imageUrl: String?
    var url: String?
}

enum ChaptersLoadState {
    case idle, loading, noChapters, failed
    case loaded([Chapter])
}

extension TimeInterval {
    var hmsFormatted: String {
        let t = max(0, self)
        let h = Int(t) / 3600
        let m = Int(t) % 3600 / 60
        let s = Int(t) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
