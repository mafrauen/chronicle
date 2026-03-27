//
//  ToJoApp.swift
//  ToJo
//
//  Created by Michael Frauenholtz on 3/24/26.
//

import SwiftUI
import SwiftData

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showWindow = Self("showWindow", default: .init(.j, modifiers: [.command, .shift]))
}

@main
struct ToJoApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @State private var newEntryTrigger = false
    @State private var showPinnedPane = false
    @State private var focusTagFieldTrigger = false
    @State private var searchTrigger = false

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
            ContentView(newEntryTrigger: $newEntryTrigger, showPinnedPane: $showPinnedPane, focusTagFieldTrigger: $focusTagFieldTrigger, searchTrigger: $searchTrigger)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Entry") {
                    newEntryTrigger.toggle()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Add Tag") {
                    focusTagFieldTrigger.toggle()
                }
                .keyboardShortcut("t", modifiers: .command)
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle Pinned Pane") {
                    showPinnedPane.toggle()
                }
                .keyboardShortcut("d", modifiers: .command)
            }
            
            CommandGroup(after: .textEditing) {
                Button("Find Entries") {
                    searchTrigger.toggle()
                }
                .keyboardShortcut("f", modifiers: .command)
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
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Global hotkeys (work even when app is not active / window is closed)
        KeyboardShortcuts.onKeyDown(for: .showWindow) {
            AppDelegate.showMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AppDelegate.showMainWindow()
        }
        return true
    }

    static func showMainWindow() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
