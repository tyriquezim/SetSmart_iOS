import SwiftUI

// MARK: - Sheet content enum

enum EnergySheetContent: Identifiable, Sendable {
    case resting(RestingEnergyResult, stats: BodyStats)
    case everydayActivity(restingKcal: Double, pal: Double, activity: DailyActivity?, assumed: Bool)
    case workoutsDay(workoutKcal: Double, met: Double, effort: WorkoutEffort, weightKg: Double, restingKcalPerMin: Double)
    case totalBurn(DayEnergyComponents)
    case singleWorkout(WorkoutEnergyResult, restingResult: RestingEnergyResult)

    var id: String {
        switch self {
        case .resting:          return "resting"
        case .everydayActivity: return "everyday"
        case .workoutsDay:      return "workoutsDay"
        case .totalBurn:        return "totalBurn"
        case .singleWorkout:    return "singleWorkout"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .resting:          return "How resting energy is estimated"
        case .everydayActivity: return "How everyday activity energy is estimated"
        case .workoutsDay:      return "How workout energy is estimated"
        case .totalBurn:        return "How total energy burn is estimated"
        case .singleWorkout:    return "How this workout's energy is estimated"
        }
    }
}

// MARK: - Reusable ⓘ button

struct InfoButton: View {
    let content: EnergySheetContent
    let unit: EnergyUnit
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
            EnergyInfoSheetView(content: content, unit: unit, showFull: $showFull)
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
        case .resting(let r, _):
            switch r.method {
            case .cunningham: return "Resting energy (BMR)"
            case .mifflin, .mifflinAverage: return "Resting energy (BMR)"
            }
        case .everydayActivity: return "Everyday activity"
        case .workoutsDay:      return "Workouts"
        case .totalBurn:        return "Estimated burn"
        case .singleWorkout:    return "Workout energy"
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
            return "Your estimated burn for the whole day is three estimates added together."
        case .singleWorkout(let r, _):
            var desc = "Based on \(String(format: "%g", r.met)) METs for \(r.effort.rawValue) weight training (2024 Compendium of Physical Activities), your weight of \(String(format: "%.1f", r.weightKg)) kg and the workout's length. Resting energy is subtracted because it's counted separately."
            if r.capped { desc += " It ran longer than 3 hours, so only 3 hours are counted." }
            return desc
        }
    }

    private var sheetExtra: String? {
        switch content {
        case .everydayActivity: return "The levels are 1.4, 1.55 and 1.75."
        case .workoutsDay:      return "Change workout effort in Settings."
        case .totalBurn:        return "The ± figure is 10%, because these equations are usually within about 10% for most people. For some people they're further off."
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
            let total    = formatThousands(Int(c.totalKcal.rounded()))
            return ["resting \(rest) + everyday \(everyday) + workouts \(workout)",
                    "= \(total) kcal"]

        case .singleWorkout(let r, _):
            let g   = String(format: "%.1f", r.met * 3.5 * r.weightKg / 200)
            let res = String(format: "%.2f", r.restingKcalPerMin)
            let min = String(format: "%g",   r.minutes)
            let net = String(format: "%.2f", r.kcal / max(r.minutes, 1))
            let tot = formatThousands(Int(r.kcal.rounded()))
            return ["(\(r.met) × 3.5 × \(String(format: "%.1f", r.weightKg)) ÷ 200 − \(res) resting) × \(min) min",
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
        }
    }

    private var summaryValue: String {
        let kcal: Double
        switch content {
        case .resting(let r, _):         kcal = r.kcalPerDay
        case .everydayActivity(let restKcal, let pal, _, _): kcal = restKcal * (pal - 1)
        case .workoutsDay(let wk, _, _, _, _): kcal = wk
        case .totalBurn(let c):          kcal = c.totalKcal
        case .singleWorkout(let r, _):   kcal = r.kcal
        }
        let suffix: String
        switch content {
        case .resting:       suffix = " a day."
        case .singleWorkout: suffix = " above resting."
        default:             suffix = "."
        }
        return formatEnergyEstimateBoth(kcal) + suffix
    }
}
