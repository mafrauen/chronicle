//
//  EntryRowView.swift
//  Chronicle
//

import SwiftUI

struct EntryRowView: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .id("top")
                }

                Text(entry.title.isEmpty ? "Untitled" : entry.title)
                    .font(.headline)
            }

            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Text(entry.createdAt, format: .dateTime.month().day().year())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if !entry.tagList.isEmpty {
                    ForEach(entry.tagList) { tag in
                        TagBadge(tag: tag)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
