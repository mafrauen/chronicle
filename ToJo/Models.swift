//
//  Models.swift
//  ToJo
//
//  Created by Michael Frauenholtz on 3/24/26.
//

import Foundation
import SwiftData

// MARK: - Entry

/// Represents a journal entry - can be a TODO list, accomplishment, note, or anything else.
/// One entry can be pinned at a time to serve as the "current" TODO list.
@Model
final class Entry {
    /// The title of the entry
    var title: String = ""

    /// The main content of the entry
    var content: String = ""

    /// When this entry was created
    var createdAt: Date = Date()

    /// When this entry was last modified
    var lastModifiedAt: Date = Date()

    /// Whether this entry is pinned (only one can be pinned at a time)
    var isPinned: Bool = false

    /// Tags associated with this entry
    @Relationship(deleteRule: .nullify, inverse: \Tag.entries)
    var tags: [Tag]?

    var tagList: [Tag] { tags ?? [] }

    init(title: String = "", content: String = "", createdAt: Date = Date(), isPinned: Bool = false) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.lastModifiedAt = Date()
        self.isPinned = isPinned
        self.tags = []
    }
}

// MARK: - Tag

/// Represents a tag for categorizing entries.
@Model
final class Tag {
    /// The name of the tag
    var name: String = ""

    /// Optional color for visual distinction (stored as hex string)
    var colorHex: String?

    /// Entries associated with this tag
    @Relationship(deleteRule: .nullify)
    var entries: [Entry]?

    /// When this tag was created
    var createdAt: Date = Date()

    init(name: String, colorHex: String? = nil) {
        self.name = name
        self.colorHex = colorHex
        self.entries = []
    }
}
