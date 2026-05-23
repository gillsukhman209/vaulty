//
//  VaultTheme.swift
//  Vaulty
//
//  Created by Sukhman Singh on 5/23/26.
//

import SwiftUI

enum VaultAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum VaultTheme {
    static let appearanceKey = "vaultAppearance"

    static let accent = Color(hex: 0x1E8BFF)
    static let accentDeep = Color(hex: 0x145CFF)
    static let secure = Color(hex: 0x18C29C)

    static let background = Color.dynamic(light: 0xFAFBFD, dark: 0x08111D)
    static let elevatedBackground = Color.dynamic(light: 0xFFFFFF, dark: 0x111C2B)
    static let secondaryBackground = Color.dynamic(light: 0xEEF2F7, dark: 0x172436)
    static let border = Color.dynamic(light: 0xE0E7EF, dark: 0x26364B)
    static let primaryText = Color.dynamic(light: 0x111827, dark: 0xF8FAFC)
    static let secondaryText = Color.dynamic(light: 0x667085, dark: 0xA7B3C5)

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, secure],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [background, secondaryBackground.opacity(0.82)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(UIColor { traitCollection in
            let hex = traitCollection.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
