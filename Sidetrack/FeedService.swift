import Foundation

struct FeedService {

    // MARK: - iTunes Search

    static func searchPodcasts(_ query: String) async throws -> [Podcast] {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "limit", value: "25"),
            URLQueryItem(name: "term", value: query)
        ]
        guard let url = components?.url else { throw URLError(.badURL) }
        let data = try await fetchData(from: url)
        let result = try JSONDecoder().decode(iTunesResponse.self, from: data)
        return result.results.compactMap { item -> Podcast? in
            guard let feedUrl = item.feedUrl, !feedUrl.isEmpty else { return nil }
            return Podcast(
                id: "itunes_\(item.collectionId)",
                name: item.collectionName,
                author: item.artistName,
                desc: "",
                artUrl: cleanURLString(item.artworkUrl600 ?? item.artworkUrl100),
                feedUrl: feedUrl
            )
        }
    }

    // MARK: - RSS Feed

    static func fetchFeed(podcast: Podcast) async throws -> [Episode] {
        guard let url = URL(string: podcast.feedUrl) else { throw URLError(.badURL) }
        let data = try await fetchData(from: url)
        return RSSParser().parse(data: data, podcast: podcast)
    }

    static func fetchPodcastDetails(podcast: Podcast) async throws -> Podcast {
        guard let url = URL(string: podcast.feedUrl) else { throw URLError(.badURL) }
        let data = try await fetchData(from: url)
        return PodcastMetadataParser().parse(data: data, fallback: podcast)
    }

    // MARK: - JSON Chapters

    static func fetchChapters(urlString: String) async throws -> [Chapter] {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let data = try await fetchData(from: url)
        let root = try JSONDecoder().decode(ChaptersRoot.self, from: data)
        var chapters = root.chapters.map { item in
            Chapter(title: item.title ?? "Chapter",
                    startTime: item.startTime,
                    endTime: item.endTime,
                    imageUrl: item.img,
                    url: item.url)
        }
        guard chapters.count > 1 else { return chapters }
        for i in 0..<(chapters.count - 1) {
            if chapters[i].endTime == nil {
                chapters[i].endTime = chapters[i + 1].startTime
            }
        }
        return chapters
    }

    // MARK: - ID3 CHAP fallback

    static func fetchChaptersFromID3(audioUrl: String) async throws -> [Chapter]? {
        guard let url = URL(string: audioUrl) else { return nil }

        let maxBytes = 3 * 1024 * 1024
        var req = URLRequest(url: url, timeoutInterval: 25)
        req.setValue("bytes=0-\(maxBytes - 1)", forHTTPHeaderField: "Range")

        let data = try await fetchData(for: req)
        let buf = [UInt8](data)

        guard buf.count >= 10,
              buf[0] == 0x49, buf[1] == 0x44, buf[2] == 0x33 else { return nil }

        let ver    = Int(buf[3])
        let tagEnd = 10 + (Int(buf[6] & 0x7f) << 21 | Int(buf[7] & 0x7f) << 14 |
                           Int(buf[8] & 0x7f) << 7  | Int(buf[9] & 0x7f))
        let idLen  = ver <= 2 ? 3 : 4
        let hdrLen = ver <= 2 ? 6 : 10

        func fsz(_ i: Int) -> Int {
            guard i + idLen <= buf.count else { return 0 }
            if ver <= 2 {
                return Int(buf[i]) << 16 | Int(buf[i+1]) << 8 | Int(buf[i+2])
            } else if ver == 4 {
                return Int(buf[i]&0x7f) << 21 | Int(buf[i+1]&0x7f) << 14 |
                       Int(buf[i+2]&0x7f) << 7 | Int(buf[i+3]&0x7f)
            } else {
                return Int(buf[i]) << 24 | Int(buf[i+1]) << 16 |
                       Int(buf[i+2]) << 8 | Int(buf[i+3])
            }
        }

        func str(_ start: Int, _ len: Int) -> String {
            guard start < buf.count, len > 0 else { return "" }
            let raw = Data(buf[(start+1)..<min(start+len, buf.count)])
            let s: String?
            switch buf[start] {
            case 1:  s = String(data: raw, encoding: .utf16)
            case 2:  s = String(data: raw, encoding: .utf16BigEndian)
            case 3:  s = String(data: raw, encoding: .utf8)
            default: s = String(data: raw, encoding: .isoLatin1)
            }
            return s?.replacingOccurrences(of: "\0", with: "") ?? ""
        }

        var chapters: [Chapter] = []
        var pos = 10
        let limit = min(tagEnd, buf.count)

        while pos + hdrLen <= limit {
            guard buf[pos] != 0 else { break }
            let fid  = String(bytes: buf[pos..<min(pos+idLen, buf.count)], encoding: .isoLatin1) ?? ""
            let size = fsz(pos + idLen)
            guard size > 0, pos + hdrLen + size <= limit else { break }
            let fdata = pos + hdrLen

            if fid == "CHAP" {
                var e = fdata
                while e < buf.count && buf[e] != 0 { e += 1 }
                let t = e + 1
                guard t + 16 <= buf.count else { pos += hdrLen + size; continue }

                let startMs = UInt32(buf[t])<<24 | UInt32(buf[t+1])<<16 |
                              UInt32(buf[t+2])<<8 | UInt32(buf[t+3])
                let endMs   = UInt32(buf[t+4])<<24 | UInt32(buf[t+5])<<16 |
                              UInt32(buf[t+6])<<8 | UInt32(buf[t+7])

                var title = "", chUrl: String? = nil
                var sub = t + 16
                let subEnd = fdata + size

                while sub + hdrLen <= min(subEnd, buf.count) {
                    guard buf[sub] != 0 else { break }
                    let sid = String(bytes: buf[sub..<min(sub+idLen, buf.count)], encoding: .isoLatin1) ?? ""
                    let ssz = fsz(sub + idLen)
                    guard ssz > 0, sub + hdrLen + ssz <= min(subEnd, buf.count) else { break }
                    if sid == "TIT2" { title = str(sub + hdrLen, ssz) }
                    if sid == "WXXX" || sid == "WXX" {
                        var de = sub + hdrLen + 1
                        while de < buf.count && buf[de] != 0 { de += 1 }
                        chUrl = String(data: Data(buf[(de+1)..<min(sub+hdrLen+ssz, buf.count)]),
                                       encoding: .utf8)
                    }
                    sub += hdrLen + ssz
                }

                chapters.append(Chapter(
                    title: title.isEmpty ? "Chapter \(chapters.count + 1)" : title,
                    startTime: Double(startMs) / 1000,
                    endTime: endMs == 0xFFFFFFFF ? nil : Double(endMs) / 1000,
                    url: chUrl
                ))
            }
            pos += hdrLen + size
        }

        guard !chapters.isEmpty else { return nil }
        var sorted = chapters.sorted { $0.startTime < $1.startTime }
        guard sorted.count > 1 else { return sorted }
        for i in 0..<(sorted.count - 1) {
            if sorted[i].endTime == nil { sorted[i].endTime = sorted[i+1].startTime }
        }
        return sorted
    }

    private static func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("Backtrack/1.0", forHTTPHeaderField: "User-Agent")
        return try await fetchData(for: request)
    }

    private static func fetchData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return data
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    fileprivate static func cleanURLString(_ value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: " ", with: "%20")
        if cleaned.hasPrefix("http://") {
            return "https://" + cleaned.dropFirst("http://".count)
        }
        return cleaned
    }
}

