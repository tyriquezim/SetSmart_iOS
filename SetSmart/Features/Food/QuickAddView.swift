import SwiftUI

struct QuickAddView: View {
    var meal: Meal
    var eatenOn: String
    var onAdded: (FoodLog) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var selectedMeal: Meal
    @State private var energyStr = ""
    @State private var proteinStr = ""
    @State private var carbsStr = ""
    @State private var fatStr = ""
    @State private var isSaving = false
    @State private var error: String?

    private let repo = FoodRepository()

    init(meal: Meal, eatenOn: String, onAdded: @escaping (FoodLog) -> Void) {
        self.meal = meal
        self.eatenOn = eatenOn
        self.onAdded = onAdded
        _selectedMeal = State(initialValue: meal)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Description") {
                    TextField("Name (optional)", text: $name)
                    TextField("Brand (optional)", text: $brand)
                }

                Section("Nutrition") {
                    LabeledContent("Energy (\(appState.energyUnit.label)) *") {
                        TextField("Required", text: $energyStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Protein (g)") {
                        TextField("Optional", text: $proteinStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Carbs (g)") {
                        TextField("Optional", text: $carbsStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Fat (g)") {
                        TextField("Optional", text: $fatStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Meal") {
                    Picker("Add to", selection: $selectedMeal) {
                        ForEach(Meal.allCases) { Text($0.displayName).tag($0) }
                    }
                }

                if let error {
                    Section { Text(error).foregroundStyle(Color.ssDanger) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving { ProgressView() }
                    else {
                        Button("Add") { Task { await add() } }
                            .disabled(energyStr.isEmpty)
                    }
                }
            }
        }
    }

    private func add() async {
        let eu = appState.energyUnit
        guard let energyRaw = Double(energyStr), energyRaw > 0 else {
            error = "Enter a valid energy amount."
            return
        }
        isSaving = true
        error = nil
        do {
            let entryName = name.trimmingCharacters(in: .whitespaces)
            let log = try await repo.addQuickLog(
                meal: selectedMeal,
                eatenOn: eatenOn,
                name: entryName.isEmpty ? "Quick Add" : entryName,
                brand: brand.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                energyKj: eu.toKj(energyRaw),
                proteinG: Double(proteinStr) ?? 0,
                carbsG:   Double(carbsStr)   ?? 0,
                fatG:     Double(fatStr)     ?? 0
            )
            onAdded(log)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

private extension String {
    var nilIfEmpty: String? { trimmingCharacters(in: .whitespaces).isEmpty ? nil : self }
}
