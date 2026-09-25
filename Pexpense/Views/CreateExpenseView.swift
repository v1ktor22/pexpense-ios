//
//  CreateExpenseView.swift
//  Pexpense
//

import SwiftUI

/// View for creating a new expense.
///
/// Rules (AGENTS.md §4 & §5):
/// - Clean, minimalist UI adhering to HIG.
/// - System typography with monospaced digits for currency amount input.
/// - Neutral buttons (no red buttons).
/// - Specific field error highlights based on `field` from `VALIDATION_ERROR`.
/// - English/French only (no Portuguese strings).
struct CreateExpenseView: View {
    @Bindable var viewModel: CreateExpenseViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // General error banner
                if let generalError = viewModel.generalErrorMessage {
                    Section {
                        Text(generalError)
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Core Details Section
                Section("Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Description (e.g. Migros, SBB ticket)", text: $viewModel.description)

                        if let descError = viewModel.fieldErrors["description"] {
                            Text(descError)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Picker("Currency", selection: $viewModel.currency) {
                                ForEach(viewModel.currencies, id: \.self) { curr in
                                    Text(curr).tag(curr)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 130)

                            TextField("0.00", text: $viewModel.amountString)
                                .keyboardType(.decimalPad)
                                .font(.system(.body, design: .monospaced))
                                .multilineTextAlignment(.trailing)
                        }

                        if let amountError = viewModel.fieldErrors["amount"] {
                            Text(amountError)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    DatePicker("Date", selection: $viewModel.expenseDate, displayedComponents: .date)
                }

                // Categorization & Payment Section
                Section("Category & Payment") {
                    Picker("Category", selection: $viewModel.selectedCategoryId) {
                        Text("None").tag(nil as String?)
                        ForEach(viewModel.categories, id: \.id) { category in
                            Text(category.name).tag(category.id as String?)
                        }
                    }

                    Picker("Payment Method", selection: $viewModel.paymentMethod) {
                        ForEach(viewModel.paymentMethods, id: \.0) { method in
                            Text(method.1).tag(method.0)
                        }
                    }
                }

                // Recurrence Section
                Section("Recurrence") {
                    Toggle("Recurring Expense", isOn: $viewModel.isRecurring)

                    if viewModel.isRecurring {
                        Stepper(
                            "Day of month: \(viewModel.recurringDayOfMonth)",
                            value: $viewModel.recurringDayOfMonth,
                            in: 1...31
                        )
                    }
                }
            }
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await viewModel.submitExpense() }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isSubmitting)
                }
            }
            .task {
                await viewModel.loadCategories()
            }
        }
    }
}
