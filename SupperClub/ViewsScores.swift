//
//  ViewsScores.swift
//  10PM Supper Club
//
//  Category scores (Food, Drinks, Service, Cigability, Vibe; 1–10 in half points): the sliders
//  for scoring a dinner, the table of everyone's scores on a dinner's page (with the guests'
//  average apart), and the compact line under a dinner in someone's list. Scores are each
//  person's own; they never move the club's order.
//

import SwiftUI

/// A slider per category for Form rows; a category stays blank until you touch it.
struct ScoreEditor: View {
    @Binding var scores: [ScoreCategory: Double]

    var body: some View {
        ForEach(ScoreCategory.allCases) { category in
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Label(category.title, systemImage: category.symbol)
                        .font(Club.serif(17))
                        .foregroundStyle(Club.cream)
                    Spacer()
                    if let score = scores[category] {
                        Text(ScoreCategory.format(score))
                            .font(Club.serif(22))
                            .foregroundStyle(Club.cream)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Button {
                            scores[category] = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Club.faint)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Clear \(category.title)")
                    } else {
                        Text("–").font(Club.serif(22)).foregroundStyle(Club.faint)
                    }
                }
                if let detail = category.detail {
                    Text(detail).font(Club.italic(13)).foregroundStyle(Club.muted)
                }
                Slider(value: Binding(get: { scores[category] ?? 5.5 },
                                      set: { scores[category] = ScoreCategory.clean($0) }),
                       in: ScoreCategory.range, step: 0.5)
                    .tint(scores[category] == nil ? Club.faint : Club.cream)
                    .accessibilityLabel(category.title)
                    .accessibilityValue(scores[category].map(ScoreCategory.format) ?? "Not scored")
            }
            .padding(.vertical, 4)
            .animation(.snappy, value: scores[category])
        }
    }
}

/// Everyone's scores for a dinner: a row per category, a column per member who was there, and
/// a last column for the guests' average (kept apart from the club's). A guest sees their own
/// scores underneath, and can score it once the club has.
struct ScoresCard: View {
    let dinner: Dinner
    private static let labelWidth: CGFloat = 104
    let onScore: () -> Void
    @Environment(ClubStore.self) private var store

    var body: some View {
        let members = store.members.filter { dinner.attendeeIDs.contains($0.id) }
        let reviews = Dictionary(uniqueKeysWithValues: members.compactMap { member in
            store.review(by: member.id, of: dinner.id).map { (member.id, $0) }
        })
        let guests = store.guestReviews(for: dinner.id)
        let guestAverages = ScoreCategory.averages(guests.map(\.scores))
        let anyScores = reviews.values.contains { !$0.scores.isEmpty } || !guests.isEmpty
        let mine = store.myGuestReview(of: dinner.id)?.scores ?? [:]
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SpacedCaps(text: "Scores", size: 10)
                Spacer()
                if let label = buttonLabel(memberScored: reviews[store.meID]?.scores.isEmpty == false, guestScored: !mine.isEmpty) {
                    Button(action: onScore) { SpacedCaps(text: label, size: 9.5, color: Club.cream) }
                }
            }
            if anyScores {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Color.clear.frame(width: Self.labelWidth, height: 1)
                        ForEach(members) { member in
                            MemberBadge(member: member, size: 26, isMe: member.id == store.meID)
                                .frame(maxWidth: .infinity)
                        }
                        if !guests.isEmpty {
                            GuestsBadge(count: guests.count, size: 26).frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(ScoreCategory.allCases) { category in
                        HStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: category.symbol)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Club.muted)
                                    .frame(width: 18)
                                Text(category.title)
                                    .font(Club.serif(15))
                                    .foregroundStyle(Club.cream)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(width: Self.labelWidth, alignment: .leading)
                            ForEach(members) { member in
                                let score = reviews[member.id]?.scores[category]
                                Text(score.map(ScoreCategory.format) ?? "–")
                                    .font(Club.serif(17))
                                    .foregroundStyle(score == nil ? Club.faint : (score! >= 9 ? Club.cream : Club.cream.opacity(0.8)))
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity)
                            }
                            if !guests.isEmpty {
                                let average = guestAverages[category]
                                Text(average.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "–")
                                    .font(Club.italic(16))
                                    .foregroundStyle(average == nil ? Club.faint : Club.muted)
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity)
                                    .accessibilityLabel(average.map { "Guests \(ScoreCategory.format($0))" } ?? "")
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                Text("No scores yet. Food, drinks, service, cigability, vibe: out of 10.")
                    .font(Club.italic(16))
                    .foregroundStyle(Club.muted)
            }
            if !store.isMember {
                guestFooter(mine: mine)
            }
        }
        .padding(18)
        .clubCard()
    }

    /// "Score it" / "Edit mine": members always; guests once the club has rated it.
    private func buttonLabel(memberScored: Bool, guestScored: Bool) -> String? {
        if store.isMember { return memberScored ? "Edit mine" : "Score it" }
        guard store.canScoreAsGuest, store.clubHasRated(dinner.id) else { return nil }
        return guestScored ? "Edit mine" : "Score it"
    }

    @ViewBuilder
    private func guestFooter(mine: [ScoreCategory: Double]) -> some View {
        Divider().overlay(Club.hairline)
        if !mine.isEmpty {
            HStack(spacing: 10) {
                SpacedCaps(text: "Yours", size: 8.5, color: Club.faint)
                ScoreStrip(scores: mine)
            }
        } else if !store.clubHasRated(dinner.id) {
            Text("Guests can score it once the club has rated it.")
                .font(Club.italic(14))
                .foregroundStyle(Club.faint)
        } else if !store.isSignedIn {
            Text("Sign in to iCloud to add your scores.")
                .font(Club.italic(14))
                .foregroundStyle(Club.faint)
        } else {
            Text("Been? Add your scores to the guest average.")
                .font(Club.italic(14))
                .foregroundStyle(Club.faint)
        }
    }
}

/// One person's scores for a dinner in a line: an icon and a number per category scored.
struct ScoreStrip: View {
    let scores: [ScoreCategory: Double]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ScoreCategory.allCases.filter { scores[$0] != nil }) { category in
                HStack(spacing: 3) {
                    Image(systemName: category.symbol)
                        .font(.system(size: 10))
                        .foregroundStyle(Club.faint)
                    Text(ScoreCategory.format(scores[category]!))
                        .font(Club.serif(13))
                        .foregroundStyle(Club.muted)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(category.title) \(ScoreCategory.format(scores[category]!))")
            }
        }
    }
}
