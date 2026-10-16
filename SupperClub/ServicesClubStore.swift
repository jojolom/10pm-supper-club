//
//  ServicesClubStore.swift
//  10PM Supper Club
//
//  The club as the screens see it: who's in it, Volumes, dinners, rankings, reviews and guests'
//  scores, who "me" is (a member, or a guest), and the Volume on screen. Edits update the
//  screen at once and are saved through a ClubBackend: CloudKitBackend for the real club, in
//  the app's public iCloud database; DemoBackend (an in-memory club with sample dinners) for
//  the Simulator and screenshots.
//
//  Members add, rank and score dinners. Guests (anyone else with the app) look, and can score
//  a dinner once the club has ranked or scored it; theirs show apart, as a guest average.
//

import Foundation
import Observation
import UIKit

/// Everything in the club, as loaded.
struct ClubSnapshot {
    /// Nil until someone starts the club.
    var club: ClubInfo?
    /// Members, and anyone who has asked to join.
    var members: [Member] = []
    var dinners: [Dinner] = []
    var rankings: [Ranking] = []
    var reviews: [Review] = []
    /// Guests' scores (no notes).
    var guestReviews: [Review] = []
}

protocol ClubBackend: AnyObject {
    /// Who's signed in to iCloud on this device (their user record name); nil if nobody is,
    /// which is fine for looking but not for saving anything.
    func currentUserID() async -> String?
    func load() async throws -> ClubSnapshot
    /// Starts the club, or (founder only) changes who's in it.
    func save(_ club: ClubInfo) async throws
    func save(_ member: Member) async throws
    func save(_ dinner: Dinner) async throws
    func delete(_ dinner: Dinner) async throws
    func save(_ ranking: Ranking) async throws
    func save(_ review: Review) async throws
    func saveGuestReview(_ review: Review) async throws
    /// Stores a photo; returns its id.
    func savePhoto(_ jpeg: Data, dinnerID: String) async throws -> String
    func photo(_ id: String) async throws -> Data?
}

@Observable
final class ClubStore {

    enum Phase: Equatable {
        case loading
        /// Nobody has started the club yet.
        case noClub
        /// There's a club, and this person hasn't said whether they're in it or just looking.
        case welcome
        /// A member (or someone asking to join) who hasn't said their name yet.
        case needsProfile
        case ready
    }

    let backend: ClubBackend
    private(set) var phase: Phase = .loading
    private(set) var snapshot = ClubSnapshot()
    /// Empty when nobody's signed in to iCloud.
    private(set) var meID: String = ""
    /// The Volume on screen (this year's, unless another's picked).
    var volumeID: String?
    private(set) var isRefreshing = false
    private(set) var lastError: String?
    private var photoCache: [String: UIImage] = [:]
    /// Edits made here in the last minute, applied again over each load: new records in the
    /// public database take a few seconds to show up in queries.
    private var recentEdits: [(at: Date, apply: (inout ClubSnapshot) -> Void)] = []
    /// Tapped "I'm in the Club" and is saying their name.
    private var isJoining = false

    private static let browsingKey = "club.browsing"
    private var hasChosenToBrowse: Bool {
        get { UserDefaults.standard.bool(forKey: Self.browsingKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.browsingKey) }
    }

    init(backend: ClubBackend) {
        self.backend = backend
    }

    // MARK: Who I am

    var isSignedIn: Bool { !meID.isEmpty }
    var isMember: Bool { snapshot.club?.isMember(meID) == true }
    var isFounder: Bool { isSignedIn && snapshot.club?.founderID == meID }
    /// My name, if I'm a member or have asked to join.
    var me: Member? { snapshot.members.first { $0.id == meID } }
    /// Asked to join and waiting to be let in.
    var hasAskedToJoin: Bool { !isMember && me != nil && snapshot.club?.declinedIDs.contains(meID) != true }
    var founder: Member? { snapshot.club.flatMap { member($0.founderID) } }

    // MARK: Derived

