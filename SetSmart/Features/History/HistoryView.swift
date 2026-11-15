import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.ssTextMuted)
                Text("Workout history coming in Phase 3")
                    .font(.headline)
                    .foregroundStyle(Color.ssTextMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("History")
        }
    }
}
