import Foundation
import Observation

enum PracticeMode: String, Codable, CaseIterable, Identifiable {
    case find, name, capital, flag, nickname, capitalLocation, cityLocation, population, landmarkLocation
    var id: String { rawValue }
    var title: String {
        switch self {
        case .find: "Find the area"
        case .name: "Name the area"
        case .capital: "State capitals"
        case .flag: "State flags"
        case .nickname: "Nicknames & slogans"
        case .capitalLocation: "Locate capitals"
        case .cityLocation: "Locate cities"
        case .population: "City populations"
        case .landmarkLocation: "Locate landmarks"
        }
    }
    var instruction: String {
        switch self {
        case .find: "Read a name. Find its place on the map."
        case .name: "Look at the highlighted area. Choose its name."
        case .capital: "Match each state to its capital."
        case .flag: "Recognize the state from its flag."
        case .nickname: "Connect a name or campaign slogan to a state."
        case .capitalLocation: "Drop a pin at a state capital."
        case .cityLocation: "Find the largest cities on the map."
        case .population: "Choose a city's population from dated official figures."
        case .landmarkLocation: "Place famous sights on the map."
        }
    }
    var symbol: String {
        switch self {
        case .find: "hand.tap"
        case .name: "text.bubble"
        case .capital: "building.columns"
        case .flag: "flag"
        case .nickname: "quote.bubble"
        case .capitalLocation, .cityLocation: "mappin.and.ellipse"
        case .population: "person.3"
        case .landmarkLocation: "binoculars"
        }
    }
    var isLocation: Bool { [.capitalLocation, .cityLocation, .landmarkLocation].contains(self) }
    var usesMap: Bool { self == .find || self == .name || isLocation }
    static func available(in pack: MapPack) -> [Self] {
        ["us-states", "germany-states"].contains(pack.id) ? allCases : [.find, .name]
    }
}

struct QuestionTimer {
    private(set) var remaining: TimeInterval
    private var lastTick: TimeInterval?
    var expired: Bool { remaining <= 0 }
    init(seconds: Int) { remaining = Double(seconds) }
    mutating func resume(now: TimeInterval) { lastTick = now }
    mutating func tick(now: TimeInterval) {
        guard let lastTick else { return }
        remaining = max(0, remaining - max(0, now - lastTick))
        self.lastTick = now
    }
    mutating func pause(now: TimeInterval) { tick(now: now); lastTick = nil }
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
        var guess: MapPin? = nil
        var distanceKM: Double? = nil
        var timedOut = false
    }
    private(set) var questions: [Question]
    private(set) var index = 0
    private(set) var answer: Answer?
    private(set) var firstAttemptCorrect = 0
    private(set) var reviewedCorrect = 0
    private(set) var missed: [Area] = []
    let mode: PracticeMode
    let primaryCount: Int
    let secondsAllowed: Int
    var isComplete: Bool { index >= questions.count }
    var current: Question? { isComplete ? nil : questions[index] }
    var answeredCount: Int { index + (answer == nil ? 0 : 1) }

    init(areas: [Area], mode: PracticeMode, count: Int = 6, ordered: Bool = false, secondsAllowed: Int = 0) {
        self.mode = mode
        self.secondsAllowed = secondsAllowed
        let pool = ordered ? areas : areas.shuffled()
        primaryCount = min(count, pool.count)
        questions = pool.prefix(primaryCount).map { area in
            let distractors = (ordered ? areas : areas.shuffled()).filter { $0 != area }.prefix(3)
            let choices = ([area] + distractors)
            return Question(area: area, isReview: false, choices: ordered ? choices : choices.shuffled())
        }
    }

    mutating func submit(_ selected: Area?) {
        guard let question = current else { return }
        record(Answer(selected: selected, correct: selected == question.area))
    }

    mutating func submitLocation(_ guess: MapPin, target: MapPin, toleranceKM: Double) {
        let distance = guess.coordinate.distanceKM(to: target.coordinate)
        record(Answer(selected: nil, correct: distance <= toleranceKM, guess: guess, distanceKM: distance))
    }

    mutating func expire() { record(Answer(selected: nil, correct: false, timedOut: true)) }

    private mutating func record(_ result: Answer) {
        guard let question = current, answer == nil else { return }
        answer = result
        if question.isReview {
            if result.correct { reviewedCorrect += 1 }
        } else if result.correct {
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
    func record(for map: String, mode: PracticeMode, secondsAllowed: Int = 0) -> PracticeRecord {
        records[key(map, mode, secondsAllowed)] ?? PracticeRecord()
    }
    private func key(_ map: String, _ mode: PracticeMode, _ seconds: Int) -> String {
        map + "." + mode.rawValue + (seconds == 0 ? "" : ".\(seconds)s")
    }
    func save(_ session: PracticeSession, map: String) {
        guard session.isComplete else { return }
        let key = key(map, session.mode, session.secondsAllowed)
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
