//
//  ExpenseListView.swift
//  Pexpense
//

import SwiftUI

/// Main expense list view for the first vertical slice.
///
/// Complies with:
/// - AGENTS.md §4: Minimalist design, system typography, monospaced values.
/// - AGENTS.md §5: Monetary amounts formatted using `CurrencyFormatter`.
/// - ADR-0004: Swiss Francs (CHF) / EUR formatting with U+0027 grouping separator.
struct ExpenseListView: View {
    var viewModel: ExpenseListViewModel
    let onLogout: () -> Void
    @State private var isShowingCreateExpense = false

    var body: some View {
        NavigationStack {
            List {
                // Summary Section
                if let summary = viewModel.summary {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Summary")
                                .font(.caption)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)

                            ForEach(summary.totalsByCurrency, id: \.currency) { totalItem in
                                HStack {
                                    Text(totalItem.currency)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    let currencyEnum = CurrencyFormatter.Currency(rawValue: totalItem.currency) ?? .chf
                                    Text(CurrencyFormatter.string(fromMinorUnits: totalItem.total, currency: currencyEnum))
                                        .font(.title3.weight(.semibold).monospacedDigit())
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Expenses Section
                Section("Recent Expenses") {
                    if viewModel.expenses.isEmpty && !viewModel.isLoading {
                        Text("No expenses found.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(viewModel.expenses, id: \.id) { expense in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(expense.description)
                                        .font(.body)
                                    HStack(spacing: 6) {
                                        if let categoryName = expense.categoryName {
                                            Text(categoryName)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.secondary.opacity(0.12), in: Capsule())
                                        }
                                        Text(expense.expenseDate)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                let currencyEnum = CurrencyFormatter.Currency(rawValue: expense.currency) ?? .chf
                                Text(CurrencyFormatter.string(fromMinorUnits: expense.amount, currency: currencyEnum))
                                    .font(.callout.weight(.medium).monospacedDigit())
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingCreateExpense = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log out") {
                        onLogout()
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $isShowingCreateExpense) {
                CreateExpenseView(
                    viewModel: CreateExpenseViewModel(
                        expenseService: viewModel.expenseService,
                        onSuccess: {
                            isShowingCreateExpense = false
                            Task { await viewModel.loadExpenses() }
                        }
                    )
                )
            }
            .refreshable {
                await viewModel.loadExpenses()
            }
            .overlay {
                if viewModel.isLoading && viewModel.expenses.isEmpty {
                    ProgressView()
                }
            }
            .task {
                await viewModel.loadExpenses()
            }
        }
    }
}
