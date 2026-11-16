import SwiftUI

struct NutritionTargetsView: View {
    var initialTargets: NutritionTargets? = nil
    var onSaved: ((NutritionTargets) -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var energyStr = ""
    @State private var proteinStr = ""
    @State private var carbsStr = ""
    @State private var fatStr = ""
    @State private var isSaving = false
    @State private var error: String?

    private let repo = FoodRepository()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Energy (\(appState.energyUnit.label))") {
                        TextField("e.g. 8700", text: $energyStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: { Text("Daily Targets") }

                Section {
                    LabeledContent("Protein (g)") {
                        TextField("e.g. 160", text: $proteinStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Carbs (g)") {
                        TextField("e.g. 220", text: $carbsStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Fat (g)") {
                        TextField("e.g. 70", text: $fatStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Macros")
                } footer: {
                    if let p = Double(proteinStr), let c = Double(carbsStr), let f = Double(fatStr) {
                        let macroKj = (p * 17) + (c * 17) + (f * 37)
                        Text("Macro total: \(formatEnergy(macroKj, unit: appState.energyUnit))")
                    }
                }

                if let error {
                    Section { Text(error).foregroundStyle(Color.ssDanger) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("Nutrition Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving { ProgressView() }
                    else { Button("Save") { Task { await save() } } }
                }
            }
            .onAppear {
                if let t = initialTargets { prefill(t) }
            }
        }
    }

    private func prefill(_ t: NutritionTargets) {
        let eu = appState.energyUnit
        if let e = t.energyKj { energyStr = formatDecimalInput(eu.fromKj(e)) }
        if let p = t.proteinG { proteinStr = formatDecimalInput(p) }
        if let c = t.carbsG   { carbsStr   = formatDecimalInput(c) }
        if let f = t.fatG     { fatStr     = formatDecimalInput(f) }
    }

    private func save() async {
        isSaving = true
        error = nil
        let eu = appState.energyUnit
        let targets = NutritionTargets(
            energyKj: Double(energyStr).map { eu.toKj($0) },
            proteinG: Double(proteinStr),
            carbsG:   Double(carbsStr),
            fatG:     Double(fatStr)
        )
        do {
            try await repo.saveTargets(targets)
            onSaved?(targets)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
