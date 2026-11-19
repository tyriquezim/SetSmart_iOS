import SwiftUI

// MARK: - Sheet content enum

enum EnergySheetContent: Identifiable, Sendable {
    case resting(RestingEnergyResult, stats: BodyStats)
    case everydayActivity(restingKcal: Double, pal: Double, activity: DailyActivity?, assumed: Bool)
    case workoutsDay(workoutKcal: Double, met: Double, effort: WorkoutEffort, weightKg: Double, restingKcalPerMin: Double)
    case totalBurn(DayEnergyComponents)
    case singleWorkout(WorkoutEnergyFull)
    case cardioDay(cardioKcal: Double, weightKg: Double, restingKcalPerMin: Double)
    case singleCardio(CardioEnergyResult, restingResult: RestingEnergyResult)

    var id: String {
        switch self {
        case .resting:          return "resting"
        case .everydayActivity: return "everyday"
        case .workoutsDay:      return "workoutsDay"
        case .totalBurn:        return "totalBurn"
        case .singleWorkout:    return "singleWorkout"
        case .cardioDay:        return "cardioDay"
        case .singleCardio:     return "singleCardio"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .resting:          return "How resting energy is estimated"
        case .everydayActivity: return "How everyday activity energy is estimated"
        case .workoutsDay:      return "How workout energy is estimated"
        case .totalBurn:        return "How total energy burn is estimated"
        case .singleWorkout:    return "How this workout's energy is estimated"
        case .cardioDay:        return "How cardio energy is estimated"
        case .singleCardio:     return "How this cardio session's energy is estimated"
        }
    }
}

// MARK: - Reusable ⓘ button

struct InfoButton: View {
    let content: EnergySheetContent
    let unit: EnergyUnit
    var weightUnit: WeightUnit = .kg
    @State private var showInfo = false
    @State private var showFull = false

    var body: some View {
        Button { showInfo = true } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 16))
                .foregroundStyle(Color.ssTextMuted)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(content.accessibilityLabel)
        .sheet(isPresented: $showInfo) {
            EnergyInfoSheetView(content: content, unit: unit, weightUnit: weightUnit, showFull: $showFull)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showFull) {
            FullExplanationSheet(energyUnit: unit)
        }
    }
}

// MARK: - Main sheet view

