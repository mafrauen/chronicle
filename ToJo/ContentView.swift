//
//  ContentView.swift
//  ToJo
//
//  Created by Michael Frauenholtz on 3/24/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Entry.createdAt, order: .reverse) private var allEntries: [Entry]
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var selectedEntry: Entry?
    @State private var firstFilteredEntry: Entry?

    private var pinnedEntry: Entry? {
        allEntries.first(where: { $0.isPinned })
    }

    var body: some View {
        HSplitView {
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

            if appModel.showPinnedPane, let pinned = pinnedEntry {
                PinnedPaneView(entry: pinned)
                    .frame(minWidth: 250, idealWidth: 300)
            }
        }
        .onChange(of: appModel.newEntryTrigger) { oldValue, newValue in
            createNewEntry()
        }
        .onChange(of: appModel.focusTagFieldTrigger) { oldValue, newValue in
            appModel.shouldFocusTagField = true
        }
        .onChange(of: appModel.searchTrigger) { oldValue, newValue in
            appModel.shouldFocusSearch = true
        }
        .onChange(of: appModel.pendingSelectTitle) { oldValue, newValue in
            guard let title = newValue else { return }
            if let existing = allEntries.first(where: { $0.title == title }) {
                selectedEntry = existing
            } else {
                let newEntry = Entry(title: title)
                modelContext.insert(newEntry)
                if let tagName = appModel.pendingSelectTag {
                    let tag = allTags.first(where: { $0.name == tagName }) ?? Tag(name: tagName)
                    if tag.modelContext == nil {
                        modelContext.insert(tag)
                    }
                    newEntry.tags.append(tag)
                }
                selectedEntry = newEntry
            }
            appModel.pendingSelectTitle = nil
            appModel.pendingSelectTag = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appModel.shouldFocusContent = true
            }
        }
    }

    private func createNewEntry() {
        let title = appModel.pendingEntryTitle ?? "New Entry"
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
