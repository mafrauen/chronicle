//
//  ChronicleApp.swift
//  Chronicle
//
//  Created by Michael Frauenholtz on 3/24/26.
//

import SwiftUI
import SwiftData


extension Notification.Name {
    static let chronicleURLReceived = Notification.Name("chronicleURLReceived")
}

@main
struct ChronicleApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    #endif

    @State private var appModel = AppModel()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Entry.self,
            Tag.self,
        ])
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .private("iCloud.com.frauenholtz.Chronicle"))
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(appModel)
                .onReceive(NotificationCenter.default.publisher(for: .chronicleURLReceived)) { notification in
                    if let url = notification.object as? URL {
                        handleURL(url)
                    }
                }
                .handlesExternalEvents(preferring: ["chronicle"], allowing: ["*"])
        }
        .handlesExternalEvents(matching: ["chronicle"])
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Entry") {
                    appModel.newEntryTrigger.toggle()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Add Tag") {
                    appModel.focusTagFieldTrigger.toggle()
                }
                .keyboardShortcut("t", modifiers: .command)
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle Pinned Pane") {
                    appModel.showPinnedPane.toggle()
                }
                .keyboardShortcut("d", modifiers: .command)
            }

            CommandGroup(after: .textEditing) {
                Button("Find Entries") {
                    appModel.searchTrigger.toggle()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .importExport) {
                Button("Export Entries…") {
                    appModel.exportTrigger.toggle()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            MainWindowCommands()
        }
        #endif
    }

    private func handleURL(_ url: URL) {
        #if os(macOS)
        AppDelegate.showMainWindow()
        #endif

        guard url.scheme == "chronicle" else { return }
        let action = url.host(percentEncoded: false) ?? ""

        switch action {
        case "new":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []
            appModel.pendingEntryTitle = queryItems.first(where: { $0.name == "title" })?.value
            appModel.pendingEntryContent = queryItems.first(where: { $0.name == "content" })?.value
            appModel.newEntryTrigger.toggle()
        case "entry":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []
            appModel.pendingSelectTag = queryItems.first(where: { $0.name == "tag" })?.value
            if let title = queryItems.first(where: { $0.name == "title" })?.value {
                appModel.pendingSelectTitle = title
            }
        case "open":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []
            if queryItems.contains(where: { $0.name == "pinned" }) {
                appModel.pendingSelectPinned = true
            }
        default:
            break
        }
    }
}

#if os(macOS)
struct MainWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .windowList) {
            Button("Show Main Window") {
                if let window = NSApp.windows.first(where: { $0.canBecomeKey && ($0.isVisible || $0.isMiniaturized) }) {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate()
                } else {
                    openWindow(id: "main")
                }
            }
            .keyboardShortcut("0", modifiers: .command)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            AppDelegate.showMainWindow()
            NotificationCenter.default.post(name: .chronicleURLReceived, object: url)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate()
            if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}
#endif

