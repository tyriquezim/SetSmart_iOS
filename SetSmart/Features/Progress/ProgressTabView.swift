import SwiftUI

struct ProgressTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.ssTextMuted)
                Text("Progress charts coming in Phase 4")
                    .font(.headline)
                    .foregroundStyle(Color.ssTextMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("Progress")
        }
    }
}
