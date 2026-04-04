//
//  TagBadge.swift
//  ToJo
//

import SwiftUI

struct TagBadge: View {
    let tag: Tag
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(tag.name)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(tagColor.opacity(0.5))
            .foregroundStyle(textColor)
            .clipShape(Capsule())
    }

    private var tagColor: Color {
        if let hex = tag.colorHex {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }

    private var textColor: Color {
        let mix: Color = colorScheme == .dark ? .white : .black
        return tagColor.mix(with: mix, by: 0.7)
    }
}

// MARK: - Removable Tag Badge

struct RemovableTagBadge: View {
    let tag: Tag
    let onRemove: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var tagColor: Color {
        if let hex = tag.colorHex {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }

    private var textColor: Color {
        let mix: Color = colorScheme == .dark ? .white : .black
        return tagColor.mix(with: mix, by: 0.7)
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
        .padding(.vertical, 2)
        .background(tagColor.opacity(0.25))
        .foregroundStyle(textColor)
        .clipShape(Capsule())
    }
}
