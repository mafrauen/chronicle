//
//  ContentView.swift
//  Chronicle
//
//  Created by Michael Frauenholtz on 3/24/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Query(sort: \Entry.createdAt, order: .reverse) private var allEntries: [Entry]
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var selectedEntry: Entry?
    @State private var firstFilteredEntry: Entry?

    private var pinnedEntry: Entry? {
        allEntries.first(where: { $0.isPinned })
    }

    private var splitView: some View {
        NavigationSplitView {
            EntryListView(
                entries: allEntries,
                selectedEntry: $selectedEntry,
                firstFilteredEntry: $firstFilteredEntry,
                onPin: pinEntry,
                onNewEntry: createNewEntry,
                onDelete: deleteEntry
            )
        } detail: {
            if let entry = selectedEntry {
                EntryDetailView(
                    entry: entry,
                    onPin: {
                        pinEntry(entry)
                    }
                )
            } else if let fallbackEntry = firstFilteredEntry ?? pinnedEntry ?? allEntries.first {
                EntryDetailView(
                    entry: fallbackEntry,
                    onPin: {
                        pinEntry(fallbackEntry)
                    }
                )
            } else {
                ContentUnavailableView(
                    "No Entries",
                    systemImage: "book.closed",
                    description: Text("Create your first entry to get started")
                )
            }
        }
        .onChange(of: appModel.newEntryTrigger) { _, _ in
            createNewEntry()
        }
.onChange(of: appModel.focusTagFieldTrigger) { _, _ in
            appModel.shouldFocusTagField = true
        }
        .onChange(of: appModel.searchTrigger) { _, _ in
            appModel.shouldFocusSearch = true
        }
        .onChange(of: appModel.pendingSelectPinned) { _, newValue in
            guard newValue else { return }
            selectedEntry = allEntries.first(where: { $0.isPinned })
            appModel.pendingSelectPinned = false
        }
        .onChange(of: appModel.pendingSelectTitle) { _, newValue in
            guard let title = newValue else { return }
            if let existing = allEntries.first(where: { $0.title == title }) {
                selectedEntry = existing
                if let tagName = appModel.pendingSelectTag {
                    let tag = allTags.first(where: { $0.name == tagName }) ?? Tag(name: tagName)
                    if tag.modelContext == nil { modelContext.insert(tag) }
                    if !(existing.tagList.contains(tag)) { existing.tags?.append(tag) }
                }
            } else {
                let newEntry = Entry(title: title)
                modelContext.insert(newEntry)
                if let tagName = appModel.pendingSelectTag {
                    let tag = allTags.first(where: { $0.name == tagName }) ?? Tag(name: tagName)
                    if tag.modelContext == nil {
                        modelContext.insert(tag)
                    }
                    newEntry.tags?.append(tag)
                }
                selectedEntry = newEntry
            }
            appModel.pendingSelectTitle = nil
            appModel.pendingSelectTag = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appModel.shouldFocusContent = true
            }
        }
        .task {
            modelContext.undoManager = undoManager
        }
    }

    var body: some View {
        #if os(macOS)
        HSplitView {
            splitView
            if appModel.showPinnedPane, let pinned = pinnedEntry {
                PinnedPaneView(entry: pinned)
                    .frame(minWidth: 250, idealWidth: 300)
            }
        }
        #else
        splitView
        #endif
    }

    private func createNewEntry() {
        let title = appModel.pendingEntryTitle ?? ""
        let content = appModel.pendingEntryContent ?? ""
        let newEntry = Entry(title: title, content: content)
        modelContext.insert(newEntry)
        selectedEntry = newEntry
        appModel.pendingEntryTitle = nil
        appModel.pendingEntryContent = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            appModel.shouldFocusTitle = true
        }
    }

    private func pinEntry(_ entry: Entry) {
        for existingEntry in allEntries {
            if existingEntry != entry {
                existingEntry.isPinned = false
            }
        }
        entry.isPinned = true
    }

    private func deleteEntry(_ entry: Entry) {
        if selectedEntry == entry {
            selectedEntry = nil
        }
        modelContext.delete(entry)
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
        .modelContainer(for: [Entry.self, Tag.self], inMemory: true)
}
