//
//  ExpenseListViewModel.swift
//  Pexpense
//

import Foundation
import Observation

/// ViewModel managing the expense list retrieval and state.
@Observable
@MainActor
final class ExpenseListViewModel {
    let expenseService: any ExpenseServiceProtocol

    var expenses: [Components.Schemas.ExpenseList.expensesPayloadPayload] = []
    var summary: Components.Schemas.ExpenseList.summaryPayload? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil

    init(expenseService: any ExpenseServiceProtocol) {
        self.expenseService = expenseService
    }

    /// Load expenses list and summary from the backend.
    func loadExpenses() async {
        isLoading = true
        errorMessage = nil

        do {
            let list = try await expenseService.fetchExpenses(limit: 100)
            self.expenses = list.expenses
            self.summary = list.summary
            self.isLoading = false
        } catch let apiError as AppApiError {
            self.isLoading = false
            self.errorMessage = apiError.message
        } catch {
            self.isLoading = false
            self.errorMessage = "Unable to load expenses. Please check your connection."
        }
    }
}
