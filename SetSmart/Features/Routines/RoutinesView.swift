import SwiftUI

struct RoutinesView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.ssTextMuted)
                Text("Routines coming in Phase 2")
                    .font(.headline)
                    .foregroundStyle(Color.ssTextMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("Routines")
        }
    }
}
