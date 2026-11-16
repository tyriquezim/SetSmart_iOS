import SwiftUI

struct FoodDetailFormView: View {
    enum FormMode { case create; case edit(Food) }

    var mode: FormMode
    var onSaved: (Food) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var barcode = ""
    @State private var baseUnit = "g"
    @State private var servingSizeStr = ""
    @State private var servingLabelStr = ""
    @State private var nutritionMode: NutritionMode = .per100
    @State private var energyStr = ""
    @State private var proteinStr = ""
    @State private var carbsStr = ""
    @State private var fatStr = ""
    @State private var isSaving = false
    @State private var error: String?

    private let repo = FoodRepository()

    private enum NutritionMode: String, CaseIterable {
        case per100 = "Per 100g/ml"
        case perServing = "Per serving"
    }

    private var servingSize: Double? { Double(servingSizeStr).flatMap { $0 > 0 ? $0 : nil } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    LabeledContent("Name *") {
                        TextField("Required", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Brand") {
                        TextField("Optional", text: $brand)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Barcode") {
                        TextField("Optional", text: $barcode)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Base unit", selection: $baseUnit) {
                        Text("Solid (g)").tag("g")
                        Text("Liquid (ml)").tag("ml")
                    }
                }

                Section("Serving (optional)") {
                    LabeledContent("Size (\(baseUnit))") {
                        TextField("e.g. 30", text: $servingSizeStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Label") {
                        TextField("e.g. 1 biscuit", text: $servingLabelStr)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    if servingSize != nil {
                        Picker("Values are", selection: $nutritionMode) {
                            ForEach(NutritionMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: nutritionMode, switchMode)
                    }
                    LabeledContent("Energy (kJ) *") {
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
                } header: {
                    Text("Nutrition \(nutritionMode == .perServing ? "(per serving)" : "(per 100 \(baseUnit))")")
                }

                if let error { Section { Text(error).foregroundStyle(Color.ssDanger) } }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle(isEdit ? "Edit Food" : "New Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving { ProgressView() }
                    else {
                        Button("Save") { Task { await save() } }
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || energyStr.isEmpty)
                    }
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private var isEdit: Bool { if case .edit = mode { return true }; return false }

    private func loadExisting() {
        guard case .edit(let food) = mode else { return }
        name           = food.name
        brand          = food.brand          ?? ""
        barcode        = food.barcode        ?? ""
        baseUnit       = food.baseUnit
        servingSizeStr = food.servingSize.map { formatDecimalInput($0) } ?? ""
        servingLabelStr = food.servingLabel  ?? ""
        energyStr      = formatDecimalInput(food.energyKj)
        proteinStr     = food.proteinG.map { formatDecimalInput($0) } ?? ""
        carbsStr       = food.carbsG.map   { formatDecimalInput($0) } ?? ""
        fatStr         = food.fatG.map     { formatDecimalInput($0) } ?? ""
    }

    private func switchMode(old: NutritionMode, new: NutritionMode) {
        guard let ss = servingSize, ss > 0 else { return }
        let factor = new == .perServing ? ss / 100 : 100 / ss
        func scale(_ s: String) -> String {
            guard let v = Double(s) else { return s }
            return formatDecimalInput(v * factor)
        }
        energyStr  = scale(energyStr)
        proteinStr = scale(proteinStr)
        carbsStr   = scale(carbsStr)
        fatStr     = scale(fatStr)
    }

    private func save() async {
        guard let energyRaw = Double(energyStr) else { error = "Enter a valid energy value."; return }
        isSaving = true
        error = nil

        let ss = servingSize ?? 0
        let p100: Double = (nutritionMode == .perServing && ss > 0) ? (100 / ss) : 1

        func toP100(_ s: String) -> Double? {
            guard let v = Double(s), v >= 0 else { return nil }
            return v * p100
        }

        let baseId: UUID = { if case .edit(let f) = mode { return f.id }; return UUID() }()

        let food = Food(
            id: baseId, source: "custom", sourceId: nil,
            name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.trimmed.nilIfEmpty,
            barcode: barcode.trimmed.nilIfEmpty,
            baseUnit: baseUnit,
            energyKj: energyRaw * p100,
            proteinG: toP100(proteinStr),
            carbsG:   toP100(carbsStr),
            fatG:     toP100(fatStr),
            servingSize: ss > 0 ? ss : nil,
            servingLabel: servingLabelStr.trimmed.nilIfEmpty,
            archivedAt: nil, userId: nil
        )

        do {
            if case .edit = mode {
                try await repo.updateCustomFood(food)
                onSaved(food)
            } else {
                let saved = try await repo.createCustomFood(food)
                onSaved(saved)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
    var nilIfEmpty: String? { trimmed.isEmpty ? nil : trimmed }
}
