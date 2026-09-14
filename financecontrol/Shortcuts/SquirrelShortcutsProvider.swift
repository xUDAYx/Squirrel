//
//  SquirrelShortcutsProvider.swift
//  Squirrel
//
//  Registers Squirrel shortcuts with Siri and the Shortcuts app.
//

import AppIntents

@available(iOS 16.4, *)
struct GallaShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log expense in \(.applicationName)",
                "Add expense in \(.applicationName)",
                "Track spending in \(.applicationName)"
            ],
            shortTitle: "Log Expense",
            systemImageName: "plus.circle"
        )
    }
}
