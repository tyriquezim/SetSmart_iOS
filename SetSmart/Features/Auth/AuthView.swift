import SwiftUI

struct AuthView: View {
    @Environment(AppState.self) private var appState
    @State private var showSignUp = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            Group {
                if showSignUp {
                    SignUpView(showSignUp: $showSignUp)
                } else {
                    SignInView(showSignUp: $showSignUp, showForgotPassword: $showForgotPassword)
                }
            }
            .background(Color.ssBackground.ignoresSafeArea())
        }
        .safeAreaInset(edge: .top) {
            if let notice = appState.deletionNotice {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.ssAccent)
                    Text(notice)
                        .font(.subheadline)
                        .foregroundStyle(Color.ssTextPrimary)
                    Spacer()
                    Button {
                        appState.deletionNotice = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.ssTextMuted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.ssSurface)
                .overlay(alignment: .bottom) {
                    Divider()
                }
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }
}
