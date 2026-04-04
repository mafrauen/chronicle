//
//  PinnedPaneView.swift
//  ToJo
//

import SwiftUI

struct PinnedPaneView: View {
    @Bindable var entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.blue)
                Text(entry.title.isEmpty ? "Untitled" : entry.title)
                    .font(.title2)
                Spacer()
            }
            .padding()
            .padding([.bottom], 1.5)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Content
            ScrollView {
                Text(entry.content.isEmpty ? "No content" : entry.content)
                    .font(.body)
                    .foregroundStyle(entry.content.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
        }
    }
}
