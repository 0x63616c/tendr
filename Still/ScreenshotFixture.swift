import Foundation

/// Synthetic journal for App Store screenshots (`--screenshots`, plus `--dark` for dark mode).
/// Plain mg doses under a generic medication name: no brand names, vials or syringe units.
extension Store {
    static var screenshotRun: Bool { ProcessInfo.processInfo.arguments.contains("--screenshots") }

    static func screenshotJournal(now: Date = Date(), calendar: Calendar = .current) -> Journal {
        var journal = Journal()
        journal.medication = "Weekly medication"
        journal.medicationModel = .halfLife
        journal.halfLifeDays = 7
        journal.unit = .lb
        journal.appearance = ProcessInfo.processInfo.arguments.contains("--dark") ? "dark" : "light"

        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int, hour: Int, minute: Int) -> Date {
            calendar.date(byAdding: DateComponents(day: offset, hour: hour, minute: minute), to: today)!
        }

        // Ten weekly doses; the latest was six days ago so the next one is tomorrow morning.
        let doseCount = 10
        let lastDose = -6
        let firstDose = lastDose - 7 * (doseCount - 1)
        let notes = [0: "First week. Starting slow.", 4: "Moved up as planned with my care team.", 9: "Easy morning. Water bottle close by."]
        journal.doses = (0..<doseCount).map { index in
            DoseEntry(
                date: day(firstDose + 7 * index, hour: 8, minute: 30),
                medication: journal.medication,
                milligrams: index < 4 ? 2.5 : 5,
                note: notes[index] ?? ""
            )
        }
        journal.schedule.weekdays = [calendar.component(.weekday, from: day(1, hour: 0, minute: 0))]
        journal.schedule.startDate = day(firstDose, hour: 0, minute: 0)
        journal.schedule.hour = 8
        journal.schedule.minute = 30
        journal.schedule.enabled = true

        // Morning weigh-ins every two or three days, easing down with day-to-day noise.
        let startPounds = 212.4
        let totalLoss = 16.2
        let noise: [Double] = [0, 0.4, -0.3, 0.2, -0.5, 0.3, 0.1, -0.2, 0.5, -0.1, 0.2, -0.4, 0.3, 0, -0.3, 0.4, -0.2, 0.1, 0.3, -0.1, 0.2, -0.3, 0.1, 0, 0.2, -0.2, 0.1, 0]
        var offset = firstDose + 1
        var weights: [WeightEntry] = []
        var index = 0
        while offset < 0 {
            let progress = Double(offset - firstDose) / Double(-firstDose)
            let pounds = startPounds - totalLoss * (1 - exp(-2.2 * progress)) / (1 - exp(-2.2)) + noise[index % noise.count]
            weights.append(WeightEntry(date: day(offset, hour: 7, minute: 15), kilograms: (pounds * 10).rounded() / 10 / 2.2046226218))
            offset += index % 3 == 2 ? 3 : 2
            index += 1
        }
        if let last = weights.indices.last { weights[last].note = "Feeling more like myself. A long walk this morning." }
        journal.weights = weights
        journal.goal = WeightGoal(kilograms: 185 / 2.2046226218, date: nil)
        return journal
    }
}
