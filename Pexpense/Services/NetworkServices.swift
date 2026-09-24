//
//  NetworkServices.swift
//  Pexpense
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import UIKit

/// Concrete network implementation of AuthenticationService using OpenAPI Client.
final class RemoteAuthService: AuthenticationService, Sendable {
    private let client: Client
    private let tokenStore: any TokenStore

    init(client: Client, tokenStore: any TokenStore) {
        self.client = client
        self.tokenStore = tokenStore
    }

    func requestOTP(email: String) async throws -> RequestOTPResult {
        let input = Operations.post_sol_api_sol_v1_sol_auth_sol_otp.Input(
            body: .json(.init(email: email))
        )
        let response = try await client.post_sol_api_sol_v1_sol_auth_sol_otp(input)

        switch response {
        case .ok:
            return .sent
        case .badRequest(let badRequest):
            let errorBody = try badRequest.body.json
            throw AppApiError(code: errorBody.code, message: errorBody.error, field: errorBody.field, rule: errorBody.rule)
        case .tooManyRequests(let rateLimited):
            let errorBody = try rateLimited.body.json
            if errorBody.code == "RESEND_COOLDOWN" {
                return .cooldown(seconds: 60)
            }
            throw AppApiError(code: errorBody.code, message: errorBody.error, field: errorBody.field, rule: errorBody.rule)
        case .undocumented(let statusCode, _):
            throw AppApiError(code: "HTTP_\(statusCode)", message: "Unexpected server response (\(statusCode)).")
        }
    }

    func verifyOTP(email: String, code: String) async throws -> Components.Schemas.TokenPair {
        let deviceName = await UIDevice.current.name
        let input = Operations.post_sol_api_sol_v1_sol_auth_sol_token.Input(
            body: .json(.init(
                email: email,
                otp: code,
                deviceName: deviceName,
                platform: "iOS"
            ))
        )
        let response = try await client.post_sol_api_sol_v1_sol_auth_sol_token(input)

        switch response {
        case .created(let created):
            let pair = try created.body.json
            try tokenStore.save(accessToken: pair.accessToken, refreshToken: pair.refreshToken)
            return pair
        case .badRequest(let badRequest):
            let errorBody = try badRequest.body.json
            throw AppApiError(code: errorBody.code, message: errorBody.error, field: errorBody.field, rule: errorBody.rule)
        case .tooManyRequests(let tooMany):
            let errorBody = try tooMany.body.json
            throw AppApiError(code: errorBody.code, message: errorBody.error, field: errorBody.field, rule: errorBody.rule)
        case .undocumented(let statusCode, _):
            throw AppApiError(code: "HTTP_\(statusCode)", message: "Authentication failed (\(statusCode)).")
        }
    }

    func logout() async throws {
        if let refreshToken = tokenStore.loadRefreshToken() {
            let input = Operations.post_sol_api_sol_v1_sol_auth_sol_token_sol_revoke.Input(
                body: .json(.init(refreshToken: refreshToken))
            )
            _ = try? await client.post_sol_api_sol_v1_sol_auth_sol_token_sol_revoke(input)
        }
        tokenStore.clear()
    }
}

/// Concrete network implementation of ExpenseServiceProtocol using OpenAPI Client.
final class RemoteExpenseService: ExpenseServiceProtocol, Sendable {
    private let client: Client

    init(client: Client) {
        self.client = client
    }

    func fetchExpenses(limit: Int?) async throws -> Components.Schemas.ExpenseList {
        let limitString = limit.map(String.init)
        let input = Operations.get_sol_api_sol_v1_sol_expenses.Input(
            query: .init(limit: limitString)
        )
        let response = try await client.get_sol_api_sol_v1_sol_expenses(input)

        switch response {
        case .ok(let ok):
            return try ok.body.json
        case .unauthorized(let unauthorized):
            let errorBody = try unauthorized.body.json
            throw AppApiError(code: errorBody.code, message: errorBody.error, field: errorBody.field, rule: errorBody.rule)
        case .undocumented(let statusCode, _):
            throw AppApiError(code: "HTTP_\(statusCode)", message: "Failed to load expenses (\(statusCode)).")
        }
    }
}
