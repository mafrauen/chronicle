//
//  ContentView.swift
//  ToJo
//
//  Created by Michael Frauenholtz on 3/24/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            Text("Select a view")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    var body: some View {
        List {
            Section("This Week") {
                NavigationLink {
                    CurrentWeekView()
                } label: {
                    Label("Weekly Goals", systemImage: "list.bullet.clipboard")
                }
            }
            
            Section("Achievements") {
                NavigationLink {
                    AchievementsListView()
                } label: {
                    Label("All Achievements", systemImage: "star.fill")
                }
                
                NavigationLink {
                    TagsManagementView()
                } label: {
                    Label("Manage Tags", systemImage: "tag.fill")
                }
            }
            
            Section("Journal") {
                NavigationLink {
                    WeeklyGoalsArchiveView()
                } label: {
                    Label("Past Weeks", systemImage: "book.fill")
                }
            }
        }
        .navigationTitle("ToJo")
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
#endif
    }
}

// MARK: - Current Week View

struct CurrentWeekView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var weeklyGoals: [WeeklyGoal]
    
    @State private var currentWeekGoal: WeeklyGoal?
    @State private var goalText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Week of \(weekStartDate, format: .dateTime.month().day().year())")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            TextEditor(text: $goalText)
                .font(.body)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: goalText) { oldValue, newValue in
                    saveGoalText()
                }
        }
        .padding()
        .navigationTitle("Weekly Goals")
        .onAppear {
            loadCurrentWeekGoal()
        }
    }
    
    private var weekStartDate: Date {
        WeeklyGoal.startOfWeek()
    }
    
    private func loadCurrentWeekGoal() {
        let startDate = weekStartDate
        
        // Find existing goal for this week
        if let existing = weeklyGoals.first(where: { Calendar.current.isDate($0.weekStartDate, equalTo: startDate, toGranularity: .day) }) {
            currentWeekGoal = existing
            goalText = existing.goalText
        } else {
            // Create new goal for this week
            let newGoal = WeeklyGoal(weekStartDate: startDate)
            modelContext.insert(newGoal)
            currentWeekGoal = newGoal
            goalText = ""
        }
    }
    
    private func saveGoalText() {
        guard let goal = currentWeekGoal else { return }
        goal.goalText = goalText
        goal.lastModifiedAt = Date()
    }
}

// MARK: - Achievements List View

struct AchievementsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Achievement.completedAt, order: .reverse) private var achievements: [Achievement]
    
    @State private var showingAddAchievement = false
    
    var body: some View {
        List {
            ForEach(achievements) { achievement in
                NavigationLink {
                    AchievementDetailView(achievement: achievement)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(achievement.title)
                            .font(.headline)
                        
                        HStack {
                            Text(achievement.completedAt, format: .dateTime.month().day().year())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if !achievement.tags.isEmpty {
                                ForEach(achievement.tags) { tag in
                                    TagBadge(tag: tag)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteAchievements)
        }
        .navigationTitle("Achievements")
        .toolbar {
            ToolbarItem {
                Button {
                    showingAddAchievement = true
                } label: {
                    Label("Add Achievement", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddAchievement) {
            AddAchievementView()
        }
    }
    
    private func deleteAchievements(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(achievements[index])
        }
    }
}

// MARK: - Achievement Detail View

struct AchievementDetailView: View {
    @Bindable var achievement: Achievement
    
    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $achievement.title)
                DatePicker("Completed", selection: $achievement.completedAt, displayedComponents: .date)
            }
            
            Section("Notes") {
                TextEditor(text: $achievement.notes)
                    .frame(minHeight: 100)
            }
            
            Section("Tags") {
                // TODO: Tag selection UI
                ForEach(achievement.tags) { tag in
                    Text(tag.name)
                }
            }
        }
        .navigationTitle("Achievement")
    }
}

// MARK: - Add Achievement View

struct AddAchievementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var completedAt: Date = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                DatePicker("Completed", selection: $completedAt, displayedComponents: .date)
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("New Achievement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAchievement()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func addAchievement() {
        let achievement = Achievement(title: title, notes: notes, completedAt: completedAt)
        modelContext.insert(achievement)
        dismiss()
    }
}

// MARK: - Tags Management View

struct TagsManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    
    @State private var showingAddTag = false
    
    var body: some View {
        List {
            ForEach(tags) { tag in
                HStack {
                    TagBadge(tag: tag)
                    Spacer()
                    Text("\(tag.achievements.count) achievements")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: deleteTags)
        }
        .navigationTitle("Tags")
        .toolbar {
            ToolbarItem {
                Button {
                    showingAddTag = true
                } label: {
                    Label("Add Tag", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTag) {
            AddTagView()
        }
    }
    
    private func deleteTags(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tags[index])
        }
    }
}

// MARK: - Add Tag View

struct AddTagView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var tagName: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Tag Name", text: $tagName)
//                    .textInputAutocapitalization(.never)
            }
            .navigationTitle("New Tag")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTag()
                    }
                    .disabled(tagName.isEmpty)
                }
            }
        }
    }
    
    private func addTag() {
        let tag = Tag(name: tagName)
        modelContext.insert(tag)
        dismiss()
    }
}

// MARK: - Weekly Goals Archive View

struct WeeklyGoalsArchiveView: View {
    @Environment(\.dateService) private var dateService
    @Query(sort: \WeeklyGoal.weekStartDate, order: .reverse) private var allWeeklyGoals: [WeeklyGoal]
    
    var body: some View {
        List {
            ForEach(pastWeekGoals) { goal in
                NavigationLink {
                    WeeklyGoalDetailView(goal: goal)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Week of \(goal.weekStartDate, format: .dateTime.month().day().year())")
                            .font(.headline)
                        
                        if !goal.goalText.isEmpty {
                            Text(goal.goalText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        } else {
                            Text("No goals recorded")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .italic()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Past Weeks")
    }
    
    /// Filter out the current week's goals
    private var pastWeekGoals: [WeeklyGoal] {
        let currentWeekStart = WeeklyGoal.startOfWeek(for: dateService.now)
        return allWeeklyGoals.filter { goal in
            !Calendar.current.isDate(goal.weekStartDate, equalTo: currentWeekStart, toGranularity: .day)
        }
    }
}

// MARK: - Weekly Goal Detail View

struct WeeklyGoalDetailView: View {
    let goal: WeeklyGoal
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Week of \(goal.weekStartDate, format: .dateTime.month().day().year())")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                if goal.goalText.isEmpty {
                    Text("No goals recorded for this week")
                        .foregroundStyle(.tertiary)
                        .italic()
                } else {
                    Text(goal.goalText)
                }
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Weekly Goal")
    }
}

// MARK: - Helper Views

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

#Preview {
    ContentView()
        .modelContainer(for: [WeeklyGoal.self, Achievement.self, Tag.self], inMemory: true)
}

