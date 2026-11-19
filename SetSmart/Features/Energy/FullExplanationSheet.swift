import SwiftUI

struct FullExplanationSheet: View {
    let energyUnit: EnergyUnit
    var components: DayEnergyComponents? = nil   // when opened with a specific day's data

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introBox
                    restingSection
                    everydaySection
                    workoutsSection
                    cardioSection
                    whoDoesntSuit
                    sourcesSection
                }
                .padding(24)
            }
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("How energy estimates work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.ssAccent)
                }
            }
        }
    }

    // MARK: - Sections

    private var introBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("These numbers are **estimates from published equations, not measurements**. They're based on averages from groups of people, so your real energy use can be 10% or more higher or lower. Use them as a guide, and adjust based on how your weight actually changes over a few weeks.")
                .font(.subheadline)
                .foregroundStyle(Color.ssTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.ssSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ssBorder, lineWidth: 1))
    }

    private var restingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Resting energy (BMR)")
            Text("The energy your body uses just to keep you alive — breathing, circulation, organ function.")
                .font(.subheadline)
                .foregroundStyle(Color.ssTextSecondary)
            if let c = components {
                Text("Yours: about \(formatEnergyEstimate(c.restingKcal, unit: energyUnit)) a day, using the \(restingMethodName(c.restingResult.method)).")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ssTextPrimary)
            }

            expandable(title: "Cunningham equation [3, 4]",
                       body: "Used when a body fat % was logged within 90 days. Fat-free mass (FFM) is muscle, organs, bone and water — everything except fat.\n\nFormula: 500 + 22 × FFM (kg)")

            expandable(title: "Mifflin-St Jeor equation [1, 2]",
                       body: "Used when no recent body fat % is available. A systematic review found it most often within 10% of measured resting energy in healthy adults.\n\nFormula: 10 × weight + 6.25 × height − 5 × age + s\nwhere s = +5 (male), −161 (female), −78 (not set)")

            Text("Note on smart scale 'muscle mass': readings vary by brand and method, so we use body fat % to derive fat-free mass instead. Home scales can be a few percent out, which changes resting energy by roughly 2–3%.")
                .font(.caption)
                .foregroundStyle(Color.ssTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var everydaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Everyday activity")
            Text("Walking, standing, chores and digesting food outside of logged workouts. Uses a physical activity level (PAL) multiplied by resting energy.")
                .font(.subheadline)
                .foregroundStyle(Color.ssTextSecondary)
            if let c = components {
                let palStr = String(format: "%.2f", c.pal)
                let assumed = c.activityAssumed ? " (assumed — tap Settings to update)" : ""
                Text("Yours: PAL \(palStr)\(assumed), about \(formatEnergyEstimate(c.everydayKcal, unit: energyUnit)) on top of resting.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ssTextPrimary)
            }
            paLTable
            Text("This is the least certain part of the estimate. The PAL levels come from FAO/WHO/UNU [6].")
                .font(.caption)
                .foregroundStyle(Color.ssTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var paLTable: some View {
        VStack(spacing: 0) {
            tableRow(label: "Mostly sitting",             pal: "1.40", hint: "Desk job, little walking")
            Divider().background(Color.ssBorder)
            tableRow(label: "Mix of sitting and moving", pal: "1.55", hint: "Some walking/standing")
            Divider().background(Color.ssBorder)
            tableRow(label: "On your feet most of day",  pal: "1.75", hint: "Retail, nursing, trades")
        }
        .background(Color.ssSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ssBorder, lineWidth: 1))
    }

    private func tableRow(label: String, pal: String, hint: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline.weight(.medium))
                Text(hint).font(.caption).foregroundStyle(Color.ssTextMuted)
            }
            Spacer()
            Text("PAL \(pal)").font(.subheadline.monospacedDigit()).foregroundStyle(Color.ssTextSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Workouts")
            Text("Each logged workout is estimated using MET values from the 2024 Compendium of Physical Activities [5]. Only the energy above resting is counted, so it isn't double-counted in the daily total.")
                .font(.subheadline)
                .foregroundStyle(Color.ssTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let c = components, c.workoutKcal > 0 {
                Text("Yours: about \(formatEnergyEstimate(c.workoutKcal, unit: energyUnit)) from workouts today.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ssTextPrimary)
            }
            metTable
            Text("Formula: (MET × 3.5 × weight ÷ 200 − resting kcal/min) × minutes\n\nSessions are counted for at most 3 hours. Weight training burns less than it feels like it does, and how hard you work changes it a lot.")
                .font(.caption)
                .foregroundStyle(Color.ssTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var metTable: some View {
        VStack(spacing: 0) {
            tableRow(label: "Moderate", pal: "3.5 MET", hint: "8–15 reps, normal rests")
            Divider().background(Color.ssBorder)
            tableRow(label: "Vigorous", pal: "6.0 MET", hint: "Heavy lifting, short rests")
        }
        .background(Color.ssSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ssBorder, lineWidth: 1))
    }

    private var cardioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Cardio")
            Text("Each cardio session also uses a MET value from the 2024 Compendium of Physical Activities, with the same formula as workouts. Only the energy above resting counts, and cardio duration is not capped at 3 hours.")
                .font(.subheadline)
                .foregroundStyle(Color.ssTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let c = components, c.cardioKcal > 0 {
                Text("Yours: about \(formatEnergyEstimate(c.cardioKcal, unit: energyUnit)) from cardio today.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ssTextPrimary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("How the MET is picked:")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ssTextPrimary)
                Text("• **Runs, walks and outdoor rides with a distance:** average speed (distance ÷ time) picks the closest Compendium row.")
                    .font(.caption)
                    .foregroundStyle(Color.ssTextSecondary)
                Text("• **Everything else:** the effort you chose picks a row, e.g. \"Elliptical, vigorous effort\" (9 METs).")
                    .font(.caption)
                    .foregroundStyle(Color.ssTextSecondary)
                Text("• **Other activities:** enter a MET value from the Compendium.")
                    .font(.caption)
                    .foregroundStyle(Color.ssTextSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ssSurface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ssBorder, lineWidth: 1))
            Text("The speed rows assume flat ground, so hills, wind and heat aren't counted. Fitter people use a bit less energy at the same speed. [5]")
                .font(.caption)
                .foregroundStyle(Color.ssTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var whoDoesntSuit: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Who these don't suit")
            Text("These equations were developed for healthy adults. The estimates are less reliable if you are under 18, pregnant or breastfeeding, have a medical condition or medication that affects metabolism, or are a very high-level athlete. For accurate numbers, see a dietitian or doctor.")
                .font(.subheadline)
                .foregroundStyle(Color.ssTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Sources")
            ForEach(energySources, id: \.number) { src in
                VStack(alignment: .leading, spacing: 4) {
                    Text("[\(src.number)] \(src.citation)")
                        .font(.caption)
                        .foregroundStyle(Color.ssTextSecondary)
                    Link(src.doi, destination: URL(string: src.doi)!)
                        .font(.caption)
                        .foregroundStyle(Color.ssAccent)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(Color.ssTextPrimary)
    }

    private func expandable(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ssTextPrimary)
            Text(body)
                .font(.caption)
                .foregroundStyle(Color.ssTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ssSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ssBorder, lineWidth: 1))
    }

    private func restingMethodName(_ method: RestingEnergyResult.Method) -> String {
        switch method {
        case .cunningham:    return "Cunningham equation"
        case .mifflin:       return "Mifflin-St Jeor equation"
        case .mifflinAverage: return "Mifflin-St Jeor equation (average)"
        }
    }
}
