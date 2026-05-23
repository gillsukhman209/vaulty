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
    static let faceIDEnabledKey = "faceIDEnabled"

    private(set) var isUnlocked = false
    private(set) var isAuthenticating = false
    private(set) var lastErrorMessage: String?
    private(set) var hasPIN = VaultPINStore.hasPIN

    var isFaceIDEnabled: Bool {
        if UserDefaults.standard.object(forKey: Self.faceIDEnabledKey) == nil {
            return true
        }

        return UserDefaults.standard.bool(forKey: Self.faceIDEnabledKey)
    }

    var canUseBiometrics: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var shouldOfferBiometrics: Bool {
        hasPIN && isFaceIDEnabled && canUseBiometrics
    }

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

    func startUnlockFlow() {
        refreshPINState()

        guard !isUnlocked, shouldOfferBiometrics else {
            return
        }

        Task { await authenticateWithBiometrics() }
    }

    func authenticateWithBiometrics() async {
        guard !isUnlocked, !isAuthenticating, shouldOfferBiometrics else { return }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = ""

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            lastErrorMessage = error?.localizedDescription ?? "Enter your Vaulty PIN."
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock your private photo vault."
            )
            isUnlocked = success
            lastErrorMessage = nil
        } catch {
            isUnlocked = false
            lastErrorMessage = "Enter your Vaulty PIN."
        }
    }

    func createPIN(_ pin: String, confirmation: String) -> Bool {
        guard isValidPIN(pin) else {
            lastErrorMessage = "Use a 4-digit PIN."
            return false
        }

        guard pin == confirmation else {
            lastErrorMessage = "PINs do not match."
            return false
        }

        do {
            try VaultPINStore.setPIN(pin)
            hasPIN = true
            isUnlocked = true
            lastErrorMessage = nil
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    func unlock(with pin: String) -> Bool {
        guard isValidPIN(pin), VaultPINStore.verify(pin) else {
            lastErrorMessage = "Incorrect PIN."
            return false
        }

        isUnlocked = true
        lastErrorMessage = nil
        return true
    }

    func refreshPINState() {
        hasPIN = VaultPINStore.hasPIN
    }

    func lock() {
        guard !isAuthenticating else { return }
        isUnlocked = false
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            guard !isUnlocked else { return }
            startUnlockFlow()
        case .inactive, .background:
            lock()
        @unknown default:
            lock()
        }
    }

    private func isValidPIN(_ pin: String) -> Bool {
        pin.count == 4 && pin.allSatisfy(\.isNumber)
    }
}
