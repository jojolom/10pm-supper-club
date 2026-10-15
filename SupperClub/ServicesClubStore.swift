//
//  ServicesClubStore.swift
//  10PM Supper Club
//
//  The club as the screens see it: members, Volumes, dinners, rankings and reviews, who "me"
//  is, and the Volume on screen. Edits update the screen at once and are saved through a
//  ClubBackend: CloudKitBackend for the real, shared club; DemoBackend (an in-memory club with
//  sample dinners) for the Simulator and screenshots.
//

import Foundation
import Observation
import UIKit

/// Everything in the club, as loaded.
struct ClubSnapshot {
    var members: [Member] = []
    var dinners: [Dinner] = []
    var rankings: [Ranking] = []
    var reviews: [Review] = []
}

protocol ClubBackend: AnyObject {
    /// Whether this device is in a club yet (started one, or accepted an invite).
    var hasClub: Bool { get }
    /// Who's signed in to iCloud on this device (their user record name).
    func currentUserID() async throws -> String
    /// Starts a new club owned by this user.
    func createClub() async throws
    func load() async throws -> ClubSnapshot
    func save(_ member: Member) async throws
    func save(_ dinner: Dinner) async throws
    func delete(_ dinner: Dinner) async throws
    func save(_ ranking: Ranking) async throws
    func save(_ review: Review) async throws
    /// Stores a photo; returns its id.
    func savePhoto(_ jpeg: Data, dinnerID: String) async throws -> String
    func photo(_ id: String) async throws -> Data?
}

@Observable
final class ClubStore {

    enum Phase: Equatable {
        case loading
        /// iCloud isn't available (signed out, or restricted).
        case noAccount(String)
        /// Not in a club: start one, or open a friend's invite.
        case noClub
        /// In a club, but this person hasn't said their name yet.
        case needsProfile
        case ready
    }

    let backend: ClubBackend
    private(set) var phase: Phase = .loading
    private(set) var snapshot = ClubSnapshot()
    private(set) var meID: String = ""
    /// The Volume on screen (this year's, unless another's picked).
    var volumeID: String?
    private(set) var isRefreshing = false
    private(set) var lastError: String?
    private var photoCache: [String: UIImage] = [:]

    init(backend: ClubBackend) {
        self.backend = backend
    }

    // MARK: Derived

    var members: [Member] { snapshot.members.sorted { $0.joined < $1.joined } }
    var me: Member? { snapshot.members.first { $0.id == meID } }
    /// From Volume I (2025) through this year's, or a later year's if a dinner's dated then.
    var volumes: [Volume] { Volume.all(through: max(.now, snapshot.dinners.map(\.date).max() ?? .now)) }
    var volume: Volume? {
        volumes.first { $0.id == volumeID } ?? volumes.first { $0.id == Volume.of(.now).id } ?? volumes.last
    }
    var dinners: [Dinner] {
        guard let volume else { return [] }
        return snapshot.dinners.filter { $0.volume == volume }.sorted { $0.date > $1.date }
    }
    var standings: [Standings.Row] {
        guard let volume else { return [] }
        return Standings.club(dinners: dinners, rankings: snapshot.rankings.filter { $0.volumeID == volume.id })
    }

    func member(_ id: String) -> Member? { snapshot.members.first { $0.id == id } }
    func dinner(_ id: String) -> Dinner? { snapshot.dinners.first { $0.id == id } }

    func ranking(for memberID: String) -> Ranking? {
        guard let volume else { return nil }
        return snapshot.rankings.first { $0.memberID == memberID && $0.volumeID == volume.id }
    }

    func list(for memberID: String) -> (ranked: [Dinner], new: [Dinner]) {
        Standings.list(for: memberID, dinners: dinners, ranking: ranking(for: memberID))
    }

    func reviews(for dinnerID: String) -> [Review] {
        snapshot.reviews.filter { $0.dinnerID == dinnerID && !$0.isEmpty }
            .sorted { (member($0.memberID)?.joined ?? .now) < (member($1.memberID)?.joined ?? .now) }
    }

