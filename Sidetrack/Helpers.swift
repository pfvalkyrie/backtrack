import UIKit
import SwiftUI

extension String {
    // True if the string contains HTML markup (vs Markdown plain text)
    var isHTML: Bool {
        range(of: "<[a-zA-Z]", options: .regularExpression) != nil
    }

    // Renders HTML or Markdown intelligently, with dark-mode styling.
    var notesAttributedString: AttributedString? {
        let source = isHTML ? htmlAsMarkdown : self
        return try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )
    }

    var htmlAsMarkdown: String {
        var text = self
            .replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: "", options: [.regularExpression, .caseInsensitive])

        let anchorPattern = #"<a\s+[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)</a>"#
        if let regex = try? NSRegularExpression(pattern: anchorPattern, options: [.caseInsensitive]) {
            let ns = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: ns).reversed()
            for match in matches where match.numberOfRanges >= 3 {
                guard let fullRange = Range(match.range(at: 0), in: text),
                      let urlRange = Range(match.range(at: 1), in: text),
                      let labelRange = Range(match.range(at: 2), in: text) else { continue }
                let url = String(text[urlRange]).markdownEscapedURL
                let label = String(text[labelRange]).strippingHTML.markdownEscapedLabel
                text.replaceSubrange(fullRange, with: "[\(label.isEmpty ? url : label)](\(url))")
            }
        }

        return text.strippingHTML
    }

    var strippingHTML: String {
        let cleaned = self
            .replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "</p\\s*>", with: "\n\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "</div\\s*>", with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "</li\\s*>", with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<li[^>]*>", with: "• ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        return cleaned
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var markdownEscapedLabel: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }

    private var markdownEscapedURL: String {
        replacingOccurrences(of: ")", with: "%29")
            .replacingOccurrences(of: "(", with: "%28")
            .replacingOccurrences(of: " ", with: "%20")
    }
}

struct RichPodcastText: View {
    let text: String
    var font: Font = .system(size: 13)
    var foreground: Color = .sDim
    var lineLimit: Int?
    var textAlignment: TextAlignment = .leading

    init(
        _ text: String,
        font: Font = .system(size: 13),
        foreground: Color = .sDim,
        lineLimit: Int? = nil,
        textAlignment: TextAlignment = .leading
    ) {
        self.text = text
        self.font = font
        self.foreground = foreground
        self.lineLimit = lineLimit
        self.textAlignment = textAlignment
    }

    var body: some View {
        Group {
            if let attr = text.notesAttributedString {
                Text(attr)
                    .tint(.sOrange)
            } else {
                Text(text.strippingHTML)
            }
        }
        .font(font)
        .foregroundColor(foreground)
        .multilineTextAlignment(textAlignment)
        .lineLimit(lineLimit)
    }
}

struct RemoteArtworkView: View {
    let urls: [String]
    var cornerRadius: CGFloat = 12

    @State private var urlIndex = 0

    private var candidates: [URL] {
        urls
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { value in
                value.hasPrefix("http://") ? "https://" + value.dropFirst("http://".count) : value
            }
            .filter { !$0.isEmpty }
            .compactMap(URL.init(string:))
    }

    var body: some View {
        Group {
            if candidates.indices.contains(urlIndex) {
                AsyncImage(url: candidates[urlIndex]) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        fallbackOrPlaceholder
                    case .empty:
                        artworkPlaceholder
                    @unknown default:
                        artworkPlaceholder
                    }
                }
                .id(candidates[urlIndex])
                .onChange(of: urls) { _, _ in urlIndex = 0 }
            } else {
                artworkPlaceholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    private var fallbackOrPlaceholder: some View {
        if urlIndex + 1 < candidates.count {
            artworkPlaceholder
                .task { urlIndex += 1 }
        } else {
            artworkPlaceholder
        }
    }

    private var artworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.sS3.opacity(0.72))
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.sMuted)
        }
    }
}
