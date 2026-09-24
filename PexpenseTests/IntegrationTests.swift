//
//  IntegrationTests.swift
//  PexpenseTests
//

import Foundation
import Testing
@testable import Pexpense

@Suite("IntegrationTests")
struct IntegrationTests {

    private static var isLiveTestingEnabled: Bool {
        ProcessInfo.processInfo.environment["PEXPENSE_LIVE_TESTS"] == "1"
    }

    @Test(
        "Backend health endpoint returns ok",
        .enabled(if: isLiveTestingEnabled, "Skipped by default. Set PEXPENSE_LIVE_TESTS=1 to run.")
    )
    func backendHealthCheck() async throws {
        let (data, response) = try await URLSession.shared.data(from: URL(string: "https://devpexpense.local/api/v1/health")!)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)

        struct HealthResponse: Decodable {
            let status: String
        }
        let decoded = try JSONDecoder().decode(HealthResponse.self, from: data)
        #expect(decoded.status == "ok")
    }

    @Test(
        "Remote auth error parsing returns INVALID_CODE for invalid OTP",
        .enabled(if: isLiveTestingEnabled, "Skipped by default. Set PEXPENSE_LIVE_TESTS=1 to run.")
    )
    func remoteAuthInvalidCode() async throws {
        let (data, response) = try await URLSession.shared.data(for: {
            var req = URLRequest(url: URL(string: "https://devpexpense.local/api/v1/auth/token")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try! JSONSerialization.data(withJSONObject: [
                "email": "test-ci-nonexistent@pexpense.ch",
                "otp": "0000",
                "deviceName": "TestRunner",
                "platform": "iOS"
            ])
            return req
        }())
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 400)

        struct ErrorResponse: Decodable {
            let code: String
        }
        let decoded = try JSONDecoder().decode(ErrorResponse.self, from: data)
        #expect(decoded.code == "INVALID_CODE")
    }

    @Test("KeychainService saves and reads tokens")
    func keychainTokenCycle() throws {
        let testStore = KeychainService(service: "ch.pexpense.test.tokens")
        testStore.clear()

        try testStore.save(accessToken: "access_123", refreshToken: "refresh_456")
        #expect(testStore.loadAccessToken() == "access_123")
        #expect(testStore.loadRefreshToken() == "refresh_456")

        testStore.clear()
        #expect(testStore.loadAccessToken() == nil)
        #expect(testStore.loadRefreshToken() == nil)
    }
}
