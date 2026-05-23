//
//  ContentView.swift
//  Vaulty
//
//  Created by Sukhman Singh on 5/23/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var authentication = AuthenticationController()

    var body: some View {
        Group {
            if authentication.isUnlocked {
                VaultHomeView()
                    .transition(.opacity)
            } else {
                VaultLockView(authentication: authentication)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: authentication.isUnlocked)
        .task {
            authentication.startUnlockFlow()
        }
        .onChange(of: scenePhase) { _, phase in
            authentication.handleScenePhase(phase)
        }
    }
}

struct VaultLockView: View {
    let authentication: AuthenticationController

    @State private var pin = ""
    @State private var newPIN = ""
    @State private var confirmPIN = ""

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(VaultTheme.accentGradient)
                    .frame(width: 104, height: 104)
                    .shadow(color: VaultTheme.accent.opacity(0.26), radius: 24, y: 14)

                Image(systemName: authentication.hasPIN ? "lock.shield.fill" : "lock.badge.plus")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Vaulty")
                    .font(.largeTitle.bold())
                    .foregroundStyle(VaultTheme.primaryText)

                Text(authentication.hasPIN ? "Enter your Vaulty PIN." : "Create a Vaulty PIN.")
                    .font(.body)
                    .foregroundStyle(VaultTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 18) {
                if authentication.hasPIN {
                    unlockForm
                } else {
                    setupForm
                }
            }
            .padding(18)
            .background(VaultTheme.elevatedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(VaultTheme.border, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 22, y: 12)

            if let message = authentication.lastErrorMessage {
                Text(message)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(VaultTheme.backgroundGradient.ignoresSafeArea())
    }

    private var unlockForm: some View {
        VStack(spacing: 14) {
            SecureField("PIN", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title2.monospacedDigit())
                .foregroundStyle(VaultTheme.primaryText)
                .padding()
                .background(VaultTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(VaultTheme.border, lineWidth: 1)
                }
                .onChange(of: pin) { _, value in
                    pin = sanitizedPIN(value)
                    guard pin.count == 4 else { return }

                    if !authentication.unlock(with: pin) {
                        pin = ""
                    }
                }

            if authentication.shouldOfferBiometrics {
                Button {
                    Task { await authentication.authenticateWithBiometrics() }
                } label: {
                    Label("Use \(authentication.biometricName)", systemImage: "faceid")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(VaultTheme.accent)
                .disabled(authentication.isAuthenticating)
            }
        }
    }

    private var setupForm: some View {
        VStack(spacing: 14) {
            SecureField("New PIN", text: $newPIN)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title2.monospacedDigit())
                .foregroundStyle(VaultTheme.primaryText)
                .padding()
                .background(VaultTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(VaultTheme.border, lineWidth: 1)
                }
                .onChange(of: newPIN) { _, value in
                    newPIN = sanitizedPIN(value)
                }

            SecureField("Confirm PIN", text: $confirmPIN)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title2.monospacedDigit())
                .foregroundStyle(VaultTheme.primaryText)
                .padding()
                .background(VaultTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(VaultTheme.border, lineWidth: 1)
                }
                .onChange(of: confirmPIN) { _, value in
                    confirmPIN = sanitizedPIN(value)
                }

            Button {
                _ = authentication.createPIN(newPIN, confirmation: confirmPIN)
            } label: {
                Label("Create PIN", systemImage: "checkmark.shield.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(VaultTheme.accent)
            .disabled(newPIN.count != 4 || confirmPIN.count != 4)
        }
    }

    private func sanitizedPIN(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(4))
    }
}

#Preview("Locked") {
    VaultLockView(authentication: AuthenticationController())
}

#Preview("App") {
    ContentView()
        .modelContainer(for: VaultPhoto.self, inMemory: true)
}
