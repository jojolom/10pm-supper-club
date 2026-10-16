//
//  ServicesCloudKitBackend.swift
//  10PM Supper Club
//
//  The real club, in the app's public iCloud database, so anyone with the app can look (even
//  without iCloud); saving needs iCloud. Records: Club (one, "club": the founder and who
//  they've let in; only the founder can change it), Member (a name: members and people asking
//  to join), Dinner, Ranking, Review (note, best dish, and a score_<category> field per
//  category scored), GuestReview (a guest's scores), and Photo (its image as an asset, fetched
//  only when shown). Everyone writes only their own Member, Ranking, Review and GuestReview
//  records (iCloud enforces it); any member can edit a Dinner or its Photos. Everything is
//  small, so a load queries every record of each type.
//

import CloudKit
import Foundation

final class CloudKitBackend: ClubBackend {

    static let containerID = "iCloud.com.joelombardi.tenpmsupperclub"
    static let clubRecordName = "club"

    let container = CKContainer(identifier: containerID)
    private var database: CKDatabase { container.publicCloudDatabase }

    // MARK: Account

    func currentUserID() async -> String? {
        guard (try? await container.accountStatus()) == .available else { return nil }
        return try? await container.userRecordID().recordName
    }

    // MARK: Loading

    private static let types = ["Club", "Member", "Dinner", "Ranking", "Review", "GuestReview"]

    private static let fields = ["founderID", "memberIDs", "declinedIDs", "name", "joined", "volumeID", "address",
                                 "neighborhood", "cuisine", "date", "latitude", "longitude", "attendeeIDs", "addedBy",
                                 "photoIDs", "memberID", "order", "updated", "dinnerID", "note", "bestDish"]
        + ScoreCategory.allCases.map { "score_\($0.rawValue)" }

    func load() async throws -> ClubSnapshot {
        let records = try await withThrowingTaskGroup(of: [CKRecord].self) { group in
            for type in Self.types { group.addTask { try await self.all(type) } }
            return try await group.reduce(into: []) { $0 += $1 }
        }
        var snapshot = ClubSnapshot()
        for record in records { Self.add(record, to: &snapshot) }
        return snapshot
    }

    /// Every record of a type (but the photos' images, which load when they're shown).
    private func all(_ type: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        var page = try await database.records(matching: query, desiredKeys: Self.fields)
        var records = page.matchResults.compactMap { try? $0.1.get() }
        while let cursor = page.queryCursor {
            page = try await database.records(continuingMatchFrom: cursor, desiredKeys: Self.fields)
            records += page.matchResults.compactMap { try? $0.1.get() }
        }
        return records
    }

    private static func add(_ record: CKRecord, to snapshot: inout ClubSnapshot) {
        let name = record.recordID.recordName
        switch record.recordType {
        case "Club":
            guard name == clubRecordName, let founder = record["founderID"] as? String else { return }
            snapshot.club = ClubInfo(founderID: founder, memberIDs: record["memberIDs"] as? [String] ?? [founder],
                                     declinedIDs: record["declinedIDs"] as? [String] ?? [])
        case "Member":
            snapshot.members.append(Member(id: name, name: record["name"] as? String ?? "", joined: record["joined"] as? Date ?? .distantPast))
        case "Dinner":
            snapshot.dinners.append(Dinner(
                id: name, name: record["name"] as? String ?? "",
                address: record["address"] as? String ?? "", neighborhood: record["neighborhood"] as? String ?? "",
                cuisine: record["cuisine"] as? String ?? "", date: record["date"] as? Date ?? .now,
                latitude: record["latitude"] as? Double, longitude: record["longitude"] as? Double,
                attendeeIDs: record["attendeeIDs"] as? [String] ?? [], addedBy: record["addedBy"] as? String ?? "",
                photoIDs: record["photoIDs"] as? [String] ?? []))
        case "Ranking":
            snapshot.rankings.append(Ranking(memberID: record["memberID"] as? String ?? "", volumeID: record["volumeID"] as? String ?? "",
                                             order: record["order"] as? [String] ?? [], updated: record["updated"] as? Date ?? .now))
        case "Review":
            snapshot.reviews.append(review(from: record))
        case "GuestReview":
            snapshot.guestReviews.append(review(from: record))
        default:
            break
        }
    }

