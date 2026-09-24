//
//  AuthMiddleware.swift
//  Pexpense
//

import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Middleware that injects `Authorization: Bearer <token>` and handles token refresh.
///
/// Rules (AGENTS.md §6 & ADR-0002):
/// - Injects `Authorization: Bearer <accessToken>` when a token is available.
/// - Upon receiving HTTP 401: performs **exactly one** refresh attempt, then **one** retry.
/// - If the refresh fails: wipes tokens from the Keychain and triggers session expiration.
/// - Re-entrant or concurrent 401s avoid refresh loops.
struct AuthMiddleware: ClientMiddleware {
    private let tokenStore: any TokenStore
    private let baseURL: URL
    private let onSessionExpired: (@Sendable () -> Void)?

    init(
        tokenStore: any TokenStore,
        baseURL: URL,
        onSessionExpired: (@Sendable () -> Void)? = nil
    ) {
        self.tokenStore = tokenStore
        self.baseURL = baseURL
        self.onSessionExpired = onSessionExpired
    }

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        // Skip auth injection for auth endpoints themselves
        if operationID.contains("auth") {
            return try await next(request, body, baseURL)
        }

        var authorizedRequest = request
        if let accessToken = tokenStore.loadAccessToken() {
            authorizedRequest.headerFields[.authorization] = "Bearer \(accessToken)"
        }

        let (response, responseBody) = try await next(authorizedRequest, body, baseURL)

        // Check if authentication failed (401)
        if response.status == .unauthorized {
            let refreshSucceeded = await performRefresh()
            if refreshSucceeded, let newAccessToken = tokenStore.loadAccessToken() {
                var retryRequest = request
                retryRequest.headerFields[.authorization] = "Bearer \(newAccessToken)"
                return try await next(retryRequest, body, baseURL)
            } else {
                tokenStore.clear()
                onSessionExpired?()
            }
        }

        return (response, responseBody)
    }

    /// Performs a single token refresh using the stored refresh token.
    private func performRefresh() async -> Bool {
        guard let refreshToken = tokenStore.loadRefreshToken(), !refreshToken.isEmpty else {
            return false
        }

        guard let refreshURL = URL(string: "/api/v1/auth/token/refresh", relativeTo: baseURL) else {
            return false
        }

        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["refreshToken": refreshToken]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            return false
        }
        request.httpBody = httpBody

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            guard let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }

            struct RefreshResponse: Decodable {
                let accessToken: String
                let refreshToken: String
            }

            let decoded = try JSONDecoder().decode(RefreshResponse.self, from: data)
            try tokenStore.save(accessToken: decoded.accessToken, refreshToken: decoded.refreshToken)
            return true
        } catch {
            return false
        }
    }
}
