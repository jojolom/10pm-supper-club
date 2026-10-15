//
//  ViewsScores.swift
//  10PM Supper Club
//
//  Category scores (Food, Drinks, Service, Cigability, Vibe; 1–10 in half points): the sliders
//  for scoring a dinner, the table of everyone's scores on a dinner's page, and the compact
//  line under a dinner in someone's list. Scores are each person's own; they never move the
//  club's order.
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

/// Everyone's scores for a dinner: a row per category, a column per person who was there.
struct ScoresCard: View {
    let dinner: Dinner
    private static let labelWidth: CGFloat = 112
    let onScore: () -> Void
    @Environment(ClubStore.self) private var store

    var body: some View {
        let members = store.members.filter { dinner.attendeeIDs.contains($0.id) }
        let reviews = Dictionary(uniqueKeysWithValues: members.compactMap { member in
            store.review(by: member.id, of: dinner.id).map { (member.id, $0) }
        })
        let anyScores = reviews.values.contains { !$0.scores.isEmpty }
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SpacedCaps(text: "Scores", size: 10)
                Spacer()
                Button(action: onScore) {
                    SpacedCaps(text: reviews[store.meID]?.scores.isEmpty == false ? "Edit mine" : "Score it", size: 9.5, color: Club.cream)
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
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                Text("No scores yet. Food, drinks, service, cigability, vibe: out of 10.")
                    .font(Club.italic(16))
                    .foregroundStyle(Club.muted)
            }
        }
        .padding(18)
        .clubCard()
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
