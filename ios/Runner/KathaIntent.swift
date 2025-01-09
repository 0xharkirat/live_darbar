//
//  KathaIntent.swift
//  Runner
//
//  Created by Harkirat Singh on 1/1/2025.
//


import AppIntents
import intelligence

struct KathaIntent: AppIntent {
  static var title: LocalizedStringResource = "Start Katha"
  static var openAppWhenRun: Bool = true
  
  @MainActor
  func perform() async throws -> some IntentResult {
    IntelligencePlugin.notifier.push("mukhwak_katha")
    return .result()
  }
}