    /// The club's members, in the order they joined.
    var members: [Member] {
        guard let club = snapshot.club else { return [] }
        return snapshot.members.filter { club.isMember($0.id) }.sorted { $0.joined < $1.joined }
    }
    /// People asking to join (for the founder to let in), oldest first.
    var requests: [Member] {
        guard let club = snapshot.club else { return [] }
        return snapshot.members.filter { !club.isMember($0.id) && !club.declinedIDs.contains($0.id) }.sorted { $0.joined < $1.joined }
    }
    /// From Volume I (2025) through this year's, or a later year's if a dinner's dated then.
    var volumes: [Volume] { Volume.all(through: max(.now, clubDinners.map(\.date).max() ?? .now)) }
    var volume: Volume? {
        volumes.first { $0.id == volumeID } ?? volumes.first { $0.id == Volume.of(.now).id } ?? volumes.last
    }
    var dinners: [Dinner] {
        guard let volume else { return [] }
        return clubDinners.filter { $0.volume == volume }.sorted { $0.date > $1.date }
    }
    var standings: [Standings.Row] {
        guard let volume else { return [] }
        return Standings.club(dinners: dinners, rankings: clubRankings.filter { $0.volumeID == volume.id })
    }

    /// Only what members wrote counts as the club's.
    private var clubDinners: [Dinner] { snapshot.dinners.filter { isClubMember($0.addedBy) } }
    private var clubRankings: [Ranking] { snapshot.rankings.filter { isClubMember($0.memberID) } }
    private func isClubMember(_ id: String) -> Bool { snapshot.club?.isMember(id) == true }

    func member(_ id: String) -> Member? { snapshot.members.first { $0.id == id } }
    func dinner(_ id: String) -> Dinner? { clubDinners.first { $0.id == id } }

    func ranking(for memberID: String) -> Ranking? {
        guard let volume else { return nil }
        return clubRankings.first { $0.memberID == memberID && $0.volumeID == volume.id }
    }

    func list(for memberID: String) -> (ranked: [Dinner], new: [Dinner]) {
        Standings.list(for: memberID, dinners: dinners, ranking: ranking(for: memberID))
    }

    /// Members' reviews with a note or best dish, for the dinner's notes.
    func reviews(for dinnerID: String) -> [Review] {
        snapshot.reviews.filter { $0.dinnerID == dinnerID && $0.hasWords && isClubMember($0.memberID) }
            .sorted { (member($0.memberID)?.joined ?? .now) < (member($1.memberID)?.joined ?? .now) }
    }

    func review(by memberID: String, of dinnerID: String) -> Review? {
        guard isClubMember(memberID) else { return nil }
        return snapshot.reviews.first { $0.memberID == memberID && $0.dinnerID == dinnerID }
    }

    /// Whether a member has ranked or scored it: only then can guests score it.
    func clubHasRated(_ dinnerID: String) -> Bool {
        clubRankings.contains { $0.order.contains(dinnerID) && dinner(dinnerID)?.attendeeIDs.contains($0.memberID) == true }
            || snapshot.reviews.contains { $0.dinnerID == dinnerID && !$0.scores.isEmpty && isClubMember($0.memberID) }
    }

    /// Guests' scores for a dinner (anyone not in the club).
    func guestReviews(for dinnerID: String) -> [Review] {
        snapshot.guestReviews.filter { $0.dinnerID == dinnerID && !$0.scores.isEmpty && !isClubMember($0.memberID) }
    }

    var canScoreAsGuest: Bool { isSignedIn && !isMember }

    func myGuestReview(of dinnerID: String) -> Review? {
        snapshot.guestReviews.first { $0.memberID == meID && $0.dinnerID == dinnerID }
    }

    // MARK: Loading

