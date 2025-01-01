//
//  LiveKirtanIntent.swift
//  Runner
//
//  Created by Harkirat Singh on 1/1/2025.
//


import AppIntents
import intelligence

struct LiveKirtanIntent: AppIntent {
  static var title: LocalizedStringResource = "Start Kirtan"
  static var openAppWhenRun: Bool = true
  
  @MainActor
  func perform() async throws -> some IntentResult {
    IntelligencePlugin.notifier.push("live_kirtan")
    return .result()
  }
}

