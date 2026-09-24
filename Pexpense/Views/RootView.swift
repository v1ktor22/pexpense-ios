//
//  RootView.swift
//  Pexpense
//

import SwiftUI

/// Root view of the app switching between Authentication and Main Expense flows.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Group {
            if environment.isAuthenticated {
                ExpenseListView(
                    viewModel: ExpenseListViewModel(expenseService: environment.expenseService),
                    onLogout: {
                        Task { await environment.logout() }
                    }
                )
            } else {
                OTPLoginView(
                    viewModel: AuthViewModel(
                        authService: environment.authService,
                        onSuccess: {
                            environment.handleLoginSuccess()
                        }
                    )
                )
            }
        }
        .animation(.default, value: environment.isAuthenticated)
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment())
}
