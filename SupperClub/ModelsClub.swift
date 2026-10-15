//
//  ModelsClub.swift
//  10PM Supper Club
//
//  The club's data: its members, its Volumes (one per year: Volume I is 2025), the dinners, each
//  member's ranking of a Volume's dinners (an order, no scores), and each member's note, best
//  dish and category scores for a dinner (Food, Drinks, Service, Cigability, Vibe: 1–10 in
//  half points, shown per person, never part of the club's order). Plus Standings: the club's combined order (by average position)
//  and each member's own list. No UI or CloudKit here, so scripts/standings-check.swift can
//  check it.
//

import Foundation

struct Member: Identifiable, Hashable, Codable {
    /// The member's iCloud user record name (stable across their devices).
    var id: String
    var name: String
    var joined: Date = .now

    /// "JL" for Joe Lombardi, "J" for Joe.
    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
}

/// A year of dinners: Volume I is 2025, Volume II 2026, and so on. A dinner's Volume is the
/// year it was on, so there's nothing to start or end.
struct Volume: Identifiable, Hashable {
    let year: Int

    static let firstYear = 2025

    init(year: Int) {
        self.year = max(year, Self.firstYear)
    }

    /// The Volume a dinner on `date` belongs to.
    static func of(_ date: Date, calendar: Calendar = .current) -> Volume {
        Volume(year: calendar.component(.year, from: date))
    }

    var number: Int { year - Self.firstYear + 1 }
    var id: String { "vol-\(year)" }
    /// "Volume II".
    var title: String { "Volume \(Self.roman(number))" }
    /// "Vol. II".
    var shortTitle: String { "Vol. \(Self.roman(number))" }

    /// Every Volume from the first through the one `date` is in.
    static func all(through date: Date = .now) -> [Volume] {
        (firstYear...max(of(date).year, firstYear)).map { Volume(year: $0) }
    }

    static func roman(_ number: Int) -> String {
        let table: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
                                      (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = max(number, 1), out = ""
        for (value, numeral) in table {
            while n >= value { out += numeral; n -= value }
        }
        return out
    }
}

struct Dinner: Identifiable, Hashable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var address: String = ""
    var neighborhood: String = ""
    var cuisine: String = ""
    var date: Date = .now
    var latitude: Double? = nil
    var longitude: Double? = nil
    /// Who was there: only they rank it.
    var attendeeIDs: [String] = []
    var addedBy: String = ""
    /// Photos, oldest first; the first is the cover.
    var photoIDs: [String] = []

    var hasLocation: Bool { latitude != nil && longitude != nil }

    /// The year it was in.
    var volume: Volume { Volume.of(date) }

    /// "West Village · Italian".
    var subtitle: String {
        [neighborhood, cuisine].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// One member's order for one Volume, best first. Only that member writes it.
struct Ranking: Hashable, Codable {
    var memberID: String
    var volumeID: String
    var order: [String]
    var updated: Date = .now

    var id: String { Self.id(member: memberID, volume: volumeID) }
    static func id(member: String, volume: String) -> String { "rank-\(member)-\(volume)" }
}

/// What each member scores a dinner on, alongside (not instead of) where they rank it.
enum ScoreCategory: String, CaseIterable, Codable, Identifiable {
    case food, drinks, service, cigability, vibe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: return "Food"
        case .drinks: return "Drinks"
        case .service: return "Service"
        case .cigability: return "Cigability"
        case .vibe: return "Vibe"
        }
    }

    /// For Cigability: what it means.
    var detail: String? {
        self == .cigability ? "Smoking a cig between courses" : nil
    }

    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .drinks: return "wineglass"
        case .service: return "bell"
        case .cigability: return "smoke"
        case .vibe: return "sparkles"
        }
    }

    static let range: ClosedRange<Double> = 1...10

    /// A score as it's kept: within 1–10, to the nearest half point.
    static func clean(_ score: Double) -> Double {
        (min(max(score, range.lowerBound), range.upperBound) * 2).rounded() / 2
    }

    /// "8.5", "9".
    static func format(_ score: Double) -> String {
        score.rounded() == score ? String(Int(score)) : String(format: "%.1f", score)
    }
}

/// One member's take on one dinner: a note, their standout dish, and category scores.
struct Review: Hashable, Codable, Identifiable {
    var memberID: String
    var dinnerID: String
    var note: String = ""
    var bestDish: String = ""
    /// Scores by category (only the ones they've given).
    var scores: [ScoreCategory: Double] = [:]
    var updated: Date = .now

    var id: String { Self.id(member: memberID, dinner: dinnerID) }
    static func id(member: String, dinner: String) -> String { "review-\(member)-\(dinner)" }
    var isEmpty: Bool { note.isEmpty && bestDish.isEmpty && scores.isEmpty }
    var hasWords: Bool { !note.isEmpty || !bestDish.isEmpty }
}

// MARK: - Standings

enum Standings {

    /// A member's list for a Volume: the dinners they were at, in their order. Dinners they
    /// haven't placed yet (added since they last ranked) come after, newest first, as `new`.
    static func list(for memberID: String, dinners: [Dinner], ranking: Ranking?) -> (ranked: [Dinner], new: [Dinner]) {
        let attended = dinners.filter { $0.attendeeIDs.contains(memberID) }
        let byID = Dictionary(attended.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ranked = (ranking?.order ?? []).compactMap { byID[$0] }
        let placed = Set(ranked.map(\.id))
        let new = attended.filter { !placed.contains($0.id) }.sorted { $0.date > $1.date }
        return (ranked, new)
    }

    struct Row: Identifiable, Hashable {
        let dinner: Dinner
        /// Average position (1 = best) over the members who've ranked it; nil if nobody has.
        let average: Double?
        /// Each ranking member's position for it.
        let positions: [String: Int]
        /// Attendees who haven't placed it yet.
        let waitingOn: [String]
        var id: String { dinner.id }
    }

    /// The club's order for a Volume: by average position (lower is better). Ties go to the
    /// one with more first places, then the more recent dinner. Dinners nobody has ranked come
    /// last, newest first.
    static func club(dinners: [Dinner], rankings: [Ranking]) -> [Row] {
        var rows: [Row] = dinners.map { dinner in
            var positions: [String: Int] = [:]
            for ranking in rankings {
                let list = list(for: ranking.memberID, dinners: dinners, ranking: ranking).ranked
                if let index = list.firstIndex(where: { $0.id == dinner.id }) { positions[ranking.memberID] = index + 1 }
            }
            let average = positions.isEmpty ? nil : Double(positions.values.reduce(0, +)) / Double(positions.count)
            let waiting = dinner.attendeeIDs.filter { positions[$0] == nil }
            return Row(dinner: dinner, average: average, positions: positions, waitingOn: waiting)
        }
        rows.sort { a, b in
            switch (a.average, b.average) {
            case let (x?, y?) where x != y: return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            default:
                let firstsA = a.positions.values.filter { $0 == 1 }.count
                let firstsB = b.positions.values.filter { $0 == 1 }.count
                if firstsA != firstsB { return firstsA > firstsB }
                return a.dinner.date > b.dinner.date
            }
        }
        return rows
    }
}
