//
//  ServicesDemoBackend.swift
//  10PM Supper Club
//
//  An in-memory club with four members, a friend asking to join, guests' scores and NYC dinners
//  in 2025 and 2026 (Volumes I and II), for the Simulator and screenshots. Debug builds
//  launched with `-demo YES` use it, as Joe (the founder), or as a guest with `-guest YES`;
//  nothing is saved.
//

import Foundation

final class DemoBackend: ClubBackend {

    private var snapshot: ClubSnapshot
    private var photos: [String: Data] = [:]
    private let meID: String

    init(asGuest: Bool = false) {
        meID = asGuest ? "demo-guest" : "demo-joe"
        let day: TimeInterval = 86_400
        let now = Date()
        let members = [
            Member(id: "demo-joe", name: "Joe", joined: now - 400 * day),
            Member(id: "demo-marco", name: "Marco", joined: now - 399 * day),
            Member(id: "demo-nina", name: "Nina", joined: now - 398 * day),
            Member(id: "demo-theo", name: "Theo", joined: now - 397 * day),
        ]
        let ids = members.map(\.id)
        let one = Volume(year: 2025)
        let two = Volume(year: 2026)
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 22)) ?? now
        }
        func dinner(_ id: String, _ name: String, _ hood: String, _ cuisine: String, _ when: Date,
                    _ address: String, _ lat: Double, _ lon: Double, attendees: [String]? = nil) -> Dinner {
            Dinner(id: id, name: name, address: address, neighborhood: hood, cuisine: cuisine,
                   date: when, latitude: lat, longitude: lon, attendeeIDs: attendees ?? ids, addedBy: ids[0])
        }
        let dinners = [
            dinner("carbone", "Carbone", "Greenwich Village", "Italian", date(2026, 10, 3), "181 Thompson St", 40.7279, -74.0001),
            dinner("coucou", "Le Coucou", "SoHo", "French", date(2026, 8, 22), "138 Lafayette St", 40.7191, -74.0003),
            dinner("lilia", "Lilia", "Williamsburg", "Italian", date(2026, 6, 13), "567 Union Ave, Brooklyn", 40.7175, -73.9522),
            dinner("raouls", "Raoul's", "SoHo", "French Bistro", date(2026, 4, 18), "180 Prince St", 40.7262, -74.0024),
            dinner("cote", "Cote", "Flatiron", "Korean Steakhouse", date(2026, 2, 7), "16 W 22nd St", 40.7416, -73.9915,
                   attendees: [ids[0], ids[1], ids[2]]),
            dinner("viacarota", "Via Carota", "West Village", "Italian", date(2025, 11, 15), "51 Grove St", 40.7333, -74.0036),
            dinner("prime", "4 Charles Prime Rib", "West Village", "Steakhouse", date(2025, 8, 9), "4 Charles St", 40.7355, -74.0008),
            dinner("minetta", "Minetta Tavern", "Greenwich Village", "Brasserie", date(2025, 5, 24), "113 MacDougal St", 40.7300, -74.0006),
        ]
        let rankings = [
            Ranking(memberID: ids[0], volumeID: two.id, order: ["coucou", "carbone", "cote", "lilia", "raouls"]),
            Ranking(memberID: ids[1], volumeID: two.id, order: ["carbone", "coucou", "lilia", "cote", "raouls"]),
            Ranking(memberID: ids[2], volumeID: two.id, order: ["lilia", "coucou", "cote", "raouls"]),
            Ranking(memberID: ids[3], volumeID: two.id, order: ["coucou", "lilia", "carbone", "raouls"]),
            Ranking(memberID: ids[0], volumeID: one.id, order: ["prime", "viacarota", "minetta"]),
            Ranking(memberID: ids[1], volumeID: one.id, order: ["viacarota", "prime", "minetta"]),
            Ranking(memberID: ids[2], volumeID: one.id, order: ["prime", "minetta", "viacarota"]),
            Ranking(memberID: ids[3], volumeID: one.id, order: ["prime", "viacarota", "minetta"]),
        ]
        let reviews = [
            Review(memberID: ids[0], dinnerID: "coucou", note: "Best room in the city. Worth every minute of the wait.", bestDish: "Quenelles de brochet",
                   scores: [.food: 9.5, .drinks: 8.5, .service: 10, .cigability: 4, .vibe: 9]),
            Review(memberID: ids[1], dinnerID: "carbone", note: "The show is half of it, and the other half is the rigatoni.", bestDish: "Spicy rigatoni vodka",
                   scores: [.food: 9, .drinks: 8, .service: 9.5, .cigability: 6.5, .vibe: 10]),
            Review(memberID: ids[2], dinnerID: "lilia", note: "Pasta perfection. Went back the next week.", bestDish: "Mafaldini, pink peppercorns",
                   scores: [.food: 10, .drinks: 7, .service: 8, .cigability: 8.5, .vibe: 7.5]),
            Review(memberID: ids[3], dinnerID: "coucou", note: "", bestDish: "Lobster salad",
                   scores: [.food: 9, .drinks: 9, .service: 9.5, .cigability: 3, .vibe: 8.5]),
            Review(memberID: ids[1], dinnerID: "coucou", scores: [.food: 8.5, .drinks: 8, .service: 9, .cigability: 5, .vibe: 8]),
            Review(memberID: ids[0], dinnerID: "carbone", scores: [.food: 8.5, .drinks: 7.5, .service: 9, .cigability: 7, .vibe: 9.5]),
            Review(memberID: ids[0], dinnerID: "lilia", scores: [.food: 9, .drinks: 6.5, .service: 7.5, .cigability: 9, .vibe: 7]),
        ]
        let guestReviews = [
            Review(memberID: "demo-g1", dinnerID: "coucou", scores: [.food: 9, .drinks: 8, .service: 9, .cigability: 2, .vibe: 8.5]),
            Review(memberID: "demo-g2", dinnerID: "coucou", scores: [.food: 8.5, .drinks: 9, .service: 8.5, .vibe: 9]),
            Review(memberID: "demo-g1", dinnerID: "carbone", scores: [.food: 8, .drinks: 7.5, .service: 8, .cigability: 5, .vibe: 9.5]),
        ]
        let club = ClubInfo(founderID: ids[0], memberIDs: ids)
        let asking = Member(id: "demo-sam", name: "Sam", joined: now - 2 * day)
        snapshot = ClubSnapshot(club: club, members: members + [asking], dinners: dinners, rankings: rankings,
                                reviews: reviews, guestReviews: guestReviews)
    }

    func currentUserID() async -> String? { meID }
    func load() async throws -> ClubSnapshot { snapshot }

    func save(_ club: ClubInfo) async throws { snapshot.club = club }

    func save(_ member: Member) async throws { upsert(member, \.members) }
    func save(_ dinner: Dinner) async throws { upsert(dinner, \.dinners) }
    func delete(_ dinner: Dinner) async throws { snapshot.dinners.removeAll { $0.id == dinner.id } }
    func save(_ ranking: Ranking) async throws {
        snapshot.rankings.removeAll { $0.id == ranking.id }
        snapshot.rankings.append(ranking)
    }
    func save(_ review: Review) async throws { upsert(review, \.reviews) }
    func saveGuestReview(_ review: Review) async throws { upsert(review, \.guestReviews) }

    func savePhoto(_ jpeg: Data, dinnerID: String) async throws -> String {
        let id = UUID().uuidString
        photos[id] = jpeg
        return id
    }

    func photo(_ id: String) async throws -> Data? { photos[id] }

    private func upsert<T: Identifiable>(_ item: T, _ path: WritableKeyPath<ClubSnapshot, [T]>) where T.ID == String {
        snapshot[keyPath: path].removeAll { $0.id == item.id }
        snapshot[keyPath: path].append(item)
    }
}
