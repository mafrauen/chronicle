//
//  ToJoApp.swift
//  ToJo
//
//  Created by Michael Frauenholtz on 3/24/26.
//

import SwiftUI
import SwiftData
import Observation

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showWindow = Self("showWindow", default: .init(.t, modifiers: [.command, .shift]))
}

@main
struct ToJoApp: App {
    @AppStorage("globalHotkey") private var globalHotkey: String = "command+shift+t"
    @State private var newEntryTrigger = false
    
    @State private var appState = AppState()

    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Entry.self,
            Tag.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(newEntryTrigger: $newEntryTrigger)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Entry") {
                    newEntryTrigger.toggle()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

@MainActor
@Observable
final class AppState {
    init() {
        KeyboardShortcuts.onKeyDown(for: .showWindow) { [self] in
            NSApp.activate(ignoringOtherApps: true)
//            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
