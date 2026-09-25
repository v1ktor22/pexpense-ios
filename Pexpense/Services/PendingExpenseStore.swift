//
//  PendingExpenseStore.swift
//  Pexpense
//

import Foundation

/// Stored pending expense operation awaiting confirmation/acknowledgment from the server.
struct PendingExpenseOperation: Codable, Equatable, Sendable {
    let idempotencyKey: String
    let params: CreateExpenseParams
    let createdAt: Date
}

/// Protocol abstracting persistent storage of pending expense operations.
protocol PendingExpenseStore: Sendable {
    func loadPendingOperation() -> PendingExpenseOperation?
    func savePendingOperation(_ operation: PendingExpenseOperation)
    func clearPendingOperation()
}

/// UserDefaults-backed implementation of PendingExpenseStore.
///
/// Stores the idempotency key and params as JSON atomically in UserDefaults.
final class UserDefaultsPendingExpenseStore: PendingExpenseStore, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let storageKey: String

    init(userDefaults: UserDefaults = .standard, storageKey: String = "ch.pexpense.pending_expense_operation") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func loadPendingOperation() -> PendingExpenseOperation? {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(PendingExpenseOperation.self, from: data)
    }

    func savePendingOperation(_ operation: PendingExpenseOperation) {
        if let data = try? JSONEncoder().encode(operation) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    func clearPendingOperation() {
        userDefaults.removeObject(forKey: storageKey)
    }
}