    func review(by memberID: String, of dinnerID: String) -> Review? {
        snapshot.reviews.first { $0.memberID == memberID && $0.dinnerID == dinnerID }
    }

    // MARK: Loading

    /// Works out where this device stands (iCloud, club, profile) and loads the club.
    func start() async {
        do {
            meID = try await backend.currentUserID()
        } catch {
            phase = .noAccount("Sign in to iCloud in Settings to join the club.")
            return
        }
        guard backend.hasClub else {
            phase = .noClub
            return
        }
        await refresh()
    }

    func refresh() async {
        guard backend.hasClub, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            snapshot = try await backend.load()
            lastError = nil
            phase = me == nil ? .needsProfile : .ready
        } catch {
            lastError = error.localizedDescription
            if phase == .loading { phase = .noClub }
        }
    }

    func createClub() async throws {
        try await backend.createClub()
        await refresh()
    }

    /// After an invite is accepted (see SceneDelegate).
    func joinedClub() async {
        await refresh()
    }

    // MARK: Editing

    func setMyName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var member = me ?? Member(id: meID, name: trimmed)
        member.name = trimmed
        upsert(member, in: \.members)
        phase = .ready
        persist { try await $0.save(member) }
    }

    /// Saves a dinner, and shows its Volume (its year).
    func save(_ dinner: Dinner) {
        upsert(dinner, in: \.dinners)
        volumeID = dinner.volume.id
        persist { try await $0.save(dinner) }
    }

    func delete(_ dinner: Dinner) {
        snapshot.dinners.removeAll { $0.id == dinner.id }
        persist { try await $0.delete(dinner) }
    }

    /// My order for the Volume on screen, best first (every dinner listed counts as placed).
    func setMyOrder(_ dinnerIDs: [String]) {
        guard let volume else { return }
        let ranking = Ranking(memberID: meID, volumeID: volume.id, order: dinnerIDs)
        upsert(ranking, in: \.rankings)
        persist { try await $0.save(ranking) }
    }

    func saveMyReview(of dinnerID: String, note: String, bestDish: String) {
        let review = Review(memberID: meID, dinnerID: dinnerID,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            bestDish: bestDish.trimmingCharacters(in: .whitespacesAndNewlines))
        upsert(review, in: \.reviews)
        persist { try await $0.save(review) }
    }

    /// Adds photos to a dinner (JPEG data), the first becoming the cover if it has none.
    func addPhotos(_ jpegs: [Data], to dinnerID: String) async {
        for jpeg in jpegs {
            do {
                let id = try await backend.savePhoto(jpeg, dinnerID: dinnerID)
                if let image = UIImage(data: jpeg) { photoCache[id] = image }
                guard var dinner = dinner(dinnerID) else { continue }
                dinner.photoIDs.append(id)
                save(dinner)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func image(_ photoID: String) async -> UIImage? {
        if let cached = photoCache[photoID] { return cached }
        guard let data = try? await backend.photo(photoID), let image = UIImage(data: data) else { return nil }
        photoCache[photoID] = image
        return image
    }

    // MARK: Helpers

    private func upsert<T: Identifiable>(_ item: T, in path: WritableKeyPath<ClubSnapshot, [T]>) where T.ID == String {
        if let index = snapshot[keyPath: path].firstIndex(where: { $0.id == item.id }) {
            snapshot[keyPath: path][index] = item
        } else {
            snapshot[keyPath: path].append(item)
        }
    }

    private func upsert(_ ranking: Ranking, in path: WritableKeyPath<ClubSnapshot, [Ranking]>) {
        snapshot[keyPath: path].removeAll { $0.id == ranking.id }
        snapshot[keyPath: path].append(ranking)
    }

    private func persist(_ work: @escaping (ClubBackend) async throws -> Void) {
        Task {
            do {
                try await work(backend)
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}
