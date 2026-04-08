//
//  EntryListView.swift
//  Chronicle
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum DateFilter: String, CaseIterable, Identifiable {
    case all = "All Time"
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case last6Months = "Last 6 Months"
    case custom = "Custom Date"

    var id: String { rawValue }

    var presetDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .all: return nil
        case .last7Days: return calendar.date(byAdding: .day, value: -7, to: .now)
        case .last30Days: return calendar.date(byAdding: .day, value: -30, to: .now)
        case .last6Months: return calendar.date(byAdding: .month, value: -6, to: .now)
        case .custom: return nil
        }
    }
}

struct EntryListView: View {
    @Environment(AppModel.self) private var appModel
    let entries: [Entry]
    @Binding var selectedEntry: Entry?
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
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var customEndDate: Date = .now
    @State private var showFilters = false
    @State private var showExporter = false
    @State private var exportDocument: ExportDocument = ExportDocument()

    var body: some View {
        ScrollViewReader { proxy in
            entryList
        }
    }

    private var entryList: some View {
        List(selection: $selectedEntry) {
            if showFilters { filterSection }
            if let pinnedEntry = filteredPinnedEntry { pinnedSection(pinnedEntry) }
            unpinnedSection
        }
        .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Filter entries")
        .onChange(of: appModel.shouldFocusSearch) { _, newValue in
            guard newValue else { return }
            if isSearchPresented {
                isSearchPresented = false
                DispatchQueue.main.async { isSearchPresented = true }
            } else {
                isSearchPresented = true
            }
            appModel.shouldFocusSearch = false
        }
        .onChange(of: searchText) { _, newValue in
            if !newValue.trimmingCharacters(in: .whitespaces).isEmpty { selectedEntry = nil }
            updateFirstFilteredEntry()
        }
        .onChange(of: selectedTags) { _, _ in updateFirstFilteredEntry() }
        .onChange(of: excludedTags) { _, _ in updateFirstFilteredEntry() }
        .onChange(of: dateFilter) { _, _ in updateFirstFilteredEntry() }
        .onChange(of: customStartDate) { _, _ in updateFirstFilteredEntry() }
        .onChange(of: customEndDate) { _, _ in updateFirstFilteredEntry() }
        .onChange(of: appModel.exportTrigger) { _, _ in exportFilteredEntries() }
        #if os(iOS)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        #else
        .navigationTitle("Chronicle")
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { onNewEntry() } label: { Label("New Entry", systemImage: "plus") }
            }
            ToolbarItem(placement: .automatic) {
                Button { withAnimation { showFilters.toggle() } } label: {
                    Label("Filters", systemImage: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .help("Toggle filters")
            }
            #if os(iOS)
            ToolbarItem(placement: .automatic) {
                Button { exportFilteredEntries() } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(allFilteredEntries.isEmpty)
            }
            #endif
        }
        .confirmationDialog(
            "Delete Entry",
            isPresented: Binding(get: { entryToDelete != nil }, set: { if !$0 { entryToDelete = nil } }),
            presenting: entryToDelete
        ) { entry in
            Button("Delete \"\(entry.title.isEmpty ? "Untitled" : entry.title)\"", role: .destructive) { onDelete(entry) }
        } message: { entry in
            Text("Are you sure you want to delete this entry? This cannot be undone.")
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentTypes: [.json, .commaSeparatedText, .plainText],
            defaultFilename: "Chronicle Export"
        ) { _ in }
    }

