//
//  ExpenseListView.swift
//  Pexpense
//

import SwiftUI

private struct IdentifiableWrapper<T>: Identifiable {
    let id = UUID()
    let value: T
}

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
    @State private var expenseToEdit: Components.Schemas.ExpenseList.expensesPayloadPayload? = nil
    @State private var expenseToDelete: ExpenseDisplay? = nil
    @State private var isShowingDeleteConfirmation = false

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
                        ForEach(viewModel.expenses) { expense in
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
                                        Text(expense.formattedDate)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text(expense.formattedAmount)
                                    .font(.callout.weight(.medium).monospacedDigit())
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let raw = expense.rawItem {
                                    expenseToEdit = raw
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    expenseToDelete = expense
                                    isShowingDeleteConfirmation = true
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                                .tint(.gray) // Neutral button, danger is indicated by label only per AGENTS.md §4

                                Button {
                                    if let raw = expense.rawItem {
                                        expenseToEdit = raw
                                    }
                                } label: {
                                    Label("Modifier", systemImage: "pencil")
                                }
                                .tint(.secondary)
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
            .sheet(item: Binding(
                get: { expenseToEdit.map { IdentifiableWrapper(value: $0) } },
                set: { expenseToEdit = $0?.value }
            )) { wrapper in
                EditExpenseView(
                    viewModel: EditExpenseViewModel(
                        expense: wrapper.value,
                        expenseService: viewModel.expenseService,
                        onSuccess: {
                            expenseToEdit = nil
                            Task { await viewModel.loadExpenses() }
                        }
                    )
                )
            }
            .confirmationDialog(
                "Supprimer cette dépense ?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Supprimer") {
                    if let id = expenseToDelete?.id {
                        Task { await viewModel.deleteExpense(id: id) }
                    }
                    expenseToDelete = nil
                }
                Button("Annuler", role: .cancel) {
                    expenseToDelete = nil
                }
            } message: {
                if let exp = expenseToDelete {
                    Text("Voulez-vous vraiment supprimer « \(exp.description) » ? Cette action est irréversible.")
                }
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