    private static func review(from record: CKRecord) -> Review {
        var scores: [ScoreCategory: Double] = [:]
        for category in ScoreCategory.allCases {
            if let score = record["score_\(category.rawValue)"] as? Double { scores[category] = ScoreCategory.clean(score) }
        }
        return Review(memberID: record["memberID"] as? String ?? "", dinnerID: record["dinnerID"] as? String ?? "",
                      note: record["note"] as? String ?? "", bestDish: record["bestDish"] as? String ?? "",
                      scores: scores, updated: record["updated"] as? Date ?? .now)
    }

    // MARK: Saving

    private func record(_ type: String, _ name: String, _ fields: [String: Any?]) -> CKRecord {
        let record = CKRecord(recordType: type, recordID: CKRecord.ID(recordName: name))
        for (key, value) in fields {
            // An empty list is cleared rather than saved: CloudKit can't tell an empty list's type.
            if let list = value as? [String], list.isEmpty { record[key] = nil; continue }
            record[key] = value as? __CKRecordObjCValue
        }
        return record
    }

    private func write(_ record: CKRecord) async throws {
        _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys)
    }

    func save(_ club: ClubInfo) async throws {
        try await write(record("Club", Self.clubRecordName, ["founderID": club.founderID, "memberIDs": club.memberIDs,
                                                            "declinedIDs": club.declinedIDs]))
    }

    func save(_ member: Member) async throws {
        try await write(record("Member", member.id, ["name": member.name, "joined": member.joined]))
    }

    func save(_ dinner: Dinner) async throws {
        try await write(record("Dinner", dinner.id, [
            "name": dinner.name, "address": dinner.address,
            "neighborhood": dinner.neighborhood, "cuisine": dinner.cuisine, "date": dinner.date,
            "latitude": dinner.latitude, "longitude": dinner.longitude, "attendeeIDs": dinner.attendeeIDs,
            "addedBy": dinner.addedBy, "photoIDs": dinner.photoIDs,
        ]))
    }

    func delete(_ dinner: Dinner) async throws {
        let ids = ([dinner.id] + dinner.photoIDs).map { CKRecord.ID(recordName: $0) }
        _ = try await database.modifyRecords(saving: [], deleting: ids)
    }

    func save(_ ranking: Ranking) async throws {
        try await write(record("Ranking", ranking.id, ["memberID": ranking.memberID, "volumeID": ranking.volumeID,
                                                       "order": ranking.order, "updated": ranking.updated]))
    }

    func save(_ review: Review) async throws {
        var fields: [String: Any?] = ["memberID": review.memberID, "dinnerID": review.dinnerID,
                                      "note": review.note, "bestDish": review.bestDish, "updated": review.updated]
        // Every category is written, so clearing a score clears it in iCloud too.
        for category in ScoreCategory.allCases { fields.updateValue(review.scores[category], forKey: "score_\(category.rawValue)") }
        try await write(record("Review", review.id, fields))
    }

    func saveGuestReview(_ review: Review) async throws {
        var fields: [String: Any?] = ["memberID": review.memberID, "dinnerID": review.dinnerID, "updated": review.updated]
        for category in ScoreCategory.allCases { fields.updateValue(review.scores[category], forKey: "score_\(category.rawValue)") }
        try await write(record("GuestReview", "guest-\(review.id)", fields))
    }

    func savePhoto(_ jpeg: Data, dinnerID: String) async throws -> String {
        let id = UUID().uuidString
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(id).jpg")
        try jpeg.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let photo = record("Photo", id, ["dinnerID": dinnerID])
        photo["image"] = CKAsset(fileURL: file)
        try await write(photo)
        return id
    }

    func photo(_ id: String) async throws -> Data? {
        let record = try await database.record(for: CKRecord.ID(recordName: id))
        guard let url = (record["image"] as? CKAsset)?.fileURL else { return nil }
        return try Data(contentsOf: url)
    }
}
