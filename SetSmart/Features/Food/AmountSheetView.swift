import SwiftUI

struct AmountSheetView: View {
    var food: Food
    var meal: Meal
    var eatenOn: String
    var prefillAmount: Double?
    var prefillUnit: String?
    var onAdded: (FoodLog) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var amountStr: String
    @State private var unit: String
    @State private var selectedMeal: Meal
    @State private var isSaving = false
    @State private var error: String?

    private let repo = FoodRepository()

    init(food: Food, meal: Meal, eatenOn: String,
         prefillAmount: Double? = nil, prefillUnit: String? = nil,
         onAdded: @escaping (FoodLog) -> Void) {
        self.food = food
        self.meal = meal
        self.eatenOn = eatenOn
        self.prefillAmount = prefillAmount
        self.prefillUnit = prefillUnit
        self.onAdded = onAdded

        let defaultUnit = prefillUnit ?? (food.servingSize != nil ? "serving" : food.baseUnit)
        let defaultAmount: Double
        if let p = prefillAmount { defaultAmount = p }
        else if defaultUnit == "serving" { defaultAmount = 1 }
        else { defaultAmount = 100 }

        _amountStr     = State(initialValue: formatDecimalInput(defaultAmount))
        _unit          = State(initialValue: defaultUnit)
        _selectedMeal  = State(initialValue: meal)
    }

    private var availableUnits: [String] {
        var units = [food.baseUnit]
        if food.servingSize != nil { units.insert("serving", at: 0) }
        return units
    }

    private var preview: (energyKj: Double, proteinG: Double, carbsG: Double, fatG: Double)? {
        guard let amount = Double(amountStr), amount > 0,
              let g = gramsFor(amount: amount, unit: unit, servingSize: food.servingSize)
        else { return nil }
        return computeNutrients(food: food, grams: g)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food.name)
                            .font(.headline)
                            .foregroundStyle(Color.ssTextPrimary)
                        if let brand = food.brand {
                            Text(brand)
                                .font(.subheadline)
                                .foregroundStyle(Color.ssTextSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.ssSurface)
                }

                Section("Amount") {
                    HStack {
                        TextField("Amount", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .font(.title2.weight(.semibold))
                        Picker("Unit", selection: $unit) {
                            ForEach(availableUnits, id: \.self) { u in
                                Text(unitLabel(u)).tag(u)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    .listRowBackground(Color.ssSurface)
                }

                if let n = preview {
                    Section("Nutrition") {
                        nutritionRow("Energy", value: formatEnergy(n.energyKj, unit: appState.energyUnit))
                        nutritionRow("Protein", value: "\(formatMacro(n.proteinG)) g")
                        nutritionRow("Carbs",   value: "\(formatMacro(n.carbsG)) g")
                        nutritionRow("Fat",     value: "\(formatMacro(n.fatG)) g")
                    }
                }

                Section("Meal") {
                    Picker("Add to", selection: $selectedMeal) {
                        ForEach(Meal.allCases) { Text($0.displayName).tag($0) }
                    }
                    .listRowBackground(Color.ssSurface)
                }

                if let error {
                    Section { Text(error).foregroundStyle(Color.ssDanger) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving { ProgressView() }
                    else {
                        Button("Add") { Task { await add() } }
                            .disabled(preview == nil)
                    }
                }
            }
        }
    }

    private func nutritionRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.ssTextSecondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .listRowBackground(Color.ssSurface)
    }

    private func unitLabel(_ u: String) -> String {
        guard u == "serving" else { return u }
        if let label = food.servingLabel { return label }
        if let ss = food.servingSize { return "\(Int(ss.rounded())) \(food.baseUnit)" }
        return "serving"
    }

    private func add() async {
        guard let amount = Double(amountStr), amount > 0,
              let g = gramsFor(amount: amount, unit: unit, servingSize: food.servingSize),
              let n = preview else { return }
        isSaving = true
        error = nil
        do {
            let log = try await repo.addFoodLog(
                meal: selectedMeal, eatenOn: eatenOn, food: food,
                amount: amount, amountUnit: unit, grams: g,
                energyKj: n.energyKj, proteinG: n.proteinG,
                carbsG: n.carbsG, fatG: n.fatG
            )
            onAdded(log)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
