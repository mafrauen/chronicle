//
//  ExportSheet.swift
//  ToJo
//

import SwiftUI
import UniformTypeIdentifiers

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }

    let csvContent: String
    let jsonContent: String
    let textContent: String

    init() {
        self.csvContent = ""
        self.jsonContent = ""
        self.textContent = ""
    }

    init(entries: [Entry]) {
        self.csvContent = EntryExporter.csv(from: entries)
        self.jsonContent = EntryExporter.json(from: entries)
        self.textContent = EntryExporter.plainText(from: entries)
    }

    init(configuration: ReadConfiguration) throws {
        self.csvContent = ""
        self.jsonContent = ""
        self.textContent = ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let content: String
        switch configuration.contentType {
        case .commaSeparatedText:
            content = csvContent
        case .json:
            content = jsonContent
        default:
            content = textContent
        }
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Entry Exporter

enum EntryExporter {
    static func csv(from entries: [Entry]) -> String {
        var lines = ["\"Title\",\"Content\",\"Tags\",\"Created\",\"Modified\""]
        for entry in entries {
            let title = entry.title.replacingOccurrences(of: "\"", with: "\"\"")
            let content = entry.content.replacingOccurrences(of: "\"", with: "\"\"")
            let tags = entry.tags.map { $0.name.replacingOccurrences(of: ";", with: "\\;") }.joined(separator: "; ")
            let created = ISO8601DateFormatter().string(from: entry.createdAt)
            let modified = ISO8601DateFormatter().string(from: entry.lastModifiedAt)
            lines.append("\"\(title)\",\"\(content)\",\"\(tags)\",\"\(created)\",\"\(modified)\"")
        }
        return lines.joined(separator: "\n")
    }

    static func json(from entries: [Entry]) -> String {
        let items = entries.map { entry -> [String: Any] in
            [
                "title": entry.title,
                "content": entry.content,
                "tags": entry.tags.map(\.name),
                "created": ISO8601DateFormatter().string(from: entry.createdAt),
                "modified": ISO8601DateFormatter().string(from: entry.lastModifiedAt),
                "pinned": entry.isPinned
            ]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    static func plainText(from entries: [Entry]) -> String {
        entries.map { entry in
            var parts: [String] = []
            parts.append(entry.title.isEmpty ? "Untitled" : entry.title)
            parts.append("Created: \(ISO8601DateFormatter().string(from: entry.createdAt))")
            if !entry.tags.isEmpty {
                parts.append("Tags: \(entry.tags.map(\.name).joined(separator: ", "))")
            }
            if !entry.content.isEmpty {
                parts.append("")
                parts.append(entry.content)
            }
            return parts.joined(separator: "\n")
        }.joined(separator: "\n\n// ---\n\n")
    }
}
