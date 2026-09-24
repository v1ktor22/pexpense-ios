//
//  AppEnvironment.swift
//  Pexpense
//

import Foundation
import Observation
import OpenAPIURLSession

private final class ClientHolder: @unchecked Sendable {
    var onSessionExpired: (@MainActor () -> Void)?
}

/// Central dependency container and app state provider.
///
/// Configured according to AGENTS.md §7 (MVVM + @Observable + protocol injection).
@Observable
@MainActor
final class AppEnvironment {
    let baseURL: URL
    let tokenStore: any TokenStore
    let authService: any AuthenticationService
    let expenseService: any ExpenseServiceProtocol

    var isAuthenticated: Bool

    init(
        baseURL: URL = AppConfiguration.apiBaseURL,
        tokenStore: any TokenStore = KeychainService.shared
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.isAuthenticated = tokenStore.loadAccessToken() != nil

        let clientHolder = ClientHolder()

        let authMiddleware = AuthMiddleware(tokenStore: tokenStore, baseURL: baseURL) { [weak clientHolder] in
            Task { @MainActor in
                clientHolder?.onSessionExpired?()
            }
        }

        let client = Client(
            serverURL: baseURL,
            transport: URLSessionTransport(),
            middlewares: [authMiddleware]
        )

        self.authService = RemoteAuthService(client: client, tokenStore: tokenStore)
        self.expenseService = RemoteExpenseService(client: client)

        clientHolder.onSessionExpired = { [weak self] in
            self?.isAuthenticated = false
        }
    }

    /// Sign out the current device and clear credentials.
    func logout() async {
        try? await authService.logout()
        tokenStore.clear()
        isAuthenticated = false
    }

    /// Mark user as authenticated once token exchange completes.
    func handleLoginSuccess() {
        isAuthenticated = true
    }
}