// MARK: - Podcast Metadata Parser

final class PodcastMetadataParser: NSObject, XMLParserDelegate {
    private var fallback: Podcast!
    private var buf = ""
    private var isInItem = false
    private var name = ""
    private var author = ""
    private var desc = ""
    private var artUrl = ""
    private var isInChannelImage = false

    func parse(data: Data, fallback: Podcast) -> Podcast {
        self.fallback = fallback
        self.name = fallback.name
        self.author = fallback.author
        self.desc = fallback.desc
        self.artUrl = fallback.artUrl
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return Podcast(
            id: fallback.id,
            name: name.isEmpty ? fallback.name : name,
            author: author.isEmpty ? fallback.author : author,
            desc: desc.isEmpty ? fallback.desc : desc,
            artUrl: artUrl.isEmpty ? fallback.artUrl : FeedService.cleanURLString(artUrl),
            feedUrl: fallback.feedUrl
        )
    }

    func parser(_ parser: XMLParser, didStartElement el: String, namespaceURI: String?,
                qualifiedName: String?, attributes a: [String: String] = [:]) {
        buf = ""
        let name = el.lowercased()
        if name == "item" { isInItem = true }
        if !isInItem, name == "image" { isInChannelImage = true }
        guard !isInItem else { return }
        if name == "itunes:image", let href = a["href"], !href.isEmpty {
            artUrl = href
        } else if (name == "media:thumbnail" || name == "media:content"),
                  let url = a["url"], !url.isEmpty {
            artUrl = url
        }
    }

    func parser(_ parser: XMLParser, foundCharacters s: String) { buf += s }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let text = String(data: CDATABlock, encoding: .utf8) {
            buf += text
        }
    }

    func parser(_ parser: XMLParser, didEndElement el: String,
                namespaceURI: String?, qualifiedName: String?) {
        let text = buf.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { buf = "" }
        let name = el.lowercased()
        if name == "item" {
            isInItem = false
            return
        }
        if name == "image" {
            isInChannelImage = false
            return
        }
        guard !isInItem, !text.isEmpty else { return }
        switch name {
        case "title":
            if !isInChannelImage, self.name.isEmpty || self.name == fallback.name { self.name = text }
        case "itunes:author", "managingeditor":
            if author.isEmpty || author == fallback.author { author = text }
        case "description", "itunes:summary":
            if desc.isEmpty || desc == fallback.desc { desc = text }
        case "url":
            if isInChannelImage { artUrl = text }
        default:
            break
        }
    }
}

