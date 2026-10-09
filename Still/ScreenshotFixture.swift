import Foundation

extension Store {
    /// Synthetic journal for App Store screenshots (`--demo --screenshots`): twelve weeks of plain mg doses
    /// under a generic medication name, steady weigh-ins and a goal. No vials, syringe units or brand names.
    static func screenshotJournal(now: Date = Date(), calendar cal: Calendar = .current) -> Journal {
        var journal = Journal()
        journal.medication = "Weekly medication"
        journal.medicationModel = .halfLife
        journal.halfLifeDays = 7
        journal.unit = .lb
        let today = cal.startOfDay(for: now)
        func day(_ offset: Int, hour: Int, minute: Int) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: cal.date(byAdding: .day, value: offset, to: today)!)!
        }

        // Weekly doses stepping up 0.25 → 0.5 → 1 mg; the latest was five days ago, so the next is in two.
        let amounts: [Double] = [0.25, 0.25, 0.25, 0.25, 0.5, 0.5, 0.5, 0.5, 1, 1, 1, 1]
        let notes = [11: "Felt good. Easy walk after dinner.", 8: "Slept well, appetite settled.", 4: "First week at 0.5 mg."]
        journal.doses = amounts.enumerated().map { index, milligrams in
            let weeksAgo = amounts.count - 1 - index
            return DoseEntry(date: day(-5 - weeksAgo * 7, hour: 8, minute: 30), medication: journal.medication, milligrams: milligrams, note: notes[index] ?? "")
        }
        let firstDose = journal.doses[0].date
        journal.schedule.weekdays = [cal.component(.weekday, from: day(2, hour: 8, minute: 30))]
        journal.schedule.hour = 8
        journal.schedule.minute = 30
        journal.schedule.startDate = cal.startOfDay(for: firstDose)
        journal.schedule.enabled = true

        // 217 lbs easing to 199 lbs with day-to-day noise, weighed every three days after the first dose
        // and ending yesterday, so no entry is in the future whatever time the capture runs.
        let pounds = 2.2046226218
        let span = cal.dateComponents([.day], from: cal.startOfDay(for: firstDose), to: today).day! - 1
        journal.weights = stride(from: span, through: 0, by: -3).reversed().map { elapsed in
            let progress = Double(elapsed) / Double(span)
            let trend = 217 - 18 * (1 - pow(1 - progress, 1.6))
            let noise = 0.7 * sin(Double(elapsed) * 1.7) + 0.35 * cos(Double(elapsed) * 0.9)
            let lbs = elapsed == 0 ? 217.0 : elapsed == span ? 199.0 : (trend + noise * (1 - progress)).rounded(toPlaces: 1)
            return WeightEntry(date: day(elapsed - span - 1, hour: 9, minute: 10), kilograms: lbs / pounds, note: elapsed == span ? "Lowest yet. Jeans fit better." : "")
        }
        journal.goal = WeightGoal(kilograms: 185 / pounds, date: cal.date(byAdding: .day, value: 90, to: today))
        journal.weightsStartAtFirstDose = true
        return journal
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let scale = pow(10, Double(places))
        return (self * scale).rounded() / scale
    }
}
