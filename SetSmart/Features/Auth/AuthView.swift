import SwiftUI

struct AuthView: View {
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
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }
}
