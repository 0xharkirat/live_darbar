//
//  AppShortcuts.swift
//  Runner
//
//  Created by Harkirat Singh on 1/1/2025.
//


import AppIntents
import intelligence

struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        return [
            // Mukhwak Intent Shortcut
            AppShortcut(
                intent: MukhwakIntent(),
                phrases: [
                    "\(.applicationName) mukhwak",
                ]
            ),
            
            // Live Kirtan Intent Shortcut
            AppShortcut(
                intent: LiveKirtanIntent(),
                phrases: [
                    "\(.applicationName) kirtan",
                    "Open \(.applicationName)"
                ]
            ),
            
            // Katha Intent Shortcut
            AppShortcut(
                intent: KathaIntent(),
                phrases: [
                   
                    "\(.applicationName) katha",
                    
                    
                ]
            )
        ]
    }
}

