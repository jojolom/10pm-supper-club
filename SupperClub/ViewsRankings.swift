//
//  ViewsRankings.swift
//  10PM Supper Club
//
//  The rankings: the Club's (everyone's lists combined by average position, each person's spot
//  shown under it), My List (your own order: drag a dinner up or down; new dinners wait at the
//  bottom until you place them), and Members (anyone's list, side by side with the club's, with
//  their category scores under each dinner; for the founder, people asking to join).
//

import SwiftUI

// MARK: - Club

struct ClubRankingView: View {
    @Environment(ClubStore.self) private var store

    var body: some View {
        ClubPage(title: "The Club") {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 14) {
                        Wordmark(scale: 0.9)
                        VolumeLabel(volume: store.volume)
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 6)

                    if !store.isMember { GuestNote() }

                    let rows = store.standings
                    if rows.isEmpty {
                        EmptyState(title: "No dinners yet",
                                   message: store.isMember ? "Add the first dinner of the Volume from the Dinners tab." : "The club hasn't been out this Volume yet.")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                                NavigationLink(value: row.dinner) {
                                    ClubRow(rank: index + 1, row: row)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("Ranked by average spot across everyone's lists.")
                            .font(Club.italic(14))
                            .foregroundStyle(Club.faint)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationDestination(for: Dinner.self) { DinnerDetailView(dinnerID: $0.id) }
        }
    }
}

/// For guests, at the top of the Club page: what they can do, or that they're waiting to be let in.
private struct GuestNote: View {
    @Environment(ClubStore.self) private var store

    var body: some View {
        let text = store.hasAskedToJoin
            ? "You've asked to join. \(store.founder?.firstName ?? "The founder") will let you in. Until then, you're a guest."
            : store.isSignedIn
                ? "You're a guest. Score any dinner the club has rated; yours count toward the guest average."
                : "You're a guest. Sign in to iCloud to score dinners."
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: store.hasAskedToJoin ? "hourglass" : "person.2")
                .font(.system(size: 13))
                .foregroundStyle(Club.muted)
            Text(text)
                .font(Club.italic(15))
                .foregroundStyle(Club.muted)
            Spacer(minLength: 0)
        }
        .padding(14)
        .clubCard()
    }
}

