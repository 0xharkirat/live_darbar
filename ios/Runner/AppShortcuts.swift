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
                    "Start Wak in \(.applicationName)",
                    "\(.applicationName) Ajj da Mukhwak Shuru Karo",
                    "\(.applicationName) Ajj da Hukumnama Shuru Karo",
                    "\(.applicationName) Ajj da walk shuru karo",
                    "\(.applicationName) Ajj da Hukum Shuru Karo",
                    "Start Muk walk in \(.applicationName)",
                    "Start Mukhwak in \(.applicationName)",
                    "Start Hukumnama in \(.applicationName)",
                    "Start Walk in \(.applicationName)",
                    "Start Hukum in \(.applicationName)",
                    "Start Muk Wak in \(.applicationName)",
                    "Start Mukh Walk in \(.applicationName)",
                    "Start Muk Walk in \(.applicationName)",
                    "Start Muk Wok in \(.applicationName)",
                    "Start Mukh Wok in \(.applicationName)",
                    "Start Mukwak in \(.applicationName)",
                    "Start Muk Wack in \(.applicationName)",
                    "Start Mukwhack in \(.applicationName)",
                    "Start Muk Wahk in \(.applicationName)",
                    "Start Mukh Wahk in \(.applicationName)",
                    "Start Wak in \(.applicationName)",
                    "Start Walk in \(.applicationName)",
                    "Start Wock in \(.applicationName)",
                    "Start Whack in \(.applicationName)",
                    "Start Muk Whack in \(.applicationName)",
                    "Start Mukh Whack in \(.applicationName)",
                    "Start Mukwak Today in \(.applicationName)",
                    "Start Muk Wawk in \(.applicationName)",
                    "Start Muk Vahk in \(.applicationName)",
                    "Start Muck Walk in \(.applicationName)",
                    "Start Muck Wak in \(.applicationName)",
                    "Start Muck Wack in \(.applicationName)",
                    "Start Mock Walk in \(.applicationName)",
                    "Start Mock Wak in \(.applicationName)",
                    "Start Mock Wack in \(.applicationName)",
                ]
            ),
            
            // Live Kirtan Intent Shortcut
            AppShortcut(
                intent: LiveKirtanIntent(),
                phrases: [
                    "Start Kirtan in \(.applicationName)",
                    "\(.applicationName) Kirtan Shuru Karo",
                    "Kirtan Shuru Karo",
                    "Start Kirtan",
                ]
            ),
            
            // Katha Intent Shortcut
            AppShortcut(
                intent: KathaIntent(),
                phrases: [
                    "Start Katha in \(.applicationName)",
                    "\(.applicationName) Katha Shuru Karo",
                    "Katha Shuru Karo",
                    "Start Katha",
                ]
            )
        ]
    }
}

