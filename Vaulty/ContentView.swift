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
            await authentication.authenticate()
        }
        .onChange(of: scenePhase) { _, phase in
            authentication.handleScenePhase(phase)
        }
    }
}

struct VaultLockView: View {
    let authentication: AuthenticationController

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Vaulty")
                    .font(.largeTitle.bold())

                Text("Unlock with \(authentication.biometricName) or your device passcode.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            Button {
                Task { await authentication.authenticate() }
            } label: {
                Label(authentication.isAuthenticating ? "Unlocking" : "Unlock Vault", systemImage: "faceid")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .disabled(authentication.isAuthenticating)

            if let message = authentication.lastErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Locked") {
    VaultLockView(authentication: AuthenticationController())
}

#Preview("App") {
    ContentView()
        .modelContainer(for: VaultPhoto.self, inMemory: true)
}
