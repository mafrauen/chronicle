//
//  EntryDetailView.swift
//  ToJo
//

import SwiftUI
import SwiftData

struct EntryDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Bindable var entry: Entry
    let onPin: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var showingTagPicker = false
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isContentFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Entry Title", text: $entry.title)
                .font(.title2)
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            TextEditor(text: $entry.content)
                .font(.body)
                .focused($isContentFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .onChange(of: entry.content) { oldValue, newValue in
                    entry.lastModifiedAt = Date()
                }
                .onChange(of: entry.title) { oldValue, newValue in
                    entry.lastModifiedAt = Date()
                }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button {
                        showingTagPicker = true
                    } label: {
                        Image(systemName: "tag")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Browse all tags")
                    .popover(isPresented: $showingTagPicker, arrowEdge: .top) {
                        TagPickerView(entry: entry, allTags: allTags)
                    }

                    if !entry.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(entry.tags) { tag in
                                    RemovableTagBadge(tag: tag) {
                                        removeTag(tag)
                                    }
                                }
                            }
                        }
                    }
                }

                HStack {
                    Text("Created: \(entry.createdAt, format: .dateTime.month().day().year().hour().minute())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Modified: \(entry.lastModifiedAt, format: .relative(presentation: .named))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onPin()
                } label: {
                    Label(entry.isPinned ? "Pinned" : "Pin", systemImage: entry.isPinned ? "pin.fill" : "pin")
                }
            }
        }
        .onChange(of: appModel.shouldFocusTitle) { oldValue, newValue in
            if newValue {
                isTitleFocused = true
                appModel.shouldFocusTitle = false
            }
        }
        .onChange(of: appModel.shouldFocusTagField) { oldValue, newValue in
            if newValue {
                showingTagPicker = true
                appModel.shouldFocusTagField = false
            }
        }
        .onChange(of: appModel.shouldFocusContent) { oldValue, newValue in
            if newValue {
                isContentFocused = true
                appModel.shouldFocusContent = false
            }
        }
    }

    private func removeTag(_ tag: Tag) {
        if let index = entry.tags.firstIndex(of: tag) {
            entry.tags.remove(at: index)
        }
    }
}
