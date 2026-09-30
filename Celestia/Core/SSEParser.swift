import Foundation

struct SSEMessage: Equatable, Sendable {
    var event: String
    var data: String
    var id: String?
}

/// Incremental parser for `text/event-stream` (WHATWG spec subset: event, data, id,
/// comments). Feed it lines as they arrive; it emits a message on each blank line.
struct SSEParser: Sendable {
    private var event: String?
    private var dataLines: [String] = []
    private var id: String?

    mutating func feed(line rawLine: String) -> SSEMessage? {
        let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine

        if line.isEmpty {
            defer { event = nil; dataLines = []; id = nil }
            guard !dataLines.isEmpty else { return nil }
            return SSEMessage(event: event ?? "message", data: dataLines.joined(separator: "\n"), id: id)
        }
        if line.hasPrefix(":") { return nil }

        let field: Substring
        var value: Substring
        if let colon = line.firstIndex(of: ":") {
            field = line[..<colon]
            value = line[line.index(after: colon)...]
            if value.hasPrefix(" ") { value = value.dropFirst() }
        } else {
            field = Substring(line)
            value = ""
        }

        switch field {
        case "event": event = String(value)
        case "data": dataLines.append(String(value))
        case "id": id = String(value)
        default: break
        }
        return nil
    }

    /// Flushes a trailing message when the stream ends without a final blank line.
    mutating func finish() -> SSEMessage? {
        feed(line: "")
    }
}
