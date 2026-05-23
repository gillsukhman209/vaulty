//
//  AuthenticationController.swift
//  Vaulty
//
//  Created by Sukhman Singh on 5/23/26.
//

import LocalAuthentication
import Observation
import SwiftUI

@MainActor
@Observable
final class AuthenticationController {
    private(set) var isUnlocked = false
    private(set) var isAuthenticating = false
    private(set) var lastErrorMessage: String?

    var biometricName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)

        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Passcode"
        }
    }

    func authenticate() async {
        guard !isUnlocked, !isAuthenticating else { return }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lastErrorMessage = error?.localizedDescription ?? "Set a device passcode to unlock Vaulty."
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock your private photo vault."
            )
            isUnlocked = success
            lastErrorMessage = nil
        } catch {
            isUnlocked = false
            lastErrorMessage = error.localizedDescription
        }
    }

    func lock() {
        guard !isAuthenticating else { return }
        isUnlocked = false
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            guard !isUnlocked else { return }
            Task { await authenticate() }
        case .inactive, .background:
            lock()
        @unknown default:
            lock()
        }
    }
}
