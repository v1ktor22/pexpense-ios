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

    var expenses: [ExpenseDisplay] = []
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
            self.expenses = list.expenses.map(ExpenseDisplay.init)
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

    /// Deletes an expense by its ID and refreshes the list and summary.
    func deleteExpense(id: String) async {
        do {
            try await expenseService.deleteExpense(id: id)
            // Reload list and summary to reflect change
            await loadExpenses()
        } catch let apiError as AppApiError {
            self.errorMessage = apiError.message
        } catch {
            self.errorMessage = "Failed to delete expense."
        }
    }
}
