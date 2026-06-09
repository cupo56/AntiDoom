//  Theme.swift
//  AntiDoom design system — single source of truth for colors, type, spacing.
//  Visual concept: docs/superpowers/specs/2026-06-10-visuelles-konzept-design.md

import SwiftUI

enum Theme {

    enum Colors {
        static let canvas   = dynamic(light: 0xF4F2EC, dark: 0x141815)
        static let surface  = dynamic(light: 0xFBFAF6, dark: 0x1F2522)
        static let border   = dynamic(light: 0xE8E6DD, dark: 0x2B322E)
        static let ink      = dynamic(light: 0x1D2A30, dark: 0xE9E7DF)
        static let inkMuted = dynamic(light: 0x8A948F, dark: 0x888F88)
        static let accent   = dynamic(light: 0x7E9B82, dark: 0x8FB093)
        static let onAccent = Color.white

        private static func dynamic(light: UInt, dark: UInt) -> Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(rgb: dark)
                    : UIColor(rgb: light)
            })
        }
    }

    enum Spacing {
        static let xs: CGFloat = 6
        static let s: CGFloat = 12
        static let m: CGFloat = 20
        static let l: CGFloat = 30
    }

    enum Radius {
        static let card: CGFloat = 16
        static let button: CGFloat = 14
    }

    enum Fonts {
        static func display(_ size: CGFloat) -> Font {
            .system(size: size, weight: .semibold, design: .serif)
        }
        static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight)
        }
        static func label() -> Font {
            .system(size: 11, weight: .semibold)
        }
    }
}

private extension UIColor {
    convenience init(rgb: UInt) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
