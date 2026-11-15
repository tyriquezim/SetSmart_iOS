import SwiftUI

struct FoodView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.ssTextMuted)
                Text("Food log coming in Phase 5")
                    .font(.headline)
                    .foregroundStyle(Color.ssTextMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("Food")
        }
    }
}
