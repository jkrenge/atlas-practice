import Foundation
import Observation

enum PracticeMode: String, Codable, CaseIterable, Identifiable {
    case find, name
    var id: String { rawValue }
    var title: String { self == .find ? "Find the area" : "Name the area" }
    var instruction: String { self == .find ? "Read a name. Find its place on the map." : "Look at the highlighted area. Choose its name." }
    var symbol: String { self == .find ? "hand.tap" : "text.bubble" }
}

struct PracticeSession {
    struct Question: Identifiable {
        let id = UUID()
        let area: Area
        let isReview: Bool
        let choices: [Area]
    }
    struct Answer {
        let selected: Area?
        let correct: Bool
    }
    private(set) var questions: [Question]
    private(set) var index = 0
    private(set) var answer: Answer?
    private(set) var firstAttemptCorrect = 0
    private(set) var reviewedCorrect = 0
    private(set) var missed: [Area] = []
    let mode: PracticeMode
    let primaryCount: Int
    var isComplete: Bool { index >= questions.count }
    var current: Question? { isComplete ? nil : questions[index] }
    var answeredCount: Int { index + (answer == nil ? 0 : 1) }

    init(areas: [Area], mode: PracticeMode, count: Int = 6, ordered: Bool = false) {
        self.mode = mode
        let pool = ordered ? areas : areas.shuffled()
        primaryCount = min(count, pool.count)
        questions = pool.prefix(primaryCount).map { area in
            let distractors = (ordered ? areas : areas.shuffled()).filter { $0 != area }.prefix(3)
            let choices = ([area] + distractors)
            return Question(area: area, isReview: false, choices: ordered ? choices : choices.shuffled())
        }
    }

    mutating func submit(_ selected: Area?) {
        guard let question = current, answer == nil else { return }
        let correct = selected == question.area
        answer = Answer(selected: selected, correct: correct)
        if question.isReview {
            if correct { reviewedCorrect += 1 }
        } else if correct {
            firstAttemptCorrect += 1
        } else {
            missed.append(question.area)
            // Revisit once, after two other questions when the queue allows it.
            questions.insert(Question(area: question.area, isReview: true, choices: question.choices),
                             at: min(index + 3, questions.count))
        }
    }

    mutating func advance() {
        guard answer != nil else { return }
        index += 1
        answer = nil
    }
}

struct PracticeRecord: Codable, Equatable {
    var sessions = 0
    var firstCorrect = 0
    var firstTotal = 0
    var reviewCorrect = 0
    var reviewTotal = 0
}

@MainActor
@Observable
final class ProgressStore {
    private let defaults: UserDefaults
    private(set) var records: [String: PracticeRecord]
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        records = defaults.data(forKey: "practiceProgress.v1")
            .flatMap { try? JSONDecoder().decode([String: PracticeRecord].self, from: $0) } ?? [:]
    }
    func record(for map: String, mode: PracticeMode) -> PracticeRecord {
        records[map + "." + mode.rawValue] ?? PracticeRecord()
    }
    func save(_ session: PracticeSession, map: String) {
        guard session.isComplete else { return }
        let key = map + "." + session.mode.rawValue
        var record = records[key] ?? PracticeRecord()
        record.sessions += 1
        record.firstCorrect += session.firstAttemptCorrect
        record.firstTotal += session.primaryCount
        record.reviewCorrect += session.reviewedCorrect
        record.reviewTotal += session.missed.count
        records[key] = record
        if let data = try? JSONEncoder().encode(records) { defaults.set(data, forKey: "practiceProgress.v1") }
    }
}
