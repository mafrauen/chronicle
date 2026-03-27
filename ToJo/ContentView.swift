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
    @Binding var showPinnedPane: Bool
    @Binding var focusTagFieldTrigger: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Entry.createdAt, order: .reverse) private var allEntries: [Entry]
    
    @State private var selectedEntry: Entry?
    @State private var shouldFocusTitle = false
    @State private var shouldFocusTagField = false
    
    private var pinnedEntry: Entry? {
        allEntries.first(where: { $0.isPinned })
    }
    
    var body: some View {
        HSplitView {
            NavigationSplitView {
                EntryListView(
                    entries: allEntries,
                    selectedEntry: $selectedEntry,
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
                        },
                        shouldFocusTitle: $shouldFocusTitle,
                        shouldFocusTagField: $shouldFocusTagField
                    )
                } else if let firstEntry = allEntries.first {
                    EntryDetailView(
                        entry: firstEntry, 
                        onPin: {
                            pinEntry(firstEntry)
                        },
                        shouldFocusTitle: $shouldFocusTitle,
                        shouldFocusTagField: $shouldFocusTagField
                    )
                } else {
                    ContentUnavailableView(
                        "No Entries",
                        systemImage: "book.closed",
                        description: Text("Create your first entry to get started")
                    )
                }
            }
            
            if showPinnedPane, let pinned = pinnedEntry {
                PinnedPaneView(entry: pinned)
                    .frame(minWidth: 250, idealWidth: 300)
            }
        }
        .onChange(of: newEntryTrigger) { oldValue, newValue in
            createNewEntry()
        }
        .onChange(of: focusTagFieldTrigger) { oldValue, newValue in
            shouldFocusTagField = true
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
    
    private func deleteEntry(_ entry: Entry) {
        if selectedEntry == entry {
            selectedEntry = nil
        }
        modelContext.delete(entry)
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
    let onDelete: (Entry) -> Void
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var entryToDelete: Entry?
    
    var body: some View {
        ScrollViewReader { proxy in
    
            List(selection: $selectedEntry) {
                // Pinned entry section
                if let pinnedEntry = entries.first(where: { $0.isPinned }) {
                    Section {
                        NavigationLink(value: pinnedEntry) {
                            EntryRowView(entry: pinnedEntry)
                        }
                        .contextMenu {
                            entryContextMenu(for: pinnedEntry)
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
                        .contextMenu {
                            entryContextMenu(for: entry)
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
            .confirmationDialog(
                "Delete Entry",
                isPresented: Binding(
                    get: { entryToDelete != nil },
                    set: { if !$0 { entryToDelete = nil } }
                ),
                presenting: entryToDelete
            ) { entry in
                Button("Delete \"\(entry.title.isEmpty ? "Untitled" : entry.title)\"", role: .destructive) {
                    onDelete(entry)
                }
            } message: { entry in
                Text("Are you sure you want to delete this entry? This cannot be undone.")
            }
        }
    }
    
    @ViewBuilder
    private func entryContextMenu(for entry: Entry) -> some View {
        Button {
            onPin(entry)
        } label: {
            Label(entry.isPinned ? "Unpin" : "Pin", systemImage: entry.isPinned ? "pin.slash" : "pin")
        }
        
        Divider()
        
        Button(role: .destructive) {
            entryToDelete = entry
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private var unpinnedEntries: [Entry] {
        entries.filter { !$0.isPinned }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        for index in offsets {
            entryToDelete = unpinnedEntries[index]
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
    @Binding var shouldFocusTagField: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    @State private var showingTagPicker = false
    @State private var inlineTagName: String = ""
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isTagFieldFocused: Bool
    
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
                .padding()
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
                    
                    inlineTagInput
                    
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
        .onChange(of: shouldFocusTitle) { oldValue, newValue in
            if newValue {
                isTitleFocused = true
                shouldFocusTitle = false
            }
        }
        .onChange(of: shouldFocusTagField) { oldValue, newValue in
            if newValue {
                isTagFieldFocused = true
                shouldFocusTagField = false
            }
        }
    }
    
    private var inlineTagInput: some View {
        TextField("Add tag…", text: $inlineTagName)
            .textFieldStyle(.plain)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(width: 90)
            .focused($isTagFieldFocused)
            .onSubmit {
                addInlineTag()
            }
    }
    
    private func addInlineTag() {
        let name = inlineTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        // Find existing tag or create new one
        if let existing = allTags.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            if !entry.tags.contains(existing) {
                entry.tags.append(existing)
            }
        } else {
            let newTag = Tag(name: name)
            modelContext.insert(newTag)
            entry.tags.append(newTag)
        }
        inlineTagName = ""
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
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tags")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            List {
                if !allTags.isEmpty {
                    Section {
                        ForEach(allTags) { tag in
                            TagPickerRow(tag: tag, isAdded: entry.tags.contains(tag)) {
                                if entry.tags.contains(tag) {
                                    removeTag(tag)
                                } else {
                                    addTag(tag)
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
                            .onSubmit {
                                createAndAddTag()
                            }
                        Button("Create") {
                            createAndAddTag()
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Create New Tag")
                }
            }
        }
        .frame(width: 350, height: 400)
    }
    
    private func removeTag(_ tag: Tag) {
        if let index = entry.tags.firstIndex(of: tag) {
            entry.tags.remove(at: index)
        }
    }
    
    private func addTag(_ tag: Tag) {
        if !entry.tags.contains(tag) {
            entry.tags.append(tag)
        }
    }
    
    private func createAndAddTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let newTag = Tag(name: name)
        modelContext.insert(newTag)
        entry.tags.append(newTag)
        newTagName = ""
    }
}

// MARK: - Tag Picker Row

struct TagPickerRow: View {
    @Bindable var tag: Tag
    let isAdded: Bool
    let onToggle: () -> Void
    
    @State private var tagColor: Color
    
    init(tag: Tag, isAdded: Bool, onToggle: @escaping () -> Void) {
        self.tag = tag
        self.isAdded = isAdded
        self.onToggle = onToggle
        if let hex = tag.colorHex, let color = Color(hex: hex) {
            self._tagColor = State(initialValue: color)
        } else {
            self._tagColor = State(initialValue: .blue)
        }
    }
    
    var body: some View {
        HStack {
            Button {
                onToggle()
            } label: {
                HStack {
                    TagBadge(tag: tag)
                    Spacer()
                    if isAdded {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .buttonStyle(.plain)
            
            ColorPicker("", selection: $tagColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 24)
                .onChange(of: tagColor) { _, newColor in
                    tag.colorHex = newColor.hexString
                }
        }
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
        .padding(.vertical, 2)
        .background(tagColor.opacity(0.2))
        .foregroundStyle(tagColor)
        .clipShape(Capsule())
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
    
    var hexString: String? {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

// MARK: - Pinned Pane View

struct PinnedPaneView: View {
    @Bindable var entry: Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.blue)
                Text(entry.title.isEmpty ? "Untitled" : entry.title)
                    .font(.headline)
                Spacer()
            }
            .padding()
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
    ContentView(newEntryTrigger: .constant(false), showPinnedPane: .constant(false), focusTagFieldTrigger: .constant(false))
        .modelContainer(for: [Entry.self, Tag.self], inMemory: true)
}
