//
//  ToJoApp.swift
//  ToJo
//
//  Created by Michael Frauenholtz on 3/24/26.
//

import SwiftUI
import SwiftData


extension Notification.Name {
    static let tojoURLReceived = Notification.Name("tojoURLReceived")
}

@main
struct ToJoApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @State private var newEntryTrigger = false
    @State private var showPinnedPane = false
    @State private var focusTagFieldTrigger = false
    @State private var searchTrigger = false
    @State private var pendingEntryTitle: String?
    @State private var pendingEntryContent: String?
    @State private var pendingSelectTitle: String?
    @State private var pendingSelectTag: String?
    @State private var shouldFocusContent = false
    @State private var exportTrigger = false

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
            ContentView(
                newEntryTrigger: $newEntryTrigger,
                showPinnedPane: $showPinnedPane,
                focusTagFieldTrigger: $focusTagFieldTrigger,
                searchTrigger: $searchTrigger,
                pendingEntryTitle: $pendingEntryTitle,
                pendingEntryContent: $pendingEntryContent,
                pendingSelectTitle: $pendingSelectTitle,
                pendingSelectTag: $pendingSelectTag,
                shouldFocusContent: $shouldFocusContent,
                exportTrigger: $exportTrigger
            )
            .onReceive(NotificationCenter.default.publisher(for: .tojoURLReceived)) { notification in
                if let url = notification.object as? URL {
                    handleURL(url)
                }
            }
            .handlesExternalEvents(preferring: ["tojo"], allowing: ["*"])
        }
        .handlesExternalEvents(matching: ["tojo"])
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
            
            CommandGroup(replacing: .importExport) {
                Button("Export Entries…") {
                    exportTrigger.toggle()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
    
    private func handleURL(_ url: URL) {
        AppDelegate.showMainWindow()
        
        guard url.scheme == "tojo" else { return }
        let action = url.host(percentEncoded: false) ?? ""
        
        switch action {
        case "new":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []
            pendingEntryTitle = queryItems.first(where: { $0.name == "title" })?.value
            pendingEntryContent = queryItems.first(where: { $0.name == "content" })?.value
            newEntryTrigger.toggle()
        case "entry":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []
            pendingSelectTag = queryItems.first(where: { $0.name == "tag" })?.value
            if let title = queryItems.first(where: { $0.name == "title" })?.value {
                pendingSelectTitle = title
            }
        case "open":
            break // showMainWindow already called above
        default:
            break
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            AppDelegate.showMainWindow()
            NotificationCenter.default.post(name: .tojoURLReceived, object: url)
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AppDelegate.showMainWindow()
        }
        return true
    }

    static func showMainWindow() {
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        NSApp.activate()
        // Retry activation after a brief delay to ensure focus when called from URL schemes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate()
            if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}
