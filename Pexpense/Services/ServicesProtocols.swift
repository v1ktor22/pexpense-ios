//
//  ServicesProtocols.swift
//  Pexpense
//

import Foundation
import OpenAPIRuntime

/// Protocol abstracting authentication actions.
protocol AuthenticationService: Sendable {
    /// Requests an OTP login code sent to the specified email.
    func requestOTP(email: String) async throws -> RequestOTPResult

    /// Exchanges email and OTP code for device tokens.
    func verifyOTP(email: String, code: String) async throws -> Components.Schemas.TokenPair

    /// Revokes current device token.
    func logout() async throws
}

enum RequestOTPResult: Sendable {
    case sent
    case cooldown(seconds: Int)
}

/// Protocol abstracting expense retrieval actions.
protocol ExpenseServiceProtocol: Sendable {
    /// Fetches expenses with summary for a given period.
    func fetchExpenses(limit: Int?) async throws -> Components.Schemas.ExpenseList
}

/// High-level API error parsed from server JSON `{ code, error, field?, rule? }`.
struct AppApiError: Error, LocalizedError, Sendable {
    let code: String
    let message: String
    let field: String?
    let rule: String?

    init(code: String, message: String, field: String? = nil, rule: String? = nil) {
        self.code = code
        self.message = message
        self.field = field
        self.rule = rule
    }

    var errorDescription: String? {
        message
    }
}
