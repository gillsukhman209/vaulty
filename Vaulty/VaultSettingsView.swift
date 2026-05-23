//
//  VaultSettingsView.swift
//  Vaulty
//
//  Created by Sukhman Singh on 5/23/26.
//

import LocalAuthentication
import SwiftUI

struct VaultSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AuthenticationController.faceIDEnabledKey) private var faceIDEnabled = true
    @AppStorage(VaultTheme.appearanceKey) private var appearanceRawValue = VaultAppearance.system.rawValue

    @State private var currentPIN = ""
    @State private var newPIN = ""
    @State private var confirmPIN = ""
    @State private var message: String?
    @State private var isShowingPINChange = false

    private var biometricName: String {
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
            return "Biometrics"
        }
    }

    private var canUseBiometrics: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceRawValue) {
                        ForEach(VaultAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(VaultTheme.accent)
                }

                Section("Unlocking") {
                    Toggle("Use \(biometricName)", isOn: $faceIDEnabled)
                        .tint(VaultTheme.accent)
                        .disabled(!canUseBiometrics)

                    if !canUseBiometrics {
                        Text("Biometric unlock is not available on this device.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Vaulty PIN") {
                    Button {
                        isShowingPINChange.toggle()
                    } label: {
                        Label("Change PIN", systemImage: "key.fill")
                    }

                    if isShowingPINChange {
                        SecureField("Current PIN", text: $currentPIN)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .onChange(of: currentPIN) { _, value in
                                currentPIN = sanitizedPIN(value)
                            }

                        SecureField("New PIN", text: $newPIN)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .onChange(of: newPIN) { _, value in
                                newPIN = sanitizedPIN(value)
                            }

                        SecureField("Confirm New PIN", text: $confirmPIN)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .onChange(of: confirmPIN) { _, value in
                                confirmPIN = sanitizedPIN(value)
                            }

                        Button("Save New PIN") {
                            changePIN()
                        }
                        .disabled(currentPIN.count != 4 || newPIN.count != 4 || confirmPIN.count != 4)
                    }
                }

                if let message {
                    Section {
                        Text(message)
                            .foregroundStyle(message == "PIN updated." ? .green : .red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(VaultTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(VaultTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func changePIN() {
        guard VaultPINStore.verify(currentPIN) else {
            message = "Current PIN is incorrect."
            return
        }

        guard isValidPIN(newPIN) else {
            message = "Use a 4-digit PIN."
            return
        }

        guard newPIN == confirmPIN else {
            message = "New PINs do not match."
            return
        }

        do {
            try VaultPINStore.setPIN(newPIN)
            currentPIN = ""
            newPIN = ""
            confirmPIN = ""
            isShowingPINChange = false
            message = "PIN updated."
        } catch {
            message = error.localizedDescription
        }
    }

    private func isValidPIN(_ pin: String) -> Bool {
        pin.count == 4 && pin.allSatisfy(\.isNumber)
    }

    private func sanitizedPIN(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(4))
    }
}

#Preview {
    VaultSettingsView()
}
