import Foundation
import Observation

enum PracticeMode: String, Codable, CaseIterable, Identifiable {
    case find, name, capital, flag, nickname, capitalLocation, cityLocation, population, landmarkLocation, challenge
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
        case .challenge: "Beat the clock"
        }
    }
    var instruction: String {
        switch self {
        case .find: "We name it, you find it."
        case .name: "We point, you name it."
        case .capital: "Not always the biggest city."
        case .flag: "Seals, stripes, and the odd bear."
        case .nickname: "Every state has a catchphrase."
        case .capitalLocation: "Pin the capital. Close counts."
        case .cityLocation: "Big cities, tiny dots."
        case .population: "Guess the headcount. Official figures."
        case .landmarkLocation: "Famous sights. Where exactly?"
        case .challenge: "Pin each place before time runs out."
        }
    }
    var symbol: String {
        switch self {
        case .find: "hand.tap"
        case .name: "text.bubble"
        case .capital: "building.columns"
        case .flag: "flag"
        case .nickname: "quote.bubble"
        case .capitalLocation: "mappin.and.ellipse"
        case .cityLocation: "building.2"
        case .population: "person.3"
        case .landmarkLocation: "binoculars"
        case .challenge: "stopwatch"
        }
    }
    var isLocation: Bool { [.capitalLocation, .cityLocation, .landmarkLocation, .challenge].contains(self) }
    /// The challenge ignores the round settings: always this many places, this many seconds each.
    static let challengeCount = 15, challengeSeconds = 15
    var usesMap: Bool { self == .find || self == .name || isLocation }
    static func available(in pack: MapPack) -> [Self] {
        ["us-states", "germany-states"].contains(pack.id) ? allCases : [.find, .name, .challenge]
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
        var points = 0
    }
    private(set) var questions: [Question]
    private(set) var index = 0
    private(set) var answer: Answer?
    private(set) var firstAttemptCorrect = 0
    private(set) var reviewedCorrect = 0
    private(set) var missed: [Area] = []
    /// Consecutive correct answers, review questions included.
    private(set) var streak = 0
    /// Challenge points; zero in every other mode.
    private(set) var score = 0
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

    /// `rangeKM` turns on challenge scoring; `timeLeft` is the unused share of the clock, 0 to 1.
    mutating func submitLocation(_ guess: MapPin, target: MapPin, toleranceKM: Double,
                                 rangeKM: Double? = nil, timeLeft: Double = 0) {
        let distance = guess.coordinate.distanceKM(to: target.coordinate)
        let points = rangeKM.map { Self.challengePoints(distanceKM: distance, rangeKM: $0, timeLeft: timeLeft) } ?? 0
        record(Answer(selected: nil, correct: distance <= toleranceKM, guess: guess, distanceKM: distance, points: points))
    }

    /// Up to 1,000 per place. Accuracy falls with the square of the miss and reaches zero at `rangeKM`;
    /// an answer on the last tick keeps 70% of it.
    static func challengePoints(distanceKM: Double, rangeKM: Double, timeLeft: Double) -> Int {
        let accuracy = pow(max(0, 1 - distanceKM / rangeKM), 2)
        return Int((accuracy * (700 + 300 * min(1, max(0, timeLeft)))).rounded())
    }

    mutating func expire() { record(Answer(selected: nil, correct: false, timedOut: true)) }

    private mutating func record(_ result: Answer) {
        guard let question = current, answer == nil else { return }
        answer = result
        score += result.points
        streak = result.correct ? streak + 1 : 0
        if question.isReview {
            if result.correct { reviewedCorrect += 1 }
        } else if result.correct {
            firstAttemptCorrect += 1
        } else {
            missed.append(question.area)
            // Revisit once, after two other questions when the queue allows it. The challenge is one pass.
            if mode != .challenge {
                questions.insert(Question(area: question.area, isReview: true, choices: question.choices),
                                 at: min(index + 3, questions.count))
            }
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
    /// Best challenge score; nil until one is played.
    var highScore: Int?
    var accuracy: Double? { firstTotal > 0 ? Double(firstCorrect) / Double(firstTotal) : nil }
    static func + (a: Self, b: Self) -> Self {
        Self(sessions: a.sessions + b.sessions, firstCorrect: a.firstCorrect + b.firstCorrect, firstTotal: a.firstTotal + b.firstTotal,
             reviewCorrect: a.reviewCorrect + b.reviewCorrect, reviewTotal: a.reviewTotal + b.reviewTotal,
             highScore: [a.highScore, b.highScore].compactMap { $0 }.max())
    }
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
    /// Totals across timer settings, and across modes when `mode` is nil.
    func summary(for map: String, mode: PracticeMode? = nil) -> PracticeRecord {
        let prefix = map + "." + (mode?.rawValue ?? "")
        return records.filter { key, _ in
            mode == nil ? key.hasPrefix(prefix) : key == prefix || key.hasPrefix(prefix + ".")
        }.values.reduce(PracticeRecord(), +)
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
        record.reviewTotal += session.questions.count - session.primaryCount
        if session.mode == .challenge { record.highScore = max(record.highScore ?? 0, session.score) }
        records[key] = record
        if let data = try? JSONEncoder().encode(records) { defaults.set(data, forKey: "practiceProgress.v1") }
    }
    /// Forgets every score on this device.
    func reset() {
        records = [:]
        defaults.removeObject(forKey: "practiceProgress.v1")
    }
}

/// Feedback lines. Picked by position, never at random, so screenshots and tests repeat.
/// The jokes are about maps or the clock, never the learner.
enum Voice {
    static let correct = ["Nailed it.", "Spot on.", "Like a local.", "Bullseye.", "Textbook.", "Cartographers approve."]
    static let comeback = ["Second time’s the charm.", "Now it sticks.", "Redemption arc."]
    // Mode-neutral: these also follow flag, capital, and population answers.
    static let wrong = ["Not quite.", "Wrong turn.", "Plot twist.", "Close, but no.", "Not this time."]
    static let nearMiss = ["So close.", "Almost on the dot.", "Practically neighbors."]
    static let farMiss = ["Scenic detour.", "Off by a road trip.", "Bold guess."]
    static let shown = ["Here’s the answer.", "Now you know.", "No shame in peeking.", "Scouted for next time."]
    static let timeout = ["Time’s up.", "The clock won this one.", "Out of time.", "Tick, tock. Here it is."]
    static let streaks = [3: "Three in a row. Showing off?", 5: "Five straight. You’ve been here before.",
                          10: "Ten in a row. Are you a satellite?"]

    /// Stable across launches; String.hashValue is not.
    static func seed(_ id: String) -> Int { id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } }
    static func pick(_ pool: [String], _ seed: Int) -> String { pool[abs(seed % pool.count)] }

    static func headline(for answer: PracticeSession.Answer, isReview: Bool, streak: Int,
                         toleranceKM: Double, seed: Int) -> String {
        if answer.timedOut { return pick(timeout, seed) }
        if answer.correct {
            if !isReview, let line = streaks[streak] { return line }
            return pick(isReview ? comeback : correct, seed)
        }
        if let distance = answer.distanceKM { return pick(distance <= toleranceKM * 2 ? nearMiss : farMiss, seed) }
        return pick(answer.selected == nil ? shown : wrong, seed)
    }
}

/// A geographic rank for the first-try score on the results screen.
enum ResultRank: String {
    case cartographer = "Cartographer", navigator = "Navigator", explorer = "Explorer", wanderer = "Wanderer"
    init(firstTry ratio: Double) {
        self = ratio >= 1 ? .cartographer : ratio >= 0.8 ? .navigator : ratio >= 0.5 ? .explorer : .wanderer
    }
    var headlines: [String] {
        switch self {
        case .cartographer: ["Flawless.", "Not one wrong turn.", "Frame this map.", "Clean sweep."]
        case .navigator: ["Sharp navigating.", "Barely needed a compass.", "You know your way around.", "Nearly spotless."]
        case .explorer: ["Getting your bearings.", "Solid ground.", "The map is warming up."]
        case .wanderer: ["Every expert started here.", "Scenic route. Still counts.", "Good start. Go again?"]
        }
    }
}
