//
//  TagBadge.swift
//  Chronicle
//

import SwiftUI

struct TagBadge: View {
    let tag: Tag

    var body: some View {
        Text(tag.name)
            .font(.caption)
            .padding(.horizontal, 8)
            #if os(iOS)
            .padding(.vertical, 3)
            #else
            .padding(.vertical, 2)
            #endif
            .background(tagColor.opacity(0.8))
            .foregroundStyle(tagColor.contrastingTextColor)
            .clipShape(Capsule())
    }

    private var tagColor: Color {
        if let hex = tag.colorHex {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }
}

// MARK: - Removable Tag Badge

struct RemovableTagBadge: View {
    let tag: Tag
    let onRemove: () -> Void

    private var tagColor: Color {
        if let hex = tag.colorHex {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(tag.name)
                .font(.caption)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        #if os(iOS)
        .padding(.vertical, 3)
        #else
        .padding(.vertical, 2)
        #endif
        .background(tagColor.opacity(0.8))
        .foregroundStyle(tagColor.contrastingTextColor)
        .clipShape(Capsule())
    }
}
