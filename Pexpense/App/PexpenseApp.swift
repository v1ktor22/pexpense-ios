//
//  PexpenseApp.swift
//  Pexpense
//

import SwiftUI

@main
struct PexpenseApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
        }
    }
}

