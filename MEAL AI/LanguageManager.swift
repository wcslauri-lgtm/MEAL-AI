//
//  AppLanguage.swift
//  MEAL AI
//
//  Created by Lauri Laitinen on 23.8.2025.
//


import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case fi = "fi"
    case en = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fi: return "Suomi"
        case .en: return "English"
        }
    }
}

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    @AppStorage("appLanguage") var appLanguageRaw: String = AppLanguage.fi.rawValue {
        didSet { objectWillChange.send() }
    }

    var current: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fi
    }

    /// Palauttaa bundlen valitulle kielelle.
    private func bundleForCurrentLanguage() -> Bundle {
        let langCode = current.rawValue
        guard
            let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }

    /// Käännösapu – hakee `Localizable.strings`-avaimen nykyisestä kielibundlesta.
    func tr(_ key: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: bundleForCurrentLanguage(), value: key, comment: "")
    }

    /// Yksinkertainen apu interpolointiin
    func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = tr(key)
        return String(format: format, arguments: args)
    }
}

/// Globaalit apu-funktiot
func L(_ key: String) -> String { LanguageManager.shared.tr(key) }
func L(_ key: String, _ args: CVarArg...) -> String { LanguageManager.shared.tr(key, args) }
