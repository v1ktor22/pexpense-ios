//
//  EditExpenseView.swift
//  Pexpense
//

import SwiftUI

/// View for partially editing an existing expense.
///
/// Rules (AGENTS.md §4):
/// - Clean, minimalist UI adhering to HIG.
/// - System typography with monospaced digits for money.
/// - Neutral buttons (no red buttons).
/// - Specific field error highlights based on `field` from `VALIDATION_ERROR`.
struct EditExpenseView: View {
    @Bindable var viewModel: EditExpenseViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
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

                Section("Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Description", text: $viewModel.description)

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
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await viewModel.save() }
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
