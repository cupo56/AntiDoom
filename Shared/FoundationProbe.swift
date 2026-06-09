//  FoundationProbe.swift
//  Minimal model that exists only to prove the shared App Group store works.
//  Real domain models (sessions, rules, stats) are added in later sub-projects.

import Foundation
import SwiftData

@Model
final class FoundationProbe {
    var createdAt: Date

    init(createdAt: Date = .now) {
        self.createdAt = createdAt
    }
}