private struct ClubRow: View {
    let rank: Int
    let row: Standings.Row
    @Environment(ClubStore.self) private var store

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            RankNumeral(rank: rank, size: rank == 1 ? 44 : 34)
            VStack(alignment: .leading, spacing: 6) {
                Text(row.dinner.name)
                    .font(Club.serif(rank == 1 ? 24 : 20))
                    .foregroundStyle(Club.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if !row.dinner.subtitle.isEmpty {
                    SpacedCaps(text: row.dinner.subtitle, size: 9.5)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    ForEach(store.members.filter { row.dinner.attendeeIDs.contains($0.id) }) { member in
                        HStack(spacing: 3) {
                            MemberBadge(member: member, size: 18, isMe: member.id == store.meID)
                            Text(row.positions[member.id].map { "\($0)" } ?? "–")
                                .font(Club.serif(12))
                                .foregroundStyle(row.positions[member.id] == 1 ? Club.cream : Club.muted)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                if let average = row.average {
                    Text(average.formatted(.number.precision(.fractionLength(1))))
                        .font(Club.serif(20))
                        .foregroundStyle(Club.cream)
                    SpacedCaps(text: "Avg", size: 8.5, color: Club.faint)
                } else {
                    SpacedCaps(text: "New", size: 9, color: Club.cream)
                }
            }
        }
        .padding(16)
        .clubCard()
        .overlay {
            if rank == 1 {
                RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Club.cream.opacity(0.45), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - My List

struct MyListView: View {
    @Environment(ClubStore.self) private var store
    /// The order on screen; saved after every move.
    @State private var order: [Dinner] = []
    @State private var newIDs: Set<String> = []

    var body: some View {
        ClubPage(title: "My List") {
            List {
                Section {
                    VStack(spacing: 6) {
                        Text("Your ranking")
                            .font(Club.serif(26))
                            .foregroundStyle(Club.cream)
                        Text(newIDs.isEmpty ? "Hold and drag to move a dinner up or down." : "New dinners are at the bottom. Drag them into place.")
                            .font(Club.italic(15))
                            .foregroundStyle(Club.muted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if order.isEmpty {
                    EmptyState(title: "Nothing to rank", message: "Dinners you were at show up here.")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(Array(order.enumerated()), id: \.element.id) { index, dinner in
                            MyListRow(rank: index + 1, dinner: dinner, isNew: newIDs.contains(dinner.id))
                                .listRowBackground(Club.card)
                                .listRowSeparatorTint(Club.hairline)
                        }
                        .onMove(perform: move)
                    }
                    if !newIDs.isEmpty {
                        Section {
                            Button {
                                save()
                            } label: {
                                SpacedCaps(text: "Keep this order", size: 12, color: Club.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Club.cream, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .onAppear(perform: load)
            .onChange(of: store.dinners) { load() }
            .onChange(of: store.volume?.id) { load() }
        }
    }

    private func load() {
        let list = store.list(for: store.meID)
        order = list.ranked + list.new
        newIDs = Set(list.new.map(\.id))
    }

    private func move(from source: IndexSet, to destination: Int) {
        withAnimation(.snappy) { order.move(fromOffsets: source, toOffset: destination) }
        save()
    }

    /// Everything on screen counts as placed once you've moved something or kept the order.
    private func save() {
        store.setMyOrder(order.map(\.id))
        withAnimation { newIDs = [] }
    }
}

private struct MyListRow: View {
    let rank: Int
    let dinner: Dinner
    let isNew: Bool

    var body: some View {
        HStack(spacing: 14) {
            RankNumeral(rank: rank, size: 28)
            DinnerCover(dinner: dinner)
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(dinner.name)
                    .font(Club.serif(19))
                    .foregroundStyle(Club.cream)
                    .lineLimit(1)
                SpacedCaps(text: [dinner.neighborhood, dinner.date.shortDay].filter { !$0.isEmpty }.joined(separator: " · "), size: 9)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if isNew {
                SpacedCaps(text: "New", size: 9, color: Club.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Club.cream, in: Capsule())
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Drag to move it up or down")
    }
}

// MARK: - Members

struct MembersView: View {
    @Environment(ClubStore.self) private var store
    @Environment(\.showDemo) private var showDemo
    @State private var selected: String?
    @State private var showRename = false
    @State private var newName = ""
    @State private var confirmRemove = false
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    /// Where friends get the app (its App Store page); then they tap "I'm in the Club".
    static let inviteURL = URL(string: "https://apps.apple.com/app/id6823010763")!

    private var memberID: String { selected ?? (store.isMember ? store.meID : store.members.first?.id ?? "") }

    var body: some View {
        ClubPage(title: "Members") {
            ScrollView {
                VStack(spacing: 22) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(store.members) { member in
                                Button {
                                    withAnimation(.snappy) { selected = member.id }
                                } label: {
                                    VStack(spacing: 8) {
                                        MemberBadge(member: member, size: 58, isMe: member.id == memberID)
                                        SpacedCaps(text: member.id == store.meID ? "You" : member.firstName, size: 10,
                                                   color: member.id == memberID ? Club.cream : Club.muted)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(member.id == memberID ? .isSelected : [])
                            }
                            if store.isMember {
                                ShareLink(item: Self.inviteURL, message: Text(Self.inviteMessage)) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 20, weight: .light))
                                            .foregroundStyle(Club.cream)
                                            .frame(width: 58, height: 58)
                                            .overlay(Circle().stroke(Club.cream.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                                        SpacedCaps(text: "Invite", size: 10)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }

                    if store.isFounder, !store.requests.isEmpty { requests }
                    memberList
                }
                .padding(.bottom, 32)
            }
            .navigationDestination(for: Dinner.self) { DinnerDetailView(dinnerID: $0.id) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if store.me != nil {
                            Button {
                                newName = store.me?.name ?? ""
                                showRename = true
                            } label: { Label("Change My Name", systemImage: "pencil") }
                        } else if store.isSignedIn {
                            Button { store.askToJoin() } label: { Label("I'm in the Club", systemImage: "person.badge.plus") }
                        }
                        ShareLink(item: Self.inviteURL, message: Text(store.isMember ? Self.inviteMessage : Self.shareMessage)) {
                            Label(store.isMember ? "Invite Friends" : "Share the App", systemImage: "square.and.arrow.up")
                        }
                        if let other = store.member(memberID), other.id != store.meID {
                            Section(other.firstName) {
                                if store.isBlocked(other.id) {
                                    Button { store.unblock(other.id) } label: { Label("Unblock \(other.firstName)", systemImage: "hand.raised.slash") }
                                } else {
                                    Button { store.block(other.id) } label: { Label("Block \(other.firstName)", systemImage: "hand.raised") }
                                }
                                if store.isFounder {
                                    Button(role: .destructive) { confirmRemove = true } label: {
                                        Label("Remove from the Club", systemImage: "person.badge.minus")
                                    }
                                }
                            }
                        }
                        Section {
                            Link(destination: Support.pageURL) { Label("Support & Privacy", systemImage: "questionmark.circle") }
                            if !store.isMember, !store.isDemo {
                                Button { showDemo(true) } label: { Label("Explore the Demo Club", systemImage: "sparkles") }
                            }
                            if store.hasMyInfo {
                                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete My Info", systemImage: "trash") }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .alert("Your Name", isPresented: $showRename) {
                TextField("Name", text: $newName)
                Button("Save") { store.setMyName(newName) }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Remove \(store.member(memberID)?.firstName ?? "them") from the club?", isPresented: $confirmRemove,
                                titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    let id = memberID
                    withAnimation(.snappy) {
                        selected = nil
                        store.removeFromClub(id)
                    }
                }
            } message: {
                Text("Their rankings, notes, scores and the dinners they added stop showing, and they can't ask to join again.")
            }
            .confirmationDialog("Delete your info?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete My Info", role: .destructive) { deleteMyInfo() }
            } message: {
                Text(store.isFounder
                     ? "This deletes your name, rankings, notes and scores from iCloud. Dinners and photos stay with the club, and you stay its founder. This can't be undone."
                     : "This deletes your name, rankings, notes and scores from iCloud, and you'll be a guest. Dinners and photos stay with the club. This can't be undone.")
            }
            .alert("Couldn't Delete Your Info", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
            .overlay {
                if isDeleting { ProgressView().tint(Club.cream) }
            }
        }
    }

    private func deleteMyInfo() {
        isDeleting = true
        Task {
            do {
                try await store.deleteMyInfo()
                selected = nil
            } catch {
                deleteError = error.localizedDescription
            }
            isDeleting = false
        }
    }

    private static let inviteMessage = "Get the 10PM app, then tap \u{201C}I'm in the Club\u{201D} and we'll let you in."
    private static let shareMessage = "The 10PM Supper Club's dinners, ranked."

    /// For the founder: people asking to join.
    private var requests: some View {
        VStack(alignment: .leading, spacing: 10) {
            SpacedCaps(text: "Asking to join", size: 10)
                .padding(.horizontal, 4)
            ForEach(store.requests) { person in
                HStack(spacing: 12) {
                    MemberBadge(member: person, size: 34)
                    Text(person.name)
                        .font(Club.serif(19))
                        .foregroundStyle(Club.cream)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Button("Decline") { withAnimation(.snappy) { store.turnDown(person.id) } }
                        .font(Club.serif(14, bold: false))
                        .foregroundStyle(Club.muted)
                    Button {
                        withAnimation(.snappy) { store.letIn(person.id) }
                    } label: {
                        SpacedCaps(text: "Let In", size: 10, color: Club.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Club.cream, in: Capsule())
                    }
                }
                .buttonStyle(.plain)
                .padding(14)
                .clubCard()
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var memberList: some View {
        let member = store.member(memberID)
        let list = store.list(for: memberID)
        let clubRank = Dictionary(uniqueKeysWithValues: store.standings.enumerated().map { ($1.dinner.id, $0 + 1) })
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(memberID == store.meID ? "Your list" : "\(member?.firstName ?? "Their")'s list")
                    .font(Club.serif(24))
                    .foregroundStyle(Club.cream)
                Spacer()
                // Heads the right-hand column: where the club put each dinner.
                if !list.ranked.isEmpty, !store.isBlocked(memberID) {
                    SpacedCaps(text: "Club rank", size: 9, color: Club.faint)
                }
            }
            .padding(.horizontal, 4)

            if store.isBlocked(memberID) {
                EmptyState(title: "Blocked",
                           message: "You've blocked \(member?.firstName ?? "them"), so their list, notes and scores are hidden. Unblock them from the \u{2026} menu.")
            } else if list.ranked.isEmpty {
                EmptyState(title: "Not ranked yet",
                           message: memberID == store.meID ? "Put this Volume's dinners in order in My List."
                                                           : "Their list fills in once they rank this Volume.")
            }
            ForEach(Array((store.isBlocked(memberID) ? [] : list.ranked).enumerated()), id: \.element.id) { index, dinner in
                NavigationLink(value: dinner) {
                    HStack(spacing: 14) {
                        RankNumeral(rank: index + 1, size: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dinner.name)
                                .font(Club.serif(19))
                                .foregroundStyle(Club.cream)
                                .lineLimit(1)
                            let review = store.review(by: memberID, of: dinner.id)
                            if let best = review?.bestDish, !best.isEmpty {
                                Text("Best: \(best)")
                                    .font(Club.italic(14))
                                    .foregroundStyle(Club.muted)
                                    .lineLimit(1)
                            }
                            if let scores = review?.scores, !scores.isEmpty {
                                ScoreStrip(scores: scores)
                            }
                        }
                        Spacer(minLength: 0)
                        if let club = clubRank[dinner.id] {
                            ComparisonMark(theirs: index + 1, club: club)
                        }
                    }
                    .padding(14)
                    .clubCard()
                }
                .buttonStyle(.plain)
            }
            if !list.new.isEmpty, !store.isBlocked(memberID) {
                Text("\(list.new.count) new \(list.new.count == 1 ? "dinner" : "dinners") still to place.")
                    .font(Club.italic(14))
                    .foregroundStyle(Club.faint)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
    }
}

/// Where the club put it, next to where this member did: "#2" with an arrow when they differ.
private struct ComparisonMark: View {
    let theirs: Int
    let club: Int

    var body: some View {
        HStack(spacing: 4) {
            if theirs != club {
                Image(systemName: theirs < club ? "arrow.up" : "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Club.muted)
            }
            Text("#\(club)")
                .font(Club.serif(15))
                .foregroundStyle(Club.muted)
                .monospacedDigit()
        }
        .accessibilityLabel(theirs == club ? "Same as the club" : "Club has it at \(club)")
    }
}

struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(Club.serif(22))
                .foregroundStyle(Club.cream)
            Text(message)
                .font(Club.italic(15))
                .foregroundStyle(Club.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
