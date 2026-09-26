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

    var onCall: ((_ key: String) -> Void)?

    func fetchExpenses(limit: Int?) async throws -> Components.Schemas.ExpenseList {
        return .init(
            expenses: [],
            summary: .init(
                totalsByCurrency: [],
                monthlyCount: 0,
                fxRate: nil,
                availableMonths: nil,
                period: nil
            ),
            charts: .init(
                byCategory: [],
                dailyTotals: [],
                monthlyTrend: [],
                paymentMethods: [],
                topExpenses: []
            )
        )
    }

    func fetchCategories() async throws -> [Components.Schemas.Category] {
        return categoriesToReturn
    }

    func createExpense(
        params: CreateExpenseParams,
        idempotencyKey: String
    ) async throws -> Components.Schemas.CreateExpenseResponse {
        capturedCalls.append((params, idempotencyKey))
        onCall?(idempotencyKey)
        switch resultToReturn {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    var capturedUpdates: [(id: String, params: UpdateExpenseParams)] = []
    var updateResultToReturn: Result<Void, Error> = .success(())

    func updateExpense(id: String, params: UpdateExpenseParams) async throws {
        capturedUpdates.append((id, params))
        switch updateResultToReturn {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    var capturedDeletions: [String] = []
    var deleteResultToReturn: Result<Void, Error> = .success(())

    func deleteExpense(id: String) async throws {
        capturedDeletions.append(id)
        switch deleteResultToReturn {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}

/// In-memory implementation of PendingExpenseStore for testing persistence order and lifecycle.
final class MockPendingExpenseStore: PendingExpenseStore, @unchecked Sendable {
    var storedOperation: PendingExpenseOperation?
    var events: [String] = []

    func loadPendingOperation() -> PendingExpenseOperation? {
        storedOperation
    }

    func savePendingOperation(_ operation: PendingExpenseOperation) {
        events.append("savePendingOperation:\(operation.idempotencyKey)")
        storedOperation = operation
    }

    func clearPendingOperation() {
        events.append("clearPendingOperation")
        storedOperation = nil
    }
}

@Suite("ExpenseCreationTests")
struct ExpenseCreationTests {

    // MARK: - Test 1: Invariant 1 - Grava antes de enviar
    @Test("Grava-antes-de-enviar: Pending operation is persisted BEFORE network POST is made")
    @MainActor
    func saveBeforeSendOrder() async throws {
        let mockService = MockExpenseService()
        let mockStore = MockPendingExpenseStore()
        var eventLog: [String] = []

        mockService.onCall = { key in
            eventLog.append("networkPost:\(key)")
        }

        let coordinator = ExpenseSubmissionCoordinator(
            expenseService: mockService,
            pendingStore: mockStore
        )

        let params = CreateExpenseParams(
            description: "Stationery",
            amountInUnits: 12.50,
            currency: "CHF",
            expenseDate: "2026-09-25"
        )

        _ = try await coordinator.submit(params: params)

        let saveIndex = mockStore.events.firstIndex(where: { $0.starts(with: "savePendingOperation") })
        #expect(saveIndex != nil)

        #expect(mockService.capturedCalls.count == 1)
        let callKey = mockService.capturedCalls[0].key
        #expect(mockStore.events[0] == "savePendingOperation:\(callKey)")
        #expect(eventLog.first == "networkPost:\(callKey)")

        #expect(mockStore.events.contains("clearPendingOperation"))
        #expect(mockStore.loadPendingOperation() == nil)
    }

    // MARK: - Test 2: Invariant 5 - Expirado não replaya (12h TTL)
    @Test("Expirado nao replaya: Pending operation older than 12h is discarded on launch and NOT sent")
    @MainActor
    func expiredOperationNotReplayed() async throws {
        let mockService = MockExpenseService()
        let mockStore = MockPendingExpenseStore()

        let currentTime = Date()

        let staleParams = CreateExpenseParams(
            description: "Old Expense from yesterday",
            amountInUnits: 45.00,
            currency: "CHF",
            expenseDate: "2026-09-24"
        )

        let thirteenHoursAgo = currentTime.addingTimeInterval(-13 * 3600)
        let staleOperation = PendingExpenseOperation(
            idempotencyKey: "stale-key-13h",
            params: staleParams,
            createdAt: thirteenHoursAgo
        )
        mockStore.savePendingOperation(staleOperation)
        mockStore.events.removeAll()

        let coordinator = ExpenseSubmissionCoordinator(
            expenseService: mockService,
            pendingStore: mockStore,
            dateProvider: { currentTime }
        )

        let replayed = await coordinator.replayPendingOperationIfNeeded()

        #expect(!replayed)
        #expect(mockService.capturedCalls.isEmpty)
        #expect(mockStore.loadPendingOperation() == nil)
        #expect(coordinator.currentIdempotencyKey == nil)
    }

    @Test("Pending operation within 12h is replayed on launch with the same key")
    @MainActor
    func validPendingOperationIsReplayedOnLaunch() async throws {
        let mockService = MockExpenseService()
        let mockStore = MockPendingExpenseStore()

        let now = Date()
        let params = CreateExpenseParams(
            description: "Lunch interrupted by crash",
            amountInUnits: 20.00,
            currency: "CHF",
            expenseDate: "2026-09-25"
        )

        let twoHoursAgo = now.addingTimeInterval(-2 * 3600)
        let savedOp = PendingExpenseOperation(
            idempotencyKey: "crash-recovery-key-uuid",
            params: params,
            createdAt: twoHoursAgo
        )
        mockStore.savePendingOperation(savedOp)

        let coordinator = ExpenseSubmissionCoordinator(
            expenseService: mockService,
            pendingStore: mockStore,
            dateProvider: { now }
        )

        let replayed = await coordinator.replayPendingOperationIfNeeded()

        #expect(replayed)
        #expect(mockService.capturedCalls.count == 1)
        #expect(mockService.capturedCalls[0].key == "crash-recovery-key-uuid")
        #expect(mockStore.loadPendingOperation() == nil)
    }

    // MARK: - Test 3: Invariant 3 - Retry reusa a chave
    @Test("Retry of same operation reuses the EXACT same Idempotency-Key")
    @MainActor
    func retryReusesSameIdempotencyKey() async throws {
        let mockService = MockExpenseService()
        let mockStore = MockPendingExpenseStore()
        let coordinator = ExpenseSubmissionCoordinator(
            expenseService: mockService,
            pendingStore: mockStore
        )

        let params = CreateExpenseParams(
            description: "Lunch at Swiss Chalet",
            amountInUnits: 25.50,
            currency: "CHF",
            expenseDate: "2026-09-25",
            paymentMethod: "card",
            categoryId: "cat_1"
        )

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

        mockService.resultToReturn = .success(.init(id: "exp_created_123"))
        let successResponse = try await coordinator.submit(params: params)

        #expect(successResponse.id == "exp_created_123")
        #expect(mockService.capturedCalls.count == 2)
        let retryKey = mockService.capturedCalls[1].key

        #expect(retryKey == firstKey)
        #expect(mockStore.loadPendingOperation() == nil)
    }

    @Test("Two distinct operations receive DIFFERENT Idempotency-Keys")
    @MainActor
    func distinctOperationsReceiveDifferentKeys() async throws {
        let mockService = MockExpenseService()
        let mockStore = MockPendingExpenseStore()
        let coordinator = ExpenseSubmissionCoordinator(
            expenseService: mockService,
            pendingStore: mockStore
        )

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
        let mockStore = MockPendingExpenseStore()
        let coordinator = ExpenseSubmissionCoordinator(
            expenseService: mockService,
            pendingStore: mockStore
        )

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

        mockService.resultToReturn = .success(.init(id: "exp_groceries_ok"))
        _ = try await coordinator.submit(params: params)

        #expect(mockService.capturedCalls.count == 2)
        let secondKey = mockService.capturedCalls[1].key
        #expect(secondKey != firstKey)
    }

    // MARK: - Costura de Mapeamento (ExpenseDisplay)
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

    // MARK: - Caminho de Ida e Volta do Dinheiro (Edição e Exclusão)
    @Test("Ida e volta do dinheiro: 341100 centimes preenche 3411.00 e PATCH envia 3411 unidades")
    @MainActor
    func moneyRoundtripCHF() async throws {
        let mockService = MockExpenseService()

        // 1. Despesa vem da API com 341100 centimes
        let schemaExpense = Components.Schemas.ExpenseList.expensesPayloadPayload(
            id: "exp_1",
            description: "Coop Supermarché",
            amount: 341_100, // 341100 centavos
            currency: "CHF",
            expenseDate: "2026-09-25",
            paymentMethod: "card",
            categoryId: nil,
            categoryName: nil,
            categoryColor: "#000000",
            categoryIcon: nil,
            receiptId: nil,
            recurringRuleId: nil,
            recurringGenerated: false
        )

        var dismissed = false
        let viewModel = EditExpenseViewModel(
            expense: schemaExpense,
            expenseService: mockService,
            onSuccess: { dismissed = true }
        )

        // 2. Preenchimento do formulário: DEVE ser em UNIDADES (3411.00), NUNCA 341100
        #expect(viewModel.amountString == "3411.00")
        #expect(viewModel.amountString != "341100")

        // 3. Se alterar a descrição e salvar, o PATCH deve carregar apenas o que mudou, e amount continua inalterado
        viewModel.description = "Coop Supermarché Renens"
        await viewModel.save()

        #expect(dismissed)
        #expect(mockService.capturedUpdates.count == 1)
        let update = mockService.capturedUpdates[0]
        #expect(update.id == "exp_1")
        #expect(update.params.description == "Coop Supermarché Renens")
        #expect(update.params.amountInUnits == nil) // sem alteração de valor

        // 4. Se o usuário alterar o valor para 3500.50 unidades
        viewModel.amountString = "3500.50"
        await viewModel.save()

        #expect(mockService.capturedUpdates.count == 2)
        let secondUpdate = mockService.capturedUpdates[1]
        // O valor enviado deve ser 3500.5 (unidades), JAMAIS 350050 centavos
        #expect(secondUpdate.params.amountInUnits == 3500.50)
    }

    @Test("Ida e volta do dinheiro: 2500 centimes EUR preenche 25.00 unidades")
    @MainActor
    func moneyRoundtripEUR() async throws {
        let mockService = MockExpenseService()

        let schemaExpense = Components.Schemas.ExpenseList.expensesPayloadPayload(
            id: "exp_2",
            description: "Boulangerie",
            amount: 2_500, // 2500 centavos
            currency: "EUR",
            expenseDate: "2026-09-25",
            paymentMethod: "cash",
            categoryId: nil,
            categoryName: nil,
            categoryColor: "#000000",
            categoryIcon: nil,
            receiptId: nil,
            recurringRuleId: nil,
            recurringGenerated: false
        )

        let viewModel = EditExpenseViewModel(
            expense: schemaExpense,
            expenseService: mockService,
            onSuccess: {}
        )

        // 2500 centavos -> "25.00" unidades
        #expect(viewModel.amountString == "25.00")
        #expect(viewModel.amountString != "2500")
    }

    @Test("Excluir despesa chama DELETE /api/v1/expenses/{id}")
    @MainActor
    func deleteExpenseCallsService() async throws {
        let mockService = MockExpenseService()
        let listViewModel = ExpenseListViewModel(expenseService: mockService)

        await listViewModel.deleteExpense(id: "exp_to_delete_999")

        #expect(mockService.capturedDeletions.count == 1)
        #expect(mockService.capturedDeletions[0] == "exp_to_delete_999")
    }
}
