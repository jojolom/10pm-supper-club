//
//  ServicesCloudKitBackend.swift
//  10PM Supper Club
//
//  The real club, in iCloud: one record zone ("SupperClub") in the private database of
//  whoever started the club, shared with the others through a zone-wide CKShare they join by
//  an invite link. The founder reads and writes it in their private database; members in
//  their shared database. Records: Member, Dinner, Ranking, Review (note, best dish, and a
//  score_<category> field per category scored), and Photo (its
//  image as an asset, fetched only when shown). Everything is small, so a load fetches the
//  whole zone. Each member writes only their own Ranking and Review records, so friends'
//  edits never collide.
//

import CloudKit
import Foundation

final class CloudKitBackend: ClubBackend {

    static let containerID = "iCloud.com.joelombardi.tenpmsupperclub"
    static let zoneName = "SupperClub"

    let container = CKContainer(identifier: containerID)

    private enum Role: String {
        case founder, member
    }

    private let defaults = UserDefaults.standard
    private var role: Role? {
        get { defaults.string(forKey: "club.role").flatMap(Role.init(rawValue:)) }
        set { defaults.set(newValue?.rawValue, forKey: "club.role") }
    }
    /// For a member: the founder's user record name, which owns the zone.
    private var zoneOwner: String? {
        get { defaults.string(forKey: "club.zoneOwner") }
        set { defaults.set(newValue, forKey: "club.zoneOwner") }
    }

    var hasClub: Bool { role != nil }

    private var database: CKDatabase {
        role == .member ? container.sharedCloudDatabase : container.privateCloudDatabase
    }

    private var zoneID: CKRecordZone.ID {
        if role == .member, let zoneOwner {
            return CKRecordZone.ID(zoneName: Self.zoneName, ownerName: zoneOwner)
        }
        return CKRecordZone.ID(zoneName: Self.zoneName)
    }

    // MARK: Account and club

    enum CloudError: LocalizedError {
        case noAccount
        var errorDescription: String? { "iCloud isn't available. Sign in to iCloud in Settings." }
    }

    func currentUserID() async throws -> String {
        guard try await container.accountStatus() == .available else { throw CloudError.noAccount }
        return try await container.userRecordID().recordName
    }

    func createClub() async throws {
        let zone = CKRecordZone(zoneName: Self.zoneName)
        _ = try await container.privateCloudDatabase.modifyRecordZones(saving: [zone], deleting: [])
        let share = CKShare(recordZoneID: zone.zoneID)
        share[CKShare.SystemFieldKey.title] = "10PM Supper Club"
        // Anyone with the invite link can join and edit; the link only goes to the four of you.
        share.publicPermission = .readWrite
        _ = try await container.privateCloudDatabase.modifyRecords(saving: [share], deleting: [])
        role = .founder
        zoneOwner = nil
    }

    /// The club's share, for inviting friends (founder only).
    func clubShare() async throws -> CKShare {
        let id = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: CKRecordZone.ID(zoneName: Self.zoneName))
        guard let share = try await container.privateCloudDatabase.record(for: id) as? CKShare else {
            throw CKError(.unknownItem)
        }
        return share
    }

    var isFounder: Bool { role == .founder }

    /// Joins the club from a friend's invite (or, for the founder, reopens their own).
    func accept(_ metadata: CKShare.Metadata) async throws {
        if metadata.participantRole == .owner {
            role = .founder
            zoneOwner = nil
            return
        }
        _ = try await container.accept(metadata)
        role = .member
        zoneOwner = metadata.share.recordID.zoneID.ownerName
    }

    // MARK: Loading

    private static let fields = ["name", "joined", "volumeID", "address", "neighborhood", "cuisine",
                                 "date", "latitude", "longitude", "attendeeIDs", "addedBy", "photoIDs", "memberID",
                                 "order", "updated", "dinnerID", "note", "bestDish"]
        + ScoreCategory.allCases.map { "score_\($0.rawValue)" }

    func load() async throws -> ClubSnapshot {
        var snapshot = ClubSnapshot()
        var token: CKServerChangeToken? = nil
        var more = true
        while more {
            // Every field but the photos' images, which load when they're shown.
            let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: token, desiredKeys: Self.fields)
            for case .success(let modification) in changes.modificationResultsByID.values {
                Self.add(modification.record, to: &snapshot)
            }
            token = changes.changeToken
            more = changes.moreComing
        }
        return snapshot
    }

    private static func add(_ record: CKRecord, to snapshot: inout ClubSnapshot) {
        let name = record.recordID.recordName
        switch record.recordType {
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
            var scores: [ScoreCategory: Double] = [:]
            for category in ScoreCategory.allCases {
                if let score = record["score_\(category.rawValue)"] as? Double { scores[category] = ScoreCategory.clean(score) }
            }
            snapshot.reviews.append(Review(memberID: record["memberID"] as? String ?? "", dinnerID: record["dinnerID"] as? String ?? "",
                                           note: record["note"] as? String ?? "", bestDish: record["bestDish"] as? String ?? "",
                                           scores: scores, updated: record["updated"] as? Date ?? .now))
        default:
            break
        }
    }

    // MARK: Saving

    private func record(_ type: String, _ name: String, _ fields: [String: Any?]) -> CKRecord {
        let record = CKRecord(recordType: type, recordID: CKRecord.ID(recordName: name, zoneID: zoneID))
        for (key, value) in fields {
            // Empty lists are left unset: CloudKit can't tell an empty list's type.
            if let list = value as? [String], list.isEmpty { continue }
            record[key] = value as? __CKRecordObjCValue
        }
        return record
    }

    private func write(_ record: CKRecord) async throws {
        _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys)
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
        let ids = ([dinner.id] + dinner.photoIDs).map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
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
        let record = try await database.record(for: CKRecord.ID(recordName: id, zoneID: zoneID))
        guard let url = (record["image"] as? CKAsset)?.fileURL else { return nil }
        return try Data(contentsOf: url)
    }
}