// MARK: - iTunes JSON models

private struct iTunesResponse: Decodable { var results: [iTunesItem] }
private struct iTunesItem: Decodable {
    var collectionId: Int; var collectionName: String; var artistName: String
    var artworkUrl100: String; var artworkUrl600: String?; var feedUrl: String?
}

// MARK: - Chapters JSON model

private struct ChaptersRoot: Decodable {
    var chapters: [ChapterItem]
    struct ChapterItem: Decodable {
        var title: String?
        var startTime: TimeInterval
        var endTime: TimeInterval?
        var img: String?
        var url: String?
    }
}

// MARK: - RSS Parser

final class RSSParser: NSObject, XMLParserDelegate {
    private var episodes: [Episode] = []
    private var podcast: Podcast!
    private var buf = ""
    private var ep: EpBuf?
    private var inItem = false
    private var inItemImage = false

    private class EpBuf {
        var title = ""; var guid = ""; var audioUrl = ""; var artUrl = ""
        var desc = ""; var descHtml = ""; var duration: TimeInterval = 0
        var date = Date(); var epNum: Int?; var chaptersUrl: String? = nil
    }

    func parse(data: Data, podcast: Podcast) -> [Episode] {
        self.podcast = podcast
        let p = XMLParser(data: data)
        p.delegate = self; p.parse()
        return episodes
    }

    func parser(_ parser: XMLParser, didStartElement el: String, namespaceURI: String?,
                qualifiedName: String?, attributes a: [String: String] = [:]) {
        buf = ""
        let name = el.lowercased()
        if name == "item" { inItem = true; ep = EpBuf() }
        guard inItem else { return }
        if name == "image" { inItemImage = true }
        switch name {
        case "enclosure":        ep?.audioUrl    = a["url"] ?? ""
        case "itunes:image":     ep?.artUrl      = a["href"] ?? ""
        case "media:thumbnail",
             "media:content":    ep?.artUrl      = a["url"] ?? ep?.artUrl ?? ""
        case "podcast:chapters": ep?.chaptersUrl = a["url"]
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters s: String) { buf += s }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let text = String(data: CDATABlock, encoding: .utf8) {
            buf += text
        }
    }

    func parser(_ parser: XMLParser, didEndElement el: String,
                namespaceURI: String?, qualifiedName: String?) {
        let text = buf.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { buf = "" }
        guard inItem, let ep else { return }
        let name = el.lowercased()
        switch name {
        case "title":           ep.title    = text
        case "guid":            ep.guid     = text
        case "description":     if ep.desc.isEmpty { ep.desc = text }
        case "content:encoded": ep.descHtml = text
        case "itunes:duration": ep.duration = parseDuration(text)
        case "pubdate":         ep.date     = parseDate(text) ?? Date()
        case "itunes:episode":  ep.epNum    = Int(text)
        case "item":
            inItem = false
            guard !ep.audioUrl.isEmpty else { return }
            let src  = ep.guid.isEmpty ? ep.audioUrl : ep.guid
            let epId = stableId(src, podId: podcast.id)
            let art  = FeedService.cleanURLString(ep.artUrl.isEmpty ? podcast.artUrl : ep.artUrl)
            let html = ep.descHtml.isEmpty ? nil : ep.descHtml
            episodes.append(Episode(
                id: epId, podId: podcast.id, podName: podcast.name,
                title: ep.title.isEmpty ? "Episode" : ep.title,
                audioUrl: ep.audioUrl, artUrl: art,
                desc: ep.desc, descHtml: html,
                duration: ep.duration, date: ep.date,
                epNum: ep.epNum, chaptersUrl: ep.chaptersUrl,
                feedUrl: podcast.feedUrl
            ))
            self.ep = nil
        case "url":
            if inItemImage { ep.artUrl = text }
        case "image":
            inItemImage = false
        default: break
        }
    }

    private func stableId(_ src: String, podId: String) -> String {
        var h = 5381
        for c in (podId + src).unicodeScalars { h = ((h << 5) &+ h) &+ Int(c.value) }
        return "\(podId)_\(abs(h))"
    }

    private func parseDuration(_ s: String) -> TimeInterval {
        let parts = s.split(separator: ":").compactMap { Double($0) }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        default: return Double(s) ?? 0
        }
    }

    private func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss z",
                    "EEE,  d MMM yyyy HH:mm:ss Z"] {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}
