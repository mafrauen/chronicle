//
//  ContentView.swift
//  ToJo
//
//  Created by Michael Frauenholtz on 3/24/26.
//

import SwiftUI
import SwiftData


struct ContentView: View {
    @Binding var newEntryTrigger: Bool
    @Binding var showPinnedPane: Bool
    @Binding var focusTagFieldTrigger: Bool
    @Binding var searchTrigger: Bool
    @Binding var pendingEntryTitle: String?
    @Binding var pendingEntryContent: String?
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Entry.createdAt, order: .reverse) private var allEntries: [Entry]
    
    @State private var selectedEntry: Entry?
    @State private var shouldFocusTitle = false
    @State private var shouldFocusTagField = false
    @State private var shouldFocusSearch = false
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
                    shouldFocusSearch: $shouldFocusSearch,
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
                        },
                        shouldFocusTitle: $shouldFocusTitle,
                        shouldFocusTagField: $shouldFocusTagField
                    )
                } else if let fallbackEntry = firstFilteredEntry ?? pinnedEntry ?? allEntries.first {
                    EntryDetailView(
                        entry: fallbackEntry, 
                        onPin: {
                            pinEntry(fallbackEntry)
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
        .onChange(of: searchTrigger) { oldValue, newValue in
            shouldFocusSearch = true
        }
    }
    
    private func createNewEntry() {
        let title = pendingEntryTitle ?? "New Entry"
        let content = pendingEntryContent ?? ""
        let newEntry = Entry(title: title, content: content)
        modelContext.insert(newEntry)
        selectedEntry = newEntry
        pendingEntryTitle = nil
        pendingEntryContent = nil
        
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

enum DateFilter: String, CaseIterable, Identifiable {
    case all = "All Time"
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case last6Months = "Last 6 Months"
    
    var id: String { rawValue }
    
    var date: Date? {
        let calendar = Calendar.current
        switch self {
        case .all: return nil
        case .last7Days: return calendar.date(byAdding: .day, value: -7, to: .now)
        case .last30Days: return calendar.date(byAdding: .day, value: -30, to: .now)
        case .last6Months: return calendar.date(byAdding: .month, value: -6, to: .now)
        }
    }
}

struct EntryListView: View {
    let entries: [Entry]
    @Binding var selectedEntry: Entry?
    @Binding var shouldFocusSearch: Bool
    @Binding var firstFilteredEntry: Entry?
    let onPin: (Entry) -> Void
    let onNewEntry: () -> Void
    let onDelete: (Entry) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    @State private var entryToDelete: Entry?
    @State private var searchText: String = ""
    @State private var isSearchPresented = false
    @State private var selectedTags: Set<PersistentIdentifier> = []
    @State private var excludedTags: Set<PersistentIdentifier> = []
    @State private var dateFilter: DateFilter = .all
    @State private var showFilters = false
    
    var body: some View {
        ScrollViewReader { proxy in
    
            List(selection: $selectedEntry) {
                // Filter controls
                if showFilters {
                    Section {
                        // Date filter
                        Picker("Date", selection: $dateFilter) {
                            ForEach(DateFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        // Include tags filter
                        if !availableTagsForInclude.isEmpty || !selectedTags.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                if !availableTagsForInclude.isEmpty {
                                    Picker("Include Tag", selection: Binding<PersistentIdentifier?>(
                                        get: { nil },
                                        set: { id in
                                            if let id { selectedTags.insert(id) }
                                        }
                                    )) {
                                        Text("Include tag…").tag(nil as PersistentIdentifier?)
                                        ForEach(availableTagsForInclude) { tag in
                                            Text(tag.name).tag(tag.persistentModelID as PersistentIdentifier?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                ForEach(includedTagObjects) { tag in
                                    HStack {
                                        TagBadge(tag: tag)
                                        Spacer()
                                        Button {
                                            selectedTags.remove(tag.persistentModelID)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        // Exclude tags filter
                        if !availableTagsForExclude.isEmpty || !excludedTags.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                if !availableTagsForExclude.isEmpty {
                                    Picker("Exclude Tag", selection: Binding<PersistentIdentifier?>(
                                        get: { nil },
                                        set: { id in
                                            if let id { excludedTags.insert(id) }
                                        }
                                    )) {
                                        Text("Exclude tag…").tag(nil as PersistentIdentifier?)
                                        ForEach(availableTagsForExclude) { tag in
                                            Text(tag.name).tag(tag.persistentModelID as PersistentIdentifier?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                ForEach(excludedTagObjects) { tag in
                                    HStack {
                                        TagBadge(tag: tag)
                                        Spacer()
                                        Button {
                                            excludedTags.remove(tag.persistentModelID)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        if !selectedTags.isEmpty || !excludedTags.isEmpty || dateFilter != .all {
                            Button("Clear Filters") {
                                selectedTags.removeAll()
                                excludedTags.removeAll()
                                dateFilter = .all
                            }
                            .font(.caption)
                        }
                    } header: {
                        Text("Filters")
                    }
                }
                
                // Pinned entry section
                if let pinnedEntry = filteredPinnedEntry {
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
                
                // Filtered entries
                Section {
                    ForEach(filteredUnpinnedEntries) { entry in
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
            .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Filter entries")
            .onChange(of: shouldFocusSearch) { oldValue, newValue in
                if newValue {
                    if isSearchPresented {
                        isSearchPresented = false
                        DispatchQueue.main.async {
                            isSearchPresented = true
                        }
                    } else {
                        isSearchPresented = true
                    }
                    shouldFocusSearch = false
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                if !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    selectedEntry = nil
                }
                updateFirstFilteredEntry()
            }
            .onChange(of: selectedTags) { _, _ in
                updateFirstFilteredEntry()
            }
            .onChange(of: excludedTags) { _, _ in
                updateFirstFilteredEntry()
            }
            .onChange(of: dateFilter) { _, _ in
                updateFirstFilteredEntry()
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
                ToolbarItem(placement: .automatic) {
                    Button {
                        withAnimation {
                            showFilters.toggle()
                        }
                    } label: {
                        Label("Filters", systemImage: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .help("Toggle filters")
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
    
    private var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty ||
        !selectedTags.isEmpty ||
        !excludedTags.isEmpty ||
        dateFilter != .all
    }
    
    private var filteredPinnedEntry: Entry? {
        guard let pinnedEntry = entries.first(where: { $0.isPinned }) else { return nil }
        
        // If not filtering, always show pinned
        if !isFiltering { return pinnedEntry }
        
        // Text search
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            let matchesText = pinnedEntry.title.localizedCaseInsensitiveContains(query) ||
                pinnedEntry.content.localizedCaseInsensitiveContains(query) ||
                pinnedEntry.tags.contains { $0.name.localizedCaseInsensitiveContains(query) }
            if !matchesText { return nil }
        }
        
        // Include tag filter
        if !selectedTags.isEmpty {
            let matchesTags = pinnedEntry.tags.contains { selectedTags.contains($0.persistentModelID) }
            if !matchesTags { return nil }
        }
        
        // Exclude tag filter
        if !excludedTags.isEmpty {
            let hasExcluded = pinnedEntry.tags.contains { excludedTags.contains($0.persistentModelID) }
            if hasExcluded { return nil }
        }
        
        // Date filter
        if let cutoff = dateFilter.date {
            if pinnedEntry.createdAt < cutoff { return nil }
        }
        
        return pinnedEntry
    }
    
    private var availableTagsForInclude: [Tag] {
        allTags.filter { !selectedTags.contains($0.persistentModelID) && !excludedTags.contains($0.persistentModelID) }
    }
    
    private var availableTagsForExclude: [Tag] {
        allTags.filter { !excludedTags.contains($0.persistentModelID) && !selectedTags.contains($0.persistentModelID) }
    }
    
    private var includedTagObjects: [Tag] {
        allTags.filter { selectedTags.contains($0.persistentModelID) }
    }
    
    private var excludedTagObjects: [Tag] {
        allTags.filter { excludedTags.contains($0.persistentModelID) }
    }
    
    private var unpinnedEntries: [Entry] {
        entries.filter { !$0.isPinned }
    }
    
    private var filteredUnpinnedEntries: [Entry] {
        var result = unpinnedEntries
        
        // Text search
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            result = result.filter { entry in
                entry.title.localizedCaseInsensitiveContains(query) ||
                entry.content.localizedCaseInsensitiveContains(query) ||
                entry.tags.contains { $0.name.localizedCaseInsensitiveContains(query) }
            }
        }
        
        // Include tag filter (OR: entry must have at least one of the selected tags)
        if !selectedTags.isEmpty {
            result = result.filter { entry in
                entry.tags.contains { selectedTags.contains($0.persistentModelID) }
            }
        }
        
        // Exclude tag filter (entry must NOT have any of the excluded tags)
        if !excludedTags.isEmpty {
            result = result.filter { entry in
                !entry.tags.contains { excludedTags.contains($0.persistentModelID) }
            }
        }
        
        // Date filter
        if let cutoff = dateFilter.date {
            result = result.filter { $0.createdAt >= cutoff }
        }
        
        return result
    }
    
    private func deleteEntries(offsets: IndexSet) {
        for index in offsets {
            entryToDelete = filteredUnpinnedEntries[index]
        }
    }
    
    private func updateFirstFilteredEntry() {
        if isFiltering {
            firstFilteredEntry = filteredPinnedEntry ?? filteredUnpinnedEntries.first
        } else {
            firstFilteredEntry = nil
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
        .onChange(of: shouldFocusTitle) { oldValue, newValue in
            if newValue {
                isTitleFocused = true
                shouldFocusTitle = false
            }
        }
        .onChange(of: shouldFocusTagField) { oldValue, newValue in
            if newValue {
                showingTagPicker = true
                shouldFocusTagField = false
            }
        }
    }
    
    private func removeTag(_ tag: Tag) {
        if let index = entry.tags.firstIndex(of: tag) {
            entry.tags.remove(at: index)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }
        
        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Tag Picker View

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
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search tags…", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        handleSubmit()
                    }
                
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
            
            // Tag list
            List {
                ForEach(filteredTags) { tag in
                    TagPickerRow(tag: tag, isAdded: entry.tags.contains(tag)) {
                        if entry.tags.contains(tag) {
                            removeTag(tag)
                        } else {
                            addTag(tag)
                        }
                    } onDelete: {
                        deleteTag(tag)
                    }
                }
                
                // "Create" row when search text doesn't match an existing tag
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
        .frame(width: 320, height: 350)
        .onAppear {
            isSearchFocused = true
        }
    }
    
    private func handleSubmit() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        
        if let first = filteredTags.first {
            // Pick the top filtered result
            if !entry.tags.contains(first) {
                addTag(first)
            }
        } else {
            // No matches — create a new tag
            createAndAddTag()
        }
        searchText = ""
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
        let name = searchText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let newTag = Tag(name: name)
        modelContext.insert(newTag)
        entry.tags.append(newTag)
        searchText = ""
    }
    
    private func deleteTag(_ tag: Tag) {
        // Remove from this entry first
        if let index = entry.tags.firstIndex(of: tag) {
            entry.tags.remove(at: index)
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
    ContentView(newEntryTrigger: .constant(false), showPinnedPane: .constant(false), focusTagFieldTrigger: .constant(false), searchTrigger: .constant(false), pendingEntryTitle: .constant(nil), pendingEntryContent: .constant(nil))
        .modelContainer(for: [Entry.self, Tag.self], inMemory: true)
}
