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
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    @State private var newEntryTrigger = false
    @State private var showPinnedPane = false
    
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
            ContentView(newEntryTrigger: $newEntryTrigger, showPinnedPane: $showPinnedPane)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Entry") {
                    newEntryTrigger.toggle()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .sidebar) {
                Button("Toggle Pinned Pane") {
                    showPinnedPane.toggle()
                }
                .keyboardShortcut("d", modifiers: .command)
            }
            
            CommandGroup(after: .windowArrangement) {
                Button("Show Window") {
                    appDelegate.showMainWindow()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }
    
    func showMainWindow() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

@MainActor
@Observable
final class AppState {
    init() {
        KeyboardShortcuts.onKeyDown(for: .showWindow) {
            NSApp.activate()
            // Ensure the main window is visible and key
            if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}