struct EnergyInfoSheetView: View {
    let content: EnergySheetContent
    let unit: EnergyUnit
    var weightUnit: WeightUnit = .kg
    @Binding var showFull: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleAndDescription
                    formulaBlock
                    summaryLine
                    disclaimer
                    fullMethodButton
                }
                .padding(24)
            }
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.ssAccent)
                }
            }
        }
    }

    // MARK: Title + description

    @ViewBuilder
    private var titleAndDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sheetTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.ssTextPrimary)
            Text(sheetDescription)
                .font(.subheadline)
                .foregroundStyle(Color.ssTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let extra = sheetExtra {
                Text(extra)
                    .font(.subheadline)
                    .foregroundStyle(Color.ssTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Formula block

    private var formulaBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(formulaLines, id: \.self) { line in
                Text(line)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Color.ssTextPrimary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ssSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ssBorder, lineWidth: 1))
    }

    // MARK: Summary line

    private var summaryLine: some View {
        HStack(spacing: 4) {
            Text(summaryPrefix)
                .font(.subheadline)
                .foregroundStyle(Color.ssTextSecondary)
            Text(summaryValue)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.ssTextPrimary)
        }
    }

    // MARK: Disclaimer

    private var disclaimer: some View {
        Text("This is an estimate from published equations, not a measurement. Your real number may be 10% or more higher or lower.")
            .font(.caption)
            .foregroundStyle(Color.ssTextMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Full method button

    private var fullMethodButton: some View {
        Button {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showFull = true
            }
        } label: {
            HStack {
                Text("Full method and sources →")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ssAccent)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content helpers

    private var sheetTitle: String {
        switch content {
        case .resting:          return "Resting energy (BMR)"
        case .everydayActivity: return "Everyday activity"
        case .workoutsDay:      return "Workouts"
        case .totalBurn:        return "Estimated burn"
        case .singleWorkout:    return "Workout energy"
        case .cardioDay:        return "Cardio"
        case .singleCardio:     return "Cardio energy"
        }
    }

    private var sheetDescription: String {
        switch content {
        case .resting(let r, let stats):
            switch r.method {
            case .cunningham:
                let bf = String(format: "%.1f", stats.bodyFatPct ?? 0)
                return "The energy your body uses at rest. Worked out with the Cunningham equation from your fat-free mass: your weight minus fat, using your body fat reading of \(bf)%."
            case .mifflin:
                return "The energy your body uses at rest. Worked out with the Mifflin-St Jeor equation from your weight, height and age. Log a body fat % on Progress to base it on your fat-free mass instead."
            case .mifflinAverage:
                return "The energy your body uses at rest. Worked out with the Mifflin-St Jeor equation from your weight, height and age, using the average of the male and female versions because sex isn't set. Log a body fat % on Progress to base it on your fat-free mass instead."
            }
        case .everydayActivity(_, let pal, let activity, let assumed):
            let actLabel = activity?.label ?? "mostly sitting"
            let suffix = assumed ? ", assumed until you choose one" : ""
            return "Walking, standing, chores and digesting food, but not logged workouts. Worked out from your resting energy and an activity level of \(String(format: "%.2f", pal)) (\(actLabel)\(suffix))."
        case .workoutsDay(_, let met, let effort, let weightKg, _):
            return "Each workout logged on this day counts \(String(format: "%g", met)) METs for \(effort.rawValue) weight training (2024 Compendium of Physical Activities) for its length, at your weight of \(String(format: "%.1f", weightKg)) kg. Only the energy above resting counts, because resting is already in the total."
        case .totalBurn:
            return "Your estimated burn for the whole day is four estimates added together."
        case .singleWorkout(let wf):
            var parts: [String] = []
            if wf.weightsMinutes > 0 {
                var desc = "Weight training: \(String(format: "%g", wf.weightsMet)) METs for \(wf.weightsEffort.rawValue) (2024 Compendium of Physical Activities), your weight of \(String(format: "%.1f", wf.weightKg)) kg and \(String(format: "%g", wf.weightsMinutes)) min. Resting energy is subtracted because it's counted separately."
                if wf.weightsCapped { desc += " Capped at 3 hours." }
                parts.append(desc)
            }
            if !wf.cardioEstimates.isEmpty {
                parts.append("Each cardio exercise is estimated separately from the 2024 Compendium of Physical Activities.")
            }
            return parts.isEmpty ? "No energy logged for this workout." : parts.joined(separator: " ")
        case .cardioDay:
            return "Each cardio session logged on this day gets a MET value from the 2024 Compendium of Physical Activities. For runs, walks and outdoor rides with a distance, the value comes from your average speed. Otherwise it comes from the effort you chose. Only the energy above resting counts."
        case .singleCardio(let r, _):
            return cardioSessionDescription(r)
        }
    }

    private func cardioSessionDescription(_ r: CardioEnergyResult) -> String {
        switch r.metSource {
        case .speed(let row, let speedKmh):
            let speedStr: String
            if weightUnit == .lb {
                speedStr = String(format: "%.1f mph", speedKmh / 1.609344)
            } else {
                speedStr = String(format: "%.1f km/h", speedKmh)
            }
            return "Your average speed was \(speedStr). The closest row in the 2024 Compendium of Physical Activities is \"\(row.description)\" (code \(row.code)), which is \(String(format: "%g", row.met)) METs."
        case .effort(let row, let defaulted):
            if defaulted {
                return "No effort was chosen, so the middle option is used: \"\(row.description)\" in the 2024 Compendium of Physical Activities (code \(row.code)), which is \(String(format: "%g", row.met)) METs."
            } else {
                return "You chose an effort that matches \"\(row.description)\" in the 2024 Compendium of Physical Activities (code \(row.code)), which is \(String(format: "%g", row.met)) METs."
            }
        case .custom(let m):
            return "You entered \(String(format: "%g", m)) METs for this activity."
        }
    }

    private var sheetExtra: String? {
        switch content {
        case .everydayActivity: return "The levels are 1.4, 1.55 and 1.75."
        case .workoutsDay:      return "Change workout effort in Settings."
        case .totalBurn:        return "The ± figure is 10%, because these equations are usually within about 10% for most people. For some people they're further off."
        case .cardioDay:        return "Tap a session in History to see how its estimate was worked out."
        case .singleCardio:     return "Hills, wind, heat and your fitness change the real number, and they aren't counted."
        default:                return nil
        }
    }

    private var formulaLines: [String] {
        switch content {
        case .resting(let r, let stats):
            switch r.method {
            case .cunningham(let ffm):
                let bf  = String(format: "%.1f", stats.bodyFatPct ?? 0)
                let w   = String(format: "%.1f", stats.weightKg)
                let f   = String(format: "%.1f", ffm)
                let res = formatThousands(Int(r.kcalPerDay.rounded()))
                return ["\(w) kg × (1 − \(bf)%) = \(f) kg fat-free",
                        "500 + 22 × \(f) = \(res) kcal/day"]
            case .mifflin, .mifflinAverage:
                let w   = String(format: "%.1f", stats.weightKg)
                let h   = String(format: "%.1f", stats.heightCm ?? 0)
                let age = stats.age ?? 0
                let s: String
                switch stats.sex {
                case .male:   s = "+ 5"
                case .female: s = "− 161"
                case nil:     s = "− 78"
                }
                let res = formatThousands(Int(r.kcalPerDay.rounded()))
                return ["10 × \(w) kg + 6.25 × \(h) cm − 5 × \(age) yrs \(s)",
                        "= \(res) kcal/day"]
            }

        case .everydayActivity(let restKcal, let pal, _, _):
            let r = formatThousands(Int(restKcal.rounded()))
            let p = String(format: "%.2f", pal)
            let e = formatThousands(Int((restKcal * (pal - 1)).rounded()))
            return ["\(r) kcal × (\(p) − 1) = \(e) kcal"]

        case .workoutsDay(let workKcal, let met, _, let w, let restPerMin):
            let g = String(format: "%.1f", met * 3.5 * w / 200)
            let r = String(format: "%.2f", restPerMin)
            let result = formatThousands(Int(workKcal.rounded()))
            return ["(MET × 3.5 × \(String(format: "%.1f", w)) kg ÷ 200 − \(r) resting) × min",
                    "gross \(g) − rest \(r) = \(result) kcal"]

        case .totalBurn(let c):
            let rest     = formatThousands(Int(c.restingKcal.rounded()))
            let everyday = formatThousands(Int(c.everydayKcal.rounded()))
            let workout  = formatThousands(Int(c.workoutKcal.rounded()))
            let cardio   = formatThousands(Int(c.cardioKcal.rounded()))
            let total    = formatThousands(Int(c.totalKcal.rounded()))
            return ["resting \(rest) + everyday \(everyday) + workouts \(workout) +",
                    "cardio \(cardio)",
                    "= \(total) kcal"]

        case .singleWorkout(let wf):
            var lines: [String] = []
            if wf.weightsMinutes > 0 {
                let g   = String(format: "%.1f", wf.weightsMet * 3.5 * wf.weightKg / 200)
                let res = String(format: "%.2f", wf.restingKcalPerMin)
                let min = String(format: "%g",   wf.weightsMinutes)
                let tot = formatThousands(Int(wf.weightsKcal.rounded()))
                lines += ["Weights: (\(String(format: "%g", wf.weightsMet)) × 3.5 × \(String(format: "%.1f", wf.weightKg)) ÷ 200 − \(res)) × \(min) min",
                          "= (\(g) − \(res)) × \(min) = \(tot) kcal"]
            }
            for (name, est) in wf.cardioEstimates {
                if case .result(let r) = est {
                    let min = String(format: "%.1f", r.minutes)
                    let tot = formatThousands(Int(r.kcal.rounded()))
                    lines.append("\(name): \(String(format: "%g", r.met)) MET × \(min) min = \(tot) kcal")
                }
            }
            if !lines.isEmpty && wf.weightsMinutes > 0 && !wf.cardioEstimates.isEmpty {
                lines.append("Total = \(formatThousands(Int(wf.totalKcal.rounded()))) kcal")
            }
            return lines.isEmpty ? ["No energy data"] : lines

        case .cardioDay(let kcal, let w, let restPerMin):
            let g   = String(format: "%.1f", 5.0 * 3.5 * w / 200)  // example MET
            let res = String(format: "%.2f", restPerMin)
            let tot = formatThousands(Int(kcal.rounded()))
            return ["(MET × 3.5 × \(String(format: "%.1f", w)) kg ÷ 200 − \(res) resting) × min",
                    "= \(tot) kcal total"]

        case .singleCardio(let r, _):
            let g   = String(format: "%.2f", r.met * 3.5 * r.weightKg / 200)
            let res = String(format: "%.2f", r.restingKcalPerMin)
            let min = String(format: "%.1f", r.minutes)
            let tot = formatThousands(Int(r.kcal.rounded()))
            return ["(\(String(format: "%g", r.met)) × 3.5 × \(String(format: "%.1f", r.weightKg)) ÷ 200 − \(res) resting) × \(min) min",
                    "= (\(g) − \(res)) × \(min) = \(tot) kcal"]
        }
    }

    private var summaryPrefix: String {
        switch content {
        case .resting:          return "Resting energy:"
        case .everydayActivity: return "Everyday activity:"
        case .workoutsDay:      return "Workouts:"
        case .totalBurn:        return "Total:"
        case .singleWorkout:    return "This workout:"
        case .cardioDay:        return "Cardio:"
        case .singleCardio:     return "This session:"
        }
    }

    private var summaryValue: String {
        let kcal: Double
        switch content {
        case .resting(let r, _):                              kcal = r.kcalPerDay
        case .everydayActivity(let restKcal, let pal, _, _):  kcal = restKcal * (pal - 1)
        case .workoutsDay(let wk, _, _, _, _):                kcal = wk
        case .totalBurn(let c):                               kcal = c.totalKcal
        case .singleWorkout(let wf):                          kcal = wf.totalKcal
        case .cardioDay(let ck, _, _):                        kcal = ck
        case .singleCardio(let r, _):                         kcal = r.kcal
        }
        let suffix: String
        switch content {
        case .resting:                   suffix = " a day."
        case .singleWorkout, .singleCardio: suffix = " above resting."
        default:                         suffix = "."
        }
        return formatEnergyEstimateBoth(kcal) + suffix
    }
}
