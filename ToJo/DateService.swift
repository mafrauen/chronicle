//
//  DateService.swift
//  ToJo
//
//  Created by Michael Frauenholtz on 3/24/26.
//

import Foundation
import SwiftUI

/// A service that provides the current date, allowing for overrides during testing and previews
@Observable
class DateService {
    /// The overridden date, if set. When nil, uses the actual current date.
    var overriddenDate: Date?
    
    /// Returns the current date, or the overridden date if one is set
    var now: Date {
        overriddenDate ?? Date()
    }
    
    /// Creates a date service with an optional override date
    init(overriddenDate: Date? = nil) {
        self.overriddenDate = overriddenDate
    }
}

// MARK: - Environment Key

private struct DateServiceKey: EnvironmentKey {
    static let defaultValue = DateService()
}

extension EnvironmentValues {
    var dateService: DateService {
        get { self[DateServiceKey.self] }
        set { self[DateServiceKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Sets a custom date service for this view and its children
    func dateService(_ service: DateService) -> some View {
        environment(\.dateService, service)
    }
    
    /// Convenience method to override the current date
    func overrideCurrentDate(_ date: Date) -> some View {
        environment(\.dateService, DateService(overriddenDate: date))
    }
}