    /// Works out who this is and loads the club.
    func start() async {
        meID = await backend.currentUserID() ?? ""
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            var loaded = try await backend.load()
            recentEdits.removeAll { $0.at < .now - 60 }
            for edit in recentEdits { edit.apply(&loaded) }
            snapshot = loaded
            lastError = nil
            updatePhase()
        } catch {
            lastError = error.localizedDescription
            if phase == .loading { phase = .welcome }
        }
    }

    private func updatePhase() {
        if snapshot.club == nil {
            phase = .noClub
        } else if isMember {
            phase = me == nil ? .needsProfile : .ready
        } else if isJoining {
            phase = .needsProfile
        } else {
            phase = hasChosenToBrowse || me != nil ? .ready : .welcome
        }
    }

    // MARK: Joining

    /// Starts the club, with this person as its founder (they say their name next).
    func startClub() async throws {
        guard isSignedIn, snapshot.club == nil else { return }
        let club = ClubInfo(founderID: meID, memberIDs: [meID])
        try await backend.save(club)
        edit { $0.club = club }
        updatePhase()
    }

    /// "Just browsing": look as a guest.
    func browse() {
        hasChosenToBrowse = true
        updatePhase()
    }

    /// "I'm in the Club": say a name, which asks the founder to let them in.
    func askToJoin() {
        guard isSignedIn else { return }
        isJoining = true
        updatePhase()
    }

    /// Founder only: lets someone who asked into the club.
    func letIn(_ memberID: String) {
        updateClub { club in
            if !club.memberIDs.contains(memberID) { club.memberIDs.append(memberID) }
            club.declinedIDs.removeAll { $0 == memberID }
        }
    }

    /// Founder only: turns down a request.
    func turnDown(_ memberID: String) {
        updateClub { club in
            if !club.declinedIDs.contains(memberID) { club.declinedIDs.append(memberID) }
        }
    }

    private func updateClub(_ change: (inout ClubInfo) -> Void) {
        guard isFounder, var club = snapshot.club else { return }
        change(&club)
        edit { $0.club = club }
        persist { try await $0.save(club) }
    }

    // MARK: Editing

    /// Sets my name: a member's, or (for anyone else) asking to join.
    func setMyName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isSignedIn else { return }
        var member = me ?? Member(id: meID, name: trimmed)
        member.name = trimmed
        edit { $0.members.upsert(member) }
        isJoining = false
        hasChosenToBrowse = true
        updatePhase()
        persist { try await $0.save(member) }
    }

    /// Saves a dinner, and shows its Volume (its year). Members only.
    func save(_ dinner: Dinner) {
        guard isMember else { return }
        edit { $0.dinners.upsert(dinner) }
        volumeID = dinner.volume.id
        persist { try await $0.save(dinner) }
    }

    func delete(_ dinner: Dinner) {
        guard isMember else { return }
        edit { $0.dinners.removeAll { $0.id == dinner.id } }
        persist { try await $0.delete(dinner) }
    }

    /// My order for the Volume on screen, best first (every dinner listed counts as placed).
    func setMyOrder(_ dinnerIDs: [String]) {
        guard isMember, let volume else { return }
        let ranking = Ranking(memberID: meID, volumeID: volume.id, order: dinnerIDs)
        edit {
            $0.rankings.removeAll { $0.id == ranking.id }
            $0.rankings.append(ranking)
        }
        persist { try await $0.save(ranking) }
    }

    func saveMyReview(of dinnerID: String, note: String, bestDish: String, scores: [ScoreCategory: Double]) {
        guard isMember else { return }
        let review = Review(memberID: meID, dinnerID: dinnerID,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            bestDish: bestDish.trimmingCharacters(in: .whitespacesAndNewlines),
                            scores: scores.mapValues(ScoreCategory.clean))
        edit { $0.reviews.upsert(review) }
        persist { try await $0.save(review) }
    }

    /// A guest's scores for a dinner the club has rated.
    func saveMyGuestScores(of dinnerID: String, scores: [ScoreCategory: Double]) {
        guard canScoreAsGuest, clubHasRated(dinnerID) else { return }
        let review = Review(memberID: meID, dinnerID: dinnerID, scores: scores.mapValues(ScoreCategory.clean))
        edit { $0.guestReviews.upsert(review) }
        persist { try await $0.saveGuestReview(review) }
    }

    /// Adds photos to a dinner (JPEG data), the first becoming the cover if it has none.
    func addPhotos(_ jpegs: [Data], to dinnerID: String) async {
        guard isMember else { return }
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

    /// Changes the snapshot now, and keeps the change for a minute over fresh loads.
    private func edit(_ apply: @escaping (inout ClubSnapshot) -> Void) {
        apply(&snapshot)
        recentEdits.append((.now, apply))
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

extension Array where Element: Identifiable, Element.ID == String {
    /// Replaces the item with the same id, or adds it.
    mutating func upsert(_ item: Element) {
        if let index = firstIndex(where: { $0.id == item.id }) { self[index] = item } else { append(item) }
    }
}
