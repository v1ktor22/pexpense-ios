//
//  AuthCooldownTests.swift
//  PexpenseTests
//

import Foundation
import Testing
@testable import Pexpense

/// Mock AuthenticationService that records calls and returns a scripted result.
final class MockAuthService: AuthenticationService, @unchecked Sendable {
    var otpResult: RequestOTPResult = .sent
    var otpError: Error?
    var requestOTPCallCount = 0

    func requestOTP(email: String) async throws -> RequestOTPResult {
        requestOTPCallCount += 1
        if let otpError { throw otpError }
        return otpResult
    }

    func verifyOTP(email: String, code: String) async throws -> Components.Schemas.TokenPair {
        .init(accessToken: "a", refreshToken: "r", expiresIn: 1200, tokenType: .Bearer)
    }

    func logout() async throws {}
}

@Suite("AuthCooldownTests")
struct AuthCooldownTests {

    /// The regression this guards: the countdown used to start only on the 429, so after a
    /// successful send the resend button stayed tappable and the user lost a tap to an error.
    @Test("Cooldown starts on a SUCCESSFUL send, not only on the 429")
    @MainActor
    func cooldownStartsOnSuccessfulSend() async {
        let service = MockAuthService()
        service.otpResult = .sent

        let viewModel = AuthViewModel(authService: service, onSuccess: {})
        viewModel.email = "user@pexpense.ch"

        #expect(viewModel.cooldownRemaining == 0)

        await viewModel.submitEmail()

        #expect(viewModel.currentStep == .enterCode)
        #expect(viewModel.cooldownRemaining == AuthViewModel.resendCooldownSeconds)
        #expect(viewModel.cooldownRemaining == 60)
    }

    /// The 429 stays as a safety net: when the client has no state (app restarted, second
    /// device), the server's remaining time is the only source of truth.
    @Test("429 RESEND_COOLDOWN still starts the countdown with the server's value")
    @MainActor
    func cooldownStartsOnServerCooldown() async {
        let service = MockAuthService()
        service.otpResult = .cooldown(seconds: 45)

        let viewModel = AuthViewModel(authService: service, onSuccess: {})
        viewModel.email = "user@pexpense.ch"

        await viewModel.submitEmail()

        #expect(viewModel.currentStep == .enterCode)
        #expect(viewModel.cooldownRemaining == 45)
    }

    /// While the countdown is active the resend action must be a no-op, so a double tap
    /// cannot burn a second code (the server only honours the most recent one).
    @Test("Resend is a no-op while the cooldown is active")
    @MainActor
    func resendIsBlockedDuringCooldown() async {
        let service = MockAuthService()
        service.otpResult = .sent

        let viewModel = AuthViewModel(authService: service, onSuccess: {})
        viewModel.email = "user@pexpense.ch"

        await viewModel.submitEmail()
        #expect(service.requestOTPCallCount == 1)
        #expect(viewModel.cooldownRemaining > 0)

        await viewModel.resendCode()

        #expect(service.requestOTPCallCount == 1, "resend must not fire while the cooldown is active")
    }

    @Test("A failed send does not start the countdown")
    @MainActor
    func failedSendDoesNotStartCooldown() async {
        let service = MockAuthService()
        service.otpError = AppApiError(code: "VALIDATION_ERROR", message: "Données invalides")

        let viewModel = AuthViewModel(authService: service, onSuccess: {})
        viewModel.email = "user@pexpense.ch"

        await viewModel.submitEmail()

        #expect(viewModel.cooldownRemaining == 0)
        #expect(viewModel.errorMessage != nil)
    }
}