    @ViewBuilder
    private func pinnedSection(_ pinnedEntry: Entry) -> some View {
        Section {
            NavigationLink(value: pinnedEntry) { EntryRowView(entry: pinnedEntry) }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { onDelete(pinnedEntry) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu { entryContextMenu(for: pinnedEntry) }
        } header: {
            Text("Pinned")
        }
    }

    private var unpinnedSection: some View {
        Section {
            ForEach(filteredUnpinnedEntries) { entry in
                NavigationLink(value: entry) { EntryRowView(entry: entry) }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { onDelete(entry) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu { entryContextMenu(for: entry) }
            }
        } header: {
            Text("Entries")
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

    // MARK: - Filter Section

    @ViewBuilder
    private var filterSection: some View {
        Section {
            Picker("Date", selection: $dateFilter) {
                ForEach(DateFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.menu)

            if dateFilter == .custom {
                DatePicker(
                    "From",
                    selection: $customStartDate,
                    in: ...customEndDate,
                    displayedComponents: .date
                )
                DatePicker(
                    "To",
                    selection: $customEndDate,
                    in: customStartDate...Date.now,
                    displayedComponents: .date
                )
            }

            if !availableTagsForInclude.isEmpty || !selectedTags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    if !availableTagsForInclude.isEmpty {
                        Picker("Include Tag", selection: Binding<PersistentIdentifier?>(
                            get: { nil },
                            set: { id in if let id { selectedTags.insert(id) } }
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
                            Button { selectedTags.remove(tag.persistentModelID) } label: {
                                Image(systemName: "xmark").font(.caption2).foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !availableTagsForExclude.isEmpty || !excludedTags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    if !availableTagsForExclude.isEmpty {
                        Picker("Exclude Tag", selection: Binding<PersistentIdentifier?>(
                            get: { nil },
                            set: { id in if let id { excludedTags.insert(id) } }
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
                            Button { excludedTags.remove(tag.persistentModelID) } label: {
                                Image(systemName: "xmark").font(.caption2).foregroundStyle(.secondary)
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
                    customStartDate = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
                    customEndDate = .now
                }
                .font(.caption)
            }
        } header: {
            Text("Filters")
        }
    }

    // MARK: - Filtering

    private var effectiveCutoffDate: Date? {
        dateFilter == .custom ? customStartDate : dateFilter.presetDate
    }

    private var effectiveEndDate: Date? {
        guard dateFilter == .custom else { return nil }
        return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: customEndDate))
    }

    private var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty ||
        !selectedTags.isEmpty ||
        !excludedTags.isEmpty ||
        dateFilter != .all
    }

    private var filteredPinnedEntry: Entry? {
        guard let pinnedEntry = entries.first(where: { $0.isPinned }) else { return nil }
        if !isFiltering { return pinnedEntry }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            let matchesText = pinnedEntry.title.localizedCaseInsensitiveContains(query) ||
                pinnedEntry.content.localizedCaseInsensitiveContains(query) ||
                pinnedEntry.tagList.contains { $0.name.localizedCaseInsensitiveContains(query) }
            if !matchesText { return nil }
        }
        if !selectedTags.isEmpty {
            if !pinnedEntry.tagList.contains(where: { selectedTags.contains($0.persistentModelID) }) { return nil }
        }
        if !excludedTags.isEmpty {
            if pinnedEntry.tagList.contains(where: { excludedTags.contains($0.persistentModelID) }) { return nil }
        }
        if let cutoff = effectiveCutoffDate {
            if pinnedEntry.createdAt < cutoff { return nil }
        }
        if let end = effectiveEndDate {
            if pinnedEntry.createdAt >= end { return nil }
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
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            result = result.filter { entry in
                entry.title.localizedCaseInsensitiveContains(query) ||
                entry.content.localizedCaseInsensitiveContains(query) ||
                entry.tagList.contains { $0.name.localizedCaseInsensitiveContains(query) }
            }
        }
        if !selectedTags.isEmpty {
            result = result.filter { entry in
                entry.tagList.contains { selectedTags.contains($0.persistentModelID) }
            }
        }
        if !excludedTags.isEmpty {
            result = result.filter { entry in
                !entry.tagList.contains { excludedTags.contains($0.persistentModelID) }
            }
        }
        if let cutoff = effectiveCutoffDate {
            result = result.filter { $0.createdAt >= cutoff }
        }
        if let end = effectiveEndDate {
            result = result.filter { $0.createdAt < end }
        }
        return result
    }

    private var allFilteredEntries: [Entry] {
        var result: [Entry] = []
        if let pinned = filteredPinnedEntry { result.append(pinned) }
        result.append(contentsOf: filteredUnpinnedEntries)
        return result
    }

    private func updateFirstFilteredEntry() {
        firstFilteredEntry = isFiltering ? (filteredPinnedEntry ?? filteredUnpinnedEntries.first) : nil
    }

    private func exportFilteredEntries() {
        guard !allFilteredEntries.isEmpty else { return }
        exportDocument = ExportDocument(entries: allFilteredEntries)
        showExporter = true
    }
}
