//
//  AppModel.swift
//  ToJo
//
//  Created by Michael Frauenholtz on 3/24/26.
//

import SwiftUI

@MainActor
@Observable
final class AppModel {
    // MARK: - Entry creation
    var newEntryTrigger = false
    var pendingEntryTitle: String?
    var pendingEntryContent: String?

    // MARK: - Entry selection via URL
    var pendingSelectTitle: String?
    var pendingSelectTag: String?

    // MARK: - UI toggles
    var showPinnedPane = false
    var focusTagFieldTrigger = false
    var searchTrigger = false
    var exportTrigger = false

    // MARK: - Focus
    var shouldFocusTitle = false
    var shouldFocusTagField = false
    var shouldFocusContent = false
    var shouldFocusSearch = false
}
