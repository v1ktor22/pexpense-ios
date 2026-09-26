//
//  AuthViewModel.swift
//  Pexpense
//

import Foundation
import Observation

/// ViewModel managing the two-step OTP authentication flow.
@Observable
@MainActor
final class AuthViewModel {
    /// Server-side resend window, in seconds. Mirrors the backend cooldown and the web client.
    static let resendCooldownSeconds = 60

    enum Step {
        case requestEmail
        case enterCode
    }

    private let authService: any AuthenticationService
    private let onSuccess: () -> Void

    var email: String = ""
    var otpCode: String = ""
    var currentStep: Step = .requestEmail

    var isLoading: Bool = false
    var errorMessage: String? = nil
    var cooldownRemaining: Int = 0

    private var cooldownTask: Task<Void, Never>?

    init(authService: any AuthenticationService, onSuccess: @escaping () -> Void) {
        self.authService = authService
        self.onSuccess = onSuccess
    }

    /// Step 1: Request OTP code for the entered email address.
    func submitEmail() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await authService.requestOTP(email: trimmedEmail)
            isLoading = false

            switch result {
            case .sent:
                // The send succeeded, so the server-side 60s window is now open.
                // Start the countdown here, not on the 429: the user should see
                // "resend in 60s" immediately instead of losing a tap to an error.
                startCooldown(seconds: Self.resendCooldownSeconds)
                currentStep = .enterCode
            case .cooldown(let seconds):
                // Safety net: the client lost its state (app restarted, second device),
                // so the 429 is the only source of truth for the remaining time.
                startCooldown(seconds: seconds)
                currentStep = .enterCode
            }
        } catch let apiError as AppApiError {
            isLoading = false
            errorMessage = apiError.message
        } catch {
            isLoading = false
            errorMessage = "Failed to request code. Please check your network."
        }
    }

    /// Step 2: Verify the OTP code.
    func verifyCode() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedCode.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await authService.verifyOTP(email: trimmedEmail, code: trimmedCode)
            isLoading = false
            onSuccess()
        } catch let apiError as AppApiError {
            isLoading = false
            errorMessage = apiError.message
        } catch {
            isLoading = false
            errorMessage = "Failed to verify code. Please try again."
        }
    }

    /// Resend OTP request.
    func resendCode() async {
        guard cooldownRemaining == 0 else { return }
        await submitEmail()
    }

    /// Start 60-second cooldown countdown timer.
    private func startCooldown(seconds: Int) {
        cooldownRemaining = seconds
        cooldownTask?.cancel()
        cooldownTask = Task {
            while cooldownRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                cooldownRemaining -= 1
            }
        }
    }
}
