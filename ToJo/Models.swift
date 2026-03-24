//
//  Models.swift
//  ToJo
//
//  Created by Michael Frauenholtz on 3/24/26.
//

import Foundation
import SwiftData

// MARK: - Weekly Goal

/// Represents a week's goals and TODO items as free-form text.
/// Each week gets a fresh entry, and previous weeks become journal entries.
@Model
final class WeeklyGoal {
    /// The start date of the week (typically Monday)
    var weekStartDate: Date
    
    /// Free-form text containing the week's goals and TODOs
    var goalText: String
    
    /// When this goal entry was created
    var createdAt: Date
    
    /// When this goal entry was last modified
    var lastModifiedAt: Date
    
    init(weekStartDate: Date, goalText: String = "") {
        self.weekStartDate = weekStartDate
        self.goalText = goalText
        self.createdAt = Date()
        self.lastModifiedAt = Date()
    }
    
    /// Returns the start of the week for a given date
    static func startOfWeek(for date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
}

// MARK: - Achievement

/// Represents a completed task, accomplishment, or achievement.
/// These are dated entries that can be tagged for later filtering.
@Model
final class Achievement {
    /// The title or brief description of the achievement
    var title: String
    
    /// Optional detailed notes about the achievement
    var notes: String
    
    /// When this achievement occurred or was completed
    var completedAt: Date
    
    /// When this entry was created (may differ from completedAt if added retroactively)
    var createdAt: Date
    
    /// Tags associated with this achievement for filtering
    @Relationship(deleteRule: .nullify, inverse: \Tag.achievements)
    var tags: [Tag]
    
    init(title: String, notes: String = "", completedAt: Date = Date()) {
        self.title = title
        self.notes = notes
        self.completedAt = completedAt
        self.createdAt = Date()
        self.tags = []
    }
}

// MARK: - Tag

/// Represents a tag for categorizing achievements.
/// Used for filtering during performance reviews or retrospectives.
@Model
final class Tag {
    /// The name of the tag (e.g., "shipped", "bug-fix", "feature")
    @Attribute(.unique) var name: String
    
    /// Optional color for visual distinction (stored as hex string)
    var colorHex: String?
    
    /// Achievements associated with this tag
    @Relationship(deleteRule: .nullify)
    var achievements: [Achievement]
    
    /// When this tag was created
    var createdAt: Date
    
    init(name: String, colorHex: String? = nil) {
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
        self.achievements = []
    }
}
