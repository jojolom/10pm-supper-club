//
//  ServicesDemoBackend.swift
//  10PM Supper Club
//
//  An in-memory club with four members and two Volumes of NYC dinners, for the Simulator
//  (where iCloud sharing can't be tried) and screenshots. Debug builds launched with
//  `-demo YES` use it; nothing is saved.
//

import Foundation

final class DemoBackend: ClubBackend {

    private var snapshot: ClubSnapshot
    private var photos: [String: Data] = [:]
    private(set) var hasClub = true
    private let meID = "demo-joe"

    init() {
        let day: TimeInterval = 86_400
        let now = Date()
        let members = [
            Member(id: "demo-joe", name: "Joe", joined: now - 400 * day),
            Member(id: "demo-marco", name: "Marco", joined: now - 399 * day),
            Member(id: "demo-nina", name: "Nina", joined: now - 398 * day),
            Member(id: "demo-theo", name: "Theo", joined: now - 397 * day),
        ]
        let ids = members.map(\.id)
        let one = Volume(id: "vol-1", number: 1, started: now - 380 * day)
        let two = Volume(id: "vol-2", number: 2, started: now - 90 * day)
        func dinner(_ id: String, _ volume: Volume, _ name: String, _ hood: String, _ cuisine: String,
                    _ daysAgo: Double, _ address: String, _ lat: Double, _ lon: Double, attendees: [String]? = nil) -> Dinner {
            Dinner(id: id, volumeID: volume.id, name: name, address: address, neighborhood: hood, cuisine: cuisine,
                   date: now - daysAgo * day, latitude: lat, longitude: lon, attendeeIDs: attendees ?? ids, addedBy: ids[0])
        }
        let dinners = [
            dinner("carbone", two, "Carbone", "Greenwich Village", "Italian", 6, "181 Thompson St", 40.7279, -74.0001),
            dinner("coucou", two, "Le Coucou", "SoHo", "French", 20, "138 Lafayette St", 40.7191, -74.0003),
            dinner("lilia", two, "Lilia", "Williamsburg", "Italian", 34, "567 Union Ave, Brooklyn", 40.7175, -73.9522),
            dinner("raouls", two, "Raoul's", "SoHo", "French Bistro", 48, "180 Prince St", 40.7262, -74.0024),
            dinner("cote", two, "Cote", "Flatiron", "Korean Steakhouse", 62, "16 W 22nd St", 40.7416, -73.9915,
                   attendees: [ids[0], ids[1], ids[2]]),
            dinner("viacarota", one, "Via Carota", "West Village", "Italian", 120, "51 Grove St", 40.7333, -74.0036),
            dinner("prime", one, "4 Charles Prime Rib", "West Village", "Steakhouse", 160, "4 Charles St", 40.7355, -74.0008),
            dinner("minetta", one, "Minetta Tavern", "Greenwich Village", "Brasserie", 210, "113 MacDougal St", 40.7300, -74.0006),
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
            Review(memberID: ids[0], dinnerID: "coucou", note: "Best room in the city. Worth every minute of the wait.", bestDish: "Quenelles de brochet"),
            Review(memberID: ids[1], dinnerID: "carbone", note: "The show is half of it, and the other half is the rigatoni.", bestDish: "Spicy rigatoni vodka"),
            Review(memberID: ids[2], dinnerID: "lilia", note: "Pasta perfection. Went back the next week.", bestDish: "Mafaldini, pink peppercorns"),
            Review(memberID: ids[3], dinnerID: "coucou", note: "", bestDish: "Lobster salad"),
        ]
        snapshot = ClubSnapshot(members: members, volumes: [one, two], dinners: dinners, rankings: rankings, reviews: reviews)
    }

    func currentUserID() async throws -> String { meID }
    func createClub() async throws { hasClub = true }
    func load() async throws -> ClubSnapshot { snapshot }

    func save(_ member: Member) async throws { upsert(member, \.members) }
    func save(_ volume: Volume) async throws { upsert(volume, \.volumes) }
    func save(_ dinner: Dinner) async throws { upsert(dinner, \.dinners) }
    func delete(_ dinner: Dinner) async throws { snapshot.dinners.removeAll { $0.id == dinner.id } }
    func save(_ ranking: Ranking) async throws {
        snapshot.rankings.removeAll { $0.id == ranking.id }
        snapshot.rankings.append(ranking)
    }
    func save(_ review: Review) async throws { upsert(review, \.reviews) }

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
