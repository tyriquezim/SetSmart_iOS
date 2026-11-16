import SwiftUI

struct ProgressTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Body Weight").tag(0)
                    Text("Lifts").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                Divider().background(Color.ssBorder)

                if selectedTab == 0 {
                    BodyWeightSection()
                } else {
                    LiftProgressView()
                }
            }
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("Progress")
        }
    }
}
