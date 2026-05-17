import UIKit

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
