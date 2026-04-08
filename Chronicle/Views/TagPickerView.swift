//
//  TagPickerView.swift
//  Chronicle
//

import SwiftUI
import SwiftData

struct TagPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: Entry
    let allTags: [Tag]

    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredTags: [Tag] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if query.isEmpty { return allTags }
        return allTags.filter { fuzzyMatch(query: query, in: $0.name) }
    }

    private var exactMatchExists: Bool {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return allTags.contains { $0.name.caseInsensitiveCompare(query) == .orderedSame }
    }

    private var queryIsEmpty: Bool {
        searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            tagList
                .navigationTitle("Tags")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search tags…")
                .onSubmit(of: .search) { handleSubmit() }
        }
        .presentationDetents([.medium, .large])
        .onAppear { isSearchFocused = true }
        #else
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search tags…", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit { handleSubmit() }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(10)

            Divider()

            tagList
        }
        .frame(width: 320, height: 350)
        .onAppear { isSearchFocused = true }
        #endif
    }

    private var tagList: some View {
        List {
            ForEach(filteredTags) { tag in
                TagPickerRow(tag: tag, isAdded: entry.tagList.contains(tag)) {
                    if entry.tagList.contains(tag) {
                        removeTag(tag)
                    } else {
                        addTag(tag)
                    }
                } onDelete: {
                    deleteTag(tag)
                }
            }

            if !queryIsEmpty && !exactMatchExists {
                Button {
                    createAndAddTag()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                        Text("Create \"\(searchText.trimmingCharacters(in: .whitespaces))\"")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handleSubmit() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }

        if let first = filteredTags.first {
            if !entry.tagList.contains(first) {
                addTag(first)
            }
        } else {
            createAndAddTag()
        }
        searchText = ""
    }

    private func removeTag(_ tag: Tag) {
        if let index = entry.tags?.firstIndex(of: tag) {
            entry.tags?.remove(at: index)
        }
    }

    private func addTag(_ tag: Tag) {
        if !entry.tagList.contains(tag) {
            entry.tags?.append(tag)
        }
    }

    private func createAndAddTag() {
        let name = searchText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let newTag = Tag(name: name)
        modelContext.insert(newTag)
        entry.tags?.append(newTag)
        searchText = ""
    }

    private func deleteTag(_ tag: Tag) {
        if let index = entry.tags?.firstIndex(of: tag) {
            entry.tags?.remove(at: index)
        }
        modelContext.delete(tag)
    }

    /// Fuzzy match: checks if all characters of the query appear in order within the target string.
    private func fuzzyMatch(query: String, in target: String) -> Bool {
        var queryIndex = query.lowercased().startIndex
        let queryLower = query.lowercased()
        let targetLower = target.lowercased()

        for char in targetLower {
            if queryIndex < queryLower.endIndex && char == queryLower[queryIndex] {
                queryIndex = queryLower.index(after: queryIndex)
            }
        }
        return queryIndex == queryLower.endIndex
    }
}

// MARK: - Tag Picker Row

struct TagPickerRow: View {
    @Bindable var tag: Tag
    let isAdded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var tagColor: Color

    init(tag: Tag, isAdded: Bool, onToggle: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.tag = tag
        self.isAdded = isAdded
        self.onToggle = onToggle
        self.onDelete = onDelete
        if let hex = tag.colorHex, let color = Color(hex: hex) {
            self._tagColor = State(initialValue: color)
        } else {
            self._tagColor = State(initialValue: .blue)
        }
    }

    var body: some View {
        HStack {
            HStack {
                TagBadge(tag: tag)
                Spacer()
                if isAdded {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .padding(.trailing, 4)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onToggle()
            }

            ColorPicker("", selection: $tagColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 24)
                .onChange(of: tagColor) { _, newColor in
                    tag.colorHex = newColor.hexString
                }

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            .buttonStyle(.plain)
        }
    }
}
