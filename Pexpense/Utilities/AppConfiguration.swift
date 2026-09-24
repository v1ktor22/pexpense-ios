//
//  AppConfiguration.swift
//  Pexpense
//

import Foundation

/// Application configuration loaded from environment or bundle metadata.
///
/// In local development, the base URL points to `https://devpexpense.local`.
/// In release/staging, it can be customized via `Local.xcconfig` or `Info.plist`.
enum AppConfiguration {
    /// Default development URL if not explicitly configured.
    private static let defaultBaseURL = URL(string: "https://devpexpense.local")!

    /// Base URL for the Pexpense backend API.
    static var apiBaseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "ApiBaseURL") as? String,
           let url = URL(string: raw),
           !raw.isEmpty && !raw.contains("$(") {
            return url
        }
        return defaultBaseURL
    }
}
