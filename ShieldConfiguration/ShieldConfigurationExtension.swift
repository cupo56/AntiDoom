//  ShieldConfigurationExtension.swift
//  Gebrandetes, gestuftes Reflexions-Schild ("Ruhig & Minimal"). Stage und
//  Prompt kommen aus dem ReflectionStore; keine Seiteneffekte hier.

import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }
    override func configuration(
        shielding application: Application, in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration()
    }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }
    override func configuration(
        shielding webDomain: WebDomain, in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let stageZero = ReflectionStore.effectiveStage == 0
        let title = stageZero ? "Kurz innehalten" : "Atme dreimal tief durch"
        let subtitle = stageZero
            ? ReflectionStore.currentPrompt
            : "Langsam ein … und wieder aus. Wenn du bereit bist, geht es weiter."
        let primary = stageZero ? "Durchatmen" : "Ich bin bereit"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThinMaterial,
            backgroundColor: ShieldPalette.canvas,
            icon: ShieldPalette.ringIcon(),
            title: ShieldConfiguration.Label(text: title, color: ShieldPalette.ink),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: ShieldPalette.inkMuted),
            primaryButtonLabel: ShieldConfiguration.Label(text: primary, color: ShieldPalette.onAccent),
            primaryButtonBackgroundColor: ShieldPalette.accent,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Beenden", color: ShieldPalette.ink)
        )
    }
}

/// Spiegelt Theme.Colors (das SwiftUI-Design-System ist hier nicht importierbar).
/// Werte aus AntiDoom/DesignSystem/Theme.swift.
private enum ShieldPalette {
    static let canvas   = brand(light: 0xF4F2EC, dark: 0x141815)
    static let ink      = brand(light: 0x1D2A30, dark: 0xE9E7DF)
    static let inkMuted = brand(light: 0x8A948F, dark: 0x888F88)
    static let accent   = brand(light: 0x7E9B82, dark: 0x8FB093)
    static let onAccent = UIColor.white

    static func brand(light: UInt, dark: UInt) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        }
    }

    /// Statisches BreathingRing-Motiv: zwei konzentrische Sage-Kreise.
    static func ringIcon() -> UIImage {
        let size = CGSize(width: 80, height: 80)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let sage = accent.resolvedColor(with: UITraitCollection.current)
            sage.setStroke()
            let outer = CGRect(x: 8, y: 8, width: 64, height: 64)
            let p1 = UIBezierPath(ovalIn: outer); p1.lineWidth = 4; p1.stroke()
            let p2 = UIBezierPath(ovalIn: outer.insetBy(dx: 14, dy: 14)); p2.lineWidth = 3; p2.stroke()
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
