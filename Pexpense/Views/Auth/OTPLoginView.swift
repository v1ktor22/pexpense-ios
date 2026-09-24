//
//  OTPLoginView.swift
//  Pexpense
//

import SwiftUI

/// View handling two-step OTP authentication.
///
/// Design constraints (AGENTS.md §4):
/// - Clean, minimalist UI adhering to Human Interface Guidelines.
/// - System typography with monospaced digits for timers and codes.
/// - Neutral colors for destructive/warning actions; no red on buttons.
/// - French / English only (no Portuguese strings).
struct OTPLoginView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "francsign.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    Text("Pexpense")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                    Text(viewModel.currentStep == .requestEmail
                         ? "Enter your email to receive a login code."
                         : "Enter the code sent to \(viewModel.email)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                // Error Message Banner
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)
                }

                // Input fields
                VStack(spacing: 16) {
                    if viewModel.currentStep == .requestEmail {
                        TextField("Email address", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                        Button {
                            Task { await viewModel.submitEmail() }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Send Code")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(viewModel.email.isEmpty || viewModel.isLoading)
                    } else {
                        TextField("OTP Code", text: $viewModel.otpCode)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .font(.system(.title2, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                        Button {
                            Task { await viewModel.verifyCode() }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Sign In")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(viewModel.otpCode.isEmpty || viewModel.isLoading)

                        // Cooldown / Resend Action
                        if viewModel.cooldownRemaining > 0 {
                            Text("Resend available in \(viewModel.cooldownRemaining)s")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else {
                            Button("Resend Code") {
                                Task { await viewModel.resendCode() }
                            }
                            .buttonStyle(.plain)
                            .font(.footnote)
                            .foregroundStyle(.tint)
                            .disabled(viewModel.isLoading)
                        }

                        Button("Change Email") {
                            viewModel.currentStep = .requestEmail
                            viewModel.otpCode = ""
                            viewModel.errorMessage = nil
                        }
                        .buttonStyle(.plain)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
    }
}
