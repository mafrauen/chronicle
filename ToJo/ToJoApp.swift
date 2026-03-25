//
//  ToJoApp.swift
//  ToJo
//
//  Created by Michael Frauenholtz on 3/24/26.
//

import SwiftUI
import SwiftData

@main
struct ToJoApp: App {
    @AppStorage("globalHotkey") private var globalHotkey: String = "command+shift+t"
    @State private var newEntryTrigger = false
    
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
                .onAppear {
                    // Set up global hotkey listener
                    setupGlobalHotkey()
                }
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
    
    private func setupGlobalHotkey() {
        // TODO: Implement global hotkey registration
        // This would require Carbon or other APIs to register system-wide shortcuts
    }
}
