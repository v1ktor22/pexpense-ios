//
//  ExpenseCreationTests.swift
//  PexpenseTests
//

import Foundation
import Testing
@testable import Pexpense

/// Mock implementation of ExpenseServiceProtocol for testing idempotency and failure recovery.
final class MockExpenseService: ExpenseServiceProtocol, @unchecked Sendable {
    var capturedCalls: [(params: CreateExpenseParams, key: String)] = []
    var resultToReturn: Result<Components.Schemas.CreateExpenseResponse, Error> = .success(
        .init(id: "exp_created_123")
    )
    var categoriesToReturn: [Components.Schemas.Category] = []

    func fetchExpenses(limit: Int?) async throws -> Components.Schemas.ExpenseList {
        fatalError("Not needed for these tests")
    }

    func fetchCategories() async throws -> [Components.Schemas.Category] {
        return categoriesToReturn
    }

    func createExpense(
        params: CreateExpenseParams,
        idempotencyKey: String
    ) async throws -> Components.Schemas.CreateExpenseResponse {
        capturedCalls.append((params, idempotencyKey))
        switch resultToReturn {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}

@Suite("ExpenseCreationTests")
struct ExpenseCreationTests {

    @Test("Retry of same operation reuses the EXACT same Idempotency-Key")
    @MainActor
    func retryReusesSameIdempotencyKey() async throws {
        let mockService = MockExpenseService()
        let coordinator = ExpenseSubmissionCoordinator(expenseService: mockService)

        let params = CreateExpenseParams(
            description: "Lunch at Swiss Chalet",
            amountInUnits: 25.50,
            currency: "CHF",
            expenseDate: "2026-09-25",
            paymentMethod: "card",
            categoryId: "cat_1"
        )

        // Simulate network failure on attempt 1
        mockService.resultToReturn = .failure(URLError(.notConnectedToInternet))

        do {
            _ = try await coordinator.submit(params: params)
            Issue.record("Expected failure on attempt 1")
        } catch {
            // expected
        }

        #expect(mockService.capturedCalls.count == 1)
        let firstKey = mockService.capturedCalls[0].key
        #expect(!firstKey.isEmpty)

        // Attempt 2: retry after network recovery
        mockService.resultToReturn = .success(.init(id: "exp_created_123"))
        let successResponse = try await coordinator.submit(params: params)

        #expect(successResponse.id == "exp_created_123")
        #expect(mockService.capturedCalls.count == 2)
        let retryKey = mockService.capturedCalls[1].key

        // CRITICAL CHECK: The retry MUST have used the exact same key
        #expect(retryKey == firstKey)
    }

    @Test("Two distinct operations receive DIFFERENT Idempotency-Keys")
    @MainActor
    func distinctOperationsReceiveDifferentKeys() async throws {
        let mockService = MockExpenseService()
        let coordinator = ExpenseSubmissionCoordinator(expenseService: mockService)

        let params1 = CreateExpenseParams(
            description: "Train ticket",
            amountInUnits: 14.80,
            currency: "CHF",
            expenseDate: "2026-09-25"
        )

        let params2 = CreateExpenseParams(
            description: "Coffee",
            amountInUnits: 4.50,
            currency: "CHF",
            expenseDate: "2026-09-25"
        )

        _ = try await coordinator.submit(params: params1)
        _ = try await coordinator.submit(params: params2)

        #expect(mockService.capturedCalls.count == 2)
        let key1 = mockService.capturedCalls[0].key
        let key2 = mockService.capturedCalls[1].key

        #expect(key1 != key2)
    }

    @Test("409 IDEMPOTENCY_KEY_REUSED generates a NEW key for next attempt")
    @MainActor
    func keyReusedGeneratesNewKeyOnNextAttempt() async throws {
        let mockService = MockExpenseService()
        let coordinator = ExpenseSubmissionCoordinator(expenseService: mockService)

        let params = CreateExpenseParams(
            description: "Groceries",
            amountInUnits: 80.00,
            currency: "CHF",
            expenseDate: "2026-09-25"
        )

        mockService.resultToReturn = .failure(AppApiError(code: "IDEMPOTENCY_KEY_REUSED", message: "Key already used with different body"))

        do {
            _ = try await coordinator.submit(params: params)
            Issue.record("Expected 409 error")
        } catch let err as AppApiError {
            #expect(err.code == "IDEMPOTENCY_KEY_REUSED")
        }

        #expect(mockService.capturedCalls.count == 1)
        let firstKey = mockService.capturedCalls[0].key

        // Next attempt must generate a new key because the previous one was invalid/mismatched
        mockService.resultToReturn = .success(.init(id: "exp_groceries_ok"))
        _ = try await coordinator.submit(params: params)

        #expect(mockService.capturedCalls.count == 2)
        let secondKey = mockService.capturedCalls[1].key
        #expect(secondKey != firstKey)
    }

    @Test("ExpenseDisplay presentation model maps cents to Swiss Francs correctly")
    func expenseDisplayMapping() {
        let display = ExpenseDisplay(
            id: "1",
            description: "Supermarket Coop",
            amountInCentimes: 341_100,
            currencyCode: "CHF",
            expenseDate: "2026-09-25",
            categoryName: "Food",
            categoryColor: "#16a34a"
        )

        #expect(display.formattedAmount == "CHF 3'411.00")
        #expect(display.formattedDate == "2026-09-25")
        #expect(display.description == "Supermarket Coop")
        #expect(display.categoryName == "Food")
    }

    @Test("ExpenseDisplay presentation model maps Euro amounts correctly")
    func expenseDisplayMappingEuro() {
        let display = ExpenseDisplay(
            id: "2",
            description: "French Bakery",
            amountInCentimes: 6_850,
            currencyCode: "EUR",
            expenseDate: "2026-09-25"
        )

        #expect(display.formattedAmount == "€ 68.50")
    }
}
