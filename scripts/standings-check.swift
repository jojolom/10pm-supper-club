//
//  standings-check.swift
//
//  Offline check for the ranking math (ModelsClub.swift): a member's list keeps their order and
//  puts dinners they haven't placed after it, newest first; only attendees rank a dinner; the
//  club order goes by average position, ties to more first places, then the newer dinner, with
//  unranked dinners last; "waiting on" names the attendees who haven't placed it; and Volumes
//  are years (Volume I is 2025); category scores keep to 1–10 in half points.
//
//  Run from the repo root:
//    swiftc -parse-as-library -o /tmp/standings-check SupperClub/ModelsClub.swift scripts/standings-check.swift && /tmp/standings-check
//

import Foundation

@main
struct StandingsCheck {
    static var failures = 0
    static func check(_ ok: Bool, _ message: @autoclosure () -> String) {
        if !ok { print("FAIL", message()); failures += 1 }
    }

    static func main() {
        let now = Date()
        let all = ["a", "b", "c"]
        func dinner(_ id: String, _ daysAgo: Double, _ attendees: [String] = all) -> Dinner {
            Dinner(id: id, name: id, date: now - daysAgo * 86_400, attendeeIDs: attendees)
        }
        let dinners = [dinner("x", 30), dinner("y", 20), dinner("z", 10), dinner("w", 5, ["a", "b"]), dinner("new", 1)]
        let rankings = [
            Ranking(memberID: "a", volumeID: "v", order: ["y", "x", "z", "w"]),
            Ranking(memberID: "b", volumeID: "v", order: ["x", "y", "w", "z", "gone"]),
            Ranking(memberID: "c", volumeID: "v", order: ["y", "z", "x", "w"]),  // c wasn't at w
        ]

        let a = Standings.list(for: "a", dinners: dinners, ranking: rankings[0])
        check(a.ranked.map(\.id) == ["y", "x", "z", "w"] && a.new.map(\.id) == ["new"], "a's list: \(a.ranked.map(\.id)) + \(a.new.map(\.id))")
        let c = Standings.list(for: "c", dinners: dinners, ranking: rankings[2])
        check(c.ranked.map(\.id) == ["y", "z", "x"], "c doesn't rank a dinner they missed: \(c.ranked.map(\.id))")
        let b = Standings.list(for: "b", dinners: dinners, ranking: rankings[1])
        check(!b.ranked.contains { $0.id == "gone" }, "deleted dinners drop out")
        let fresh = Standings.list(for: "a", dinners: dinners, ranking: nil)
        check(fresh.ranked.isEmpty && fresh.new.map(\.id) == ["new", "w", "z", "y", "x"], "nothing ranked: all new, newest first")

        let club = Standings.club(dinners: dinners, rankings: rankings)
        // y: 1,2,1 → 1.33; x: 2,1,3 → 2; z: 3,4,2 → 3; w: 4,3 → 3.5; new: unranked.
        check(club.map(\.dinner.id) == ["y", "x", "z", "w", "new"], "club order: \(club.map(\.dinner.id))")
        check(abs((club[0].average ?? 0) - 4.0 / 3) < 1e-9, "y's average \(String(describing: club[0].average))")
        check(club[3].positions == ["a": 4, "b": 3], "w ranked only by its attendees: \(club[3].positions)")
        check(club[4].average == nil && Set(club[4].waitingOn) == Set(all), "new waits on everyone")

        // Ties: equal averages go to more first places, then the newer dinner.
        let tie = [dinner("p", 9), dinner("q", 8)]
        let tied = Standings.club(dinners: tie, rankings: [
            Ranking(memberID: "a", volumeID: "v", order: ["p", "q"]),
            Ranking(memberID: "b", volumeID: "v", order: ["q", "p"]),
        ])
        check(tied.map(\.dinner.id) == ["q", "p"], "a dead heat goes to the newer dinner: \(tied.map(\.dinner.id))")
        check(Volume.roman(4) == "IV" && Volume.roman(14) == "XIV", "roman numerals")
        // Volumes are years: Volume I is 2025.
        func day(_ y: Int, _ m: Int, _ d: Int) -> Date { Calendar.current.date(from: DateComponents(year: y, month: m, day: d))! }
        check(Volume.of(day(2025, 3, 1)).number == 1 && Volume.of(day(2026, 12, 31)).number == 2
              && Volume.of(day(2027, 1, 1)).title == "Volume III", "Volume I is 2025, II 2026, III 2027")
        check(Volume.of(day(2024, 6, 1)).year == 2025, "nothing before Volume I")
        check(Volume.all(through: day(2027, 5, 1)).map(\.year) == [2025, 2026, 2027], "every Volume through a date")
        check(Member(id: "1", name: "Joe Lombardi").initials == "JL", "initials")
        // Scores: 1–10 in half points, shown without a needless ".0".
        check(ScoreCategory.clean(8.3) == 8.5 && ScoreCategory.clean(8.2) == 8 && ScoreCategory.clean(12) == 10
              && ScoreCategory.clean(0) == 1, "scores round to half points within 1–10")
        check(ScoreCategory.format(9) == "9" && ScoreCategory.format(8.5) == "8.5", "score formatting")
        check(Review(memberID: "a", dinnerID: "x", scores: [.vibe: 7]).isEmpty == false
              && Review(memberID: "a", dinnerID: "x", scores: [.vibe: 7]).hasWords == false, "scores alone are a review without words")

        print(failures == 0 ? "All standings checks passed." : "\(failures) failure(s).")
        exit(failures == 0 ? 0 : 1)
    }
}
