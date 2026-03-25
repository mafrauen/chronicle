//
//  ContentView.swift
//  ToJo
//
//  Created by Michael Frauenholtz on 3/24/26.
//

import SwiftUI
import SwiftData

import KeyboardShortcuts

struct ContentView: View {
    @Binding var newEntryTrigger: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Entry.createdAt, order: .reverse) private var allEntries: [Entry]
    
    @State private var selectedEntry: Entry?
    @State private var shouldFocusTitle = false
    
    var body: some View {
        NavigationSplitView {
            EntryListView(
                entries: allEntries,
                selectedEntry: $selectedEntry,
                onPin: pinEntry,
                onNewEntry: createNewEntry
            )
        } detail: {
            if let entry = selectedEntry {
                EntryDetailView(
                    entry: entry, 
                    onPin: {
                        pinEntry(entry)
                    },
                    shouldFocusTitle: $shouldFocusTitle
                )
            } else if let firstEntry = allEntries.first {
                EntryDetailView(
                    entry: firstEntry, 
                    onPin: {
                        pinEntry(firstEntry)
                    },
                    shouldFocusTitle: $shouldFocusTitle
                )
            } else {
                ContentUnavailableView(
                    "No Entries",
                    systemImage: "book.closed",
                    description: Text("Create your first entry to get started")
                )
            }
        }
        .onChange(of: newEntryTrigger) { oldValue, newValue in
            createNewEntry()
        }
        .onGlobalKeyboardShortcut(.showWindow) {_ in 
            showPinnedEntry()
        }
    }
    
    private func createNewEntry() {
        let newEntry = Entry(title: "New Entry")
        modelContext.insert(newEntry)
        selectedEntry = newEntry
        
        // Trigger focus on title field
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            shouldFocusTitle = true
        }
    }
    
    private func pinEntry(_ entry: Entry) {
        // Unpin all other entries
        for existingEntry in allEntries {
            if existingEntry != entry {
                existingEntry.isPinned = false
            }
        }
        // Pin this entry
        entry.isPinned = true
    }
    
    private func showPinnedEntry() {
        selectedEntry = allEntries.first(where: { $0.isPinned })
    }
}

// MARK: - Entry List View

struct EntryListView: View {
    let entries: [Entry]
    @Binding var selectedEntry: Entry?
    let onPin: (Entry) -> Void
    let onNewEntry: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ScrollViewReader { proxy in
    
            List(selection: $selectedEntry) {
                // Pinned entry section
                if let pinnedEntry = entries.first(where: { $0.isPinned }) {
                    Section {
                        NavigationLink(value: pinnedEntry) {
                            EntryRowView(entry: pinnedEntry)
                        }
                    } header: {
                        Label("Pinned", systemImage: "pin.fill")
                    }
                }
                
                // All entries in chronological order
                Section {
                    ForEach(unpinnedEntries) { entry in
                        NavigationLink(value: entry) {
                            EntryRowView(entry: entry)
                        }
                    }
                    .onDelete(perform: deleteEntries)
                } header: {
                    Text("Entries")
                }
            }
            .navigationTitle("ToJo")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onNewEntry()
                    } label: {
                        Label("New Entry", systemImage: "plus")
                    }
                }
            }
            .onGlobalKeyboardShortcut(.showWindow) {_ in
                withAnimation{
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
    }
    
    private var unpinnedEntries: [Entry] {
        entries.filter { !$0.isPinned }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        for index in offsets {
            let entry = unpinnedEntries[index]
            modelContext.delete(entry)
        }
    }
}

// MARK: - Entry Row View

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
                
                if !entry.tags.isEmpty {
                    ForEach(entry.tags) { tag in
                        TagBadge(tag: tag)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Entry Detail View

struct EntryDetailView: View {
    @Bindable var entry: Entry
    let onPin: () -> Void
    @Binding var shouldFocusTitle: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    @State private var showingTagPicker = false
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Title field
            TextField("Entry Title", text: $entry.title)
                .font(.title2)
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Content editor
            TextEditor(text: $entry.content)
                .font(.body)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal)
                .onChange(of: entry.content) { oldValue, newValue in
                    entry.lastModifiedAt = Date()
                }
                .onChange(of: entry.title) { oldValue, newValue in
                    entry.lastModifiedAt = Date()
                }
            
            Divider()
            
            // Tags and metadata
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if !entry.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(entry.tags) { tag in
                                    TagBadge(tag: tag)
                                        .overlay(alignment: .topTrailing) {
                                            Button {
                                                removeTag(tag)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                            .offset(x: 4, y: -4)
                                        }
                                }
                            }
                        }
                    }
                    
                    Button {
                        showingTagPicker = true
                    } label: {
                        Label("Add Tag", systemImage: "tag")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                
                HStack {
                    Text("Created: \(entry.createdAt, format: .dateTime.month().day().year())")
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
        .sheet(isPresented: $showingTagPicker) {
            TagPickerView(entry: entry, allTags: allTags)
        }
        .onChange(of: shouldFocusTitle) { oldValue, newValue in
            if newValue {
                isTitleFocused = true
                shouldFocusTitle = false
            }
        }
    }
    
    private func removeTag(_ tag: Tag) {
        if let index = entry.tags.firstIndex(of: tag) {
            entry.tags.remove(at: index)
        }
    }
}

// MARK: - Tag Picker View

struct TagPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let entry: Entry
    let allTags: [Tag]
    
    @State private var newTagName: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                if !availableTags.isEmpty {
                    Section {
                        ForEach(availableTags) { tag in
                            Button {
                                addTag(tag)
                            } label: {
                                HStack {
                                    TagBadge(tag: tag)
                                    Spacer()
                                }
                            }
                        }
                    } header: {
                        Text("Available Tags")
                    }
                }
                
                Section {
                    HStack {
                        TextField("New tag name", text: $newTagName)
                        Button("Create") {
                            createAndAddTag()
                        }
                        .disabled(newTagName.isEmpty)
                    }
                } header: {
                    Text("Create New Tag")
                }
            }
            .navigationTitle("Add Tags")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private var availableTags: [Tag] {
        allTags.filter { tag in
            !entry.tags.contains(tag)
        }
    }
    
    private func addTag(_ tag: Tag) {
        if !entry.tags.contains(tag) {
            entry.tags.append(tag)
        }
        dismiss()
    }
    
    private func createAndAddTag() {
        let newTag = Tag(name: newTagName)
        modelContext.insert(newTag)
        entry.tags.append(newTag)
        newTagName = ""
        dismiss()
    }
}

// MARK: - Tag Badge

struct TagBadge: View {
    let tag: Tag
    
    var body: some View {
        Text(tag.name)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(tagColor.opacity(0.2))
            .foregroundStyle(tagColor)
            .clipShape(Capsule())
    }
    
    private var tagColor: Color {
        if let hex = tag.colorHex {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Global Hotkey to Show Window")
                        .font(.headline)
                    
                    KeyboardShortcuts.Recorder(for: .showWindow)
                    
                    Text("Press your desired key combination to set the global hotkey")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Keyboard Shortcuts")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This global hotkey will bring the ToJo window to the front from anywhere.")
                    Text("⌘N creates a new entry when the app is focused.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Section {
                LabeledContent("App Version", value: "1.0.0")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 300)
    }
}


#Preview {
    ContentView(newEntryTrigger: .constant(false))
        .modelContainer(for: [Entry.self, Tag.self], inMemory: true)
}
