import Foundation
import SwiftUI

/// A run of text with inline styling derived from Sefaria's light HTML.
struct StyledRun: Hashable, Sendable {
    var text: String
    var bold = false
    var italic = false
    var small = false
    var superscript = false
}

/// Converts Sefaria HTML (`<b>`, `<i>`, `<small>`, `<br>`, `<span>`, `<sup>` …)
/// into styled runs. Footnotes are dropped; unknown tags are ignored.
enum HTMLText {
    nonisolated(unsafe) private static var cache: [String: [StyledRun]] = [:]
    private static let lock = NSLock()

    static func runs(from html: String) -> [StyledRun] {
        lock.lock()
        if let hit = cache[html] { lock.unlock(); return hit }
        lock.unlock()
        let result = parse(html)
        lock.lock()
        if cache.count > 4000 { cache.removeAll(keepingCapacity: true) }
        cache[html] = result
        lock.unlock()
        return result
    }

    /// Plain text with all tags removed (used for search and accessibility).
    static func plainText(from html: String) -> String {
        runs(from: html).map(\.text).joined()
    }

    private struct Style: Hashable {
        var bold = false, italic = false, small = false, superscript = false
    }

    private static func parse(_ html: String) -> [StyledRun] {
        var runs: [StyledRun] = []
        var buffer = ""
        var stack: [(tag: String, style: Style)] = []
        var style = Style()
        var skipDepth = 0 // > 0 while inside a footnote

        func flush() {
            guard !buffer.isEmpty else { return }
            if let last = runs.indices.last,
               runs[last].bold == style.bold, runs[last].italic == style.italic,
               runs[last].small == style.small, runs[last].superscript == style.superscript {
                runs[last].text += buffer
            } else {
                runs.append(StyledRun(text: buffer, bold: style.bold, italic: style.italic, small: style.small, superscript: style.superscript))
            }
            buffer = ""
        }

        var i = html.startIndex
        while i < html.endIndex {
            let ch = html[i]
            if ch == "<" {
                guard let close = html[i...].firstIndex(of: ">") else { break }
                let raw = html[html.index(after: i)..<close]
                i = html.index(after: close)
                handleTag(String(raw))
                continue
            }
            if ch == "&" {
                if let semi = html[i...].prefix(10).firstIndex(of: ";") {
                    let entity = String(html[html.index(after: i)..<semi])
                    if let decoded = decodeEntity(entity) {
                        if skipDepth == 0 { buffer.append(decoded) }
                        i = html.index(after: semi)
                        continue
                    }
                }
            }
            if skipDepth == 0 { buffer.append(ch) }
            i = html.index(after: i)
        }
        flush()

        func handleTag(_ raw: String) {
            var body = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let isClosing = body.hasPrefix("/")
            if isClosing { body.removeFirst() }
            let selfClosing = body.hasSuffix("/")
            if selfClosing { body.removeLast() }
            let parts = body.split(whereSeparator: { $0.isWhitespace })
            guard let nameSub = parts.first else { return }
            let name = nameSub.lowercased()
            let attrs = body.lowercased()
            let isFootnote = attrs.contains("footnote")

            if isClosing {
                if let idx = stack.lastIndex(where: { $0.tag == name }) {
                    if name == "span" || name == "i" || name == "sup" {
                        // footnote spans/markers push skipDepth; pop it back when they close
                        if skipDepth > 0 && stack[idx].tag == name { skipDepth = max(0, skipDepth - 1) }
                    }
                    flush()
                    style = stack[idx].style
                    stack.removeSubrange(idx...)
                }
                return
            }

            switch name {
            case "br":
                if skipDepth == 0 { buffer.append("\n") }
            case "p", "div":
                if skipDepth == 0, !buffer.isEmpty, !buffer.hasSuffix("\n") { buffer.append("\n") }
            case "b", "strong":
                flush(); stack.append((name, style)); style.bold = true
            case "i", "em":
                flush(); stack.append((name, style))
                if isFootnote { skipDepth += 1 } else { style.italic = true }
            case "small":
                flush(); stack.append((name, style)); style.small = true
            case "big":
                flush(); stack.append((name, style)); style.bold = true
            case "sup":
                flush(); stack.append((name, style))
                if isFootnote { skipDepth += 1 } else { style.superscript = true }
            case "span":
                flush(); stack.append((name, style))
                if isFootnote { skipDepth += 1 }
                if attrs.contains("mam-spi-samekh") || attrs.contains("mam-spi-pe") { style.small = true }
            default:
                break
            }
        }

        return runs.filter { !$0.text.isEmpty }
    }

    private static func decodeEntity(_ entity: String) -> String? {
        switch entity {
        case "nbsp": return "\u{00A0}"
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos", "#39": return "'"
        case "thinsp": return "\u{2009}"
        case "ndash": return "–"
        case "mdash": return "—"
        case "hellip": return "…"
        default:
            if entity.hasPrefix("#x"), let v = UInt32(entity.dropFirst(2), radix: 16), let s = Unicode.Scalar(v) { return String(Character(s)) }
            if entity.hasPrefix("#"), let v = UInt32(entity.dropFirst()), let s = Unicode.Scalar(v) { return String(Character(s)) }
            return nil
        }
    }
}
