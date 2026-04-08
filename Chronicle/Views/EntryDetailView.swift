//
//  EntryDetailView.swift
//  Chronicle
//

import SwiftUI
import SwiftData
#if canImport(AppKit)
private let controlBG = Color(nsColor: .controlBackgroundColor)
#else
private let controlBG = Color(uiColor: .systemBackground)
#endif

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
            TextField("Entry Title", text: Binding(
                get: { entry.title },
                set: { entry.title = $0; entry.lastModifiedAt = Date() }
            ))
                .font(.title2)
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .padding()
                .background(controlBG)

            Divider()

            TextEditor(text: Binding(
                get: { entry.content },
                set: { entry.content = $0; entry.lastModifiedAt = Date() }
            ))
                .font(.body)
                .focused($isContentFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(controlBG)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button {
                        showingTagPicker = true
                    } label: {
                        Image(systemName: "tag")
                            #if os(iOS)
                            .font(.body)
                            .padding(10)
                            .contentShape(Rectangle())
                            #else
                            .font(.caption)
                            #endif
                    }
                    .buttonStyle(.borderless)
                    .help("Browse all tags")
                    .popover(isPresented: $showingTagPicker, arrowEdge: .top) {
                        TagPickerView(entry: entry, allTags: allTags)
                    }

                    if !entry.tagList.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(entry.tagList) { tag in
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
            .background(controlBG)
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
        .onAppear {
            if appModel.shouldFocusTitle {
                isTitleFocused = true
                appModel.shouldFocusTitle = false
            } else {
                #if os(macOS)
                isContentFocused = true
                #endif
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
        if let index = entry.tags?.firstIndex(of: tag) {
            entry.tags?.remove(at: index)
        }
    }
}
