import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    let onUnlock: () -> Void

    @State private var isAuthenticating = false
    @State private var authError: String?

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("RelationshipMind")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Tap to unlock")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button {
                    authenticate()
                } label: {
                    Image(systemName: biometricIcon)
                        .font(.system(size: 36))
                        .foregroundColor(.accentColor)
                        .frame(width: 72, height: 72)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Circle())
                }
                .disabled(isAuthenticating)

                if let error = authError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()
            }
        }
    }

    private var biometricIcon: String {
        let context = LAContext()
        var error: NSError?
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }

    private func authenticate() {
        isAuthenticating = true
        authError = nil

        let context = LAContext()
        context.localizedCancelTitle = "Use Passcode"

        let reason = "Unlock RelationshipMind to access your data"

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                isAuthenticating = false
                if success {
                    HapticService.success()
                    onUnlock()
                } else if let error = error as? LAError {
                    switch error.code {
                    case .userCancel, .appCancel, .systemCancel:
                        break
                    default:
                        authError = error.localizedDescription
                    }
                }
            }
        }
    }
}

#Preview {
    LockScreenView {
        print("Unlocked!")
    }
}
