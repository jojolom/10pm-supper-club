//
//  ViewsTheme.swift
//  10PM Supper Club
//
//  The look, from the club's merch: near-black, cream embroidery-coloured type, a classic
//  serif (Baskerville) for names and numbers, wide-spaced capitals for labels, and thin cream
//  rules. Shared pieces: the wordmark, the Volume label, member initials, cards.
//

import SwiftUI

enum Club {
    static let black = Color(red: 0.043, green: 0.043, blue: 0.047)
    static let card = Color(red: 0.085, green: 0.084, blue: 0.088)
    static let raised = Color(red: 0.13, green: 0.128, blue: 0.133)
    static let cream = Color(red: 0.914, green: 0.882, blue: 0.812)
    static let muted = Color(red: 0.58, green: 0.56, blue: 0.52)
    static let faint = Color(red: 0.36, green: 0.35, blue: 0.33)
    static let hairline = Color.white.opacity(0.1)

    static func serif(_ size: CGFloat, bold: Bool = true) -> Font {
        .custom(bold ? "Baskerville-SemiBold" : "Baskerville", size: size, relativeTo: .body)
    }

    static func italic(_ size: CGFloat) -> Font {
        .custom("Baskerville-Italic", size: size, relativeTo: .body)
    }
}

/// Wide-spaced capitals, like "SUPPER CLUB" on the cap.
struct SpacedCaps: View {
    let text: String
    var size: CGFloat = 12
    var color: Color = Club.muted
    var bold = true

    var body: some View {
        Text(text.uppercased())
            .font(Club.serif(size, bold: bold))
            .tracking(size * 0.28)
            .foregroundStyle(color)
    }
}

/// The club's mark: "10 PM" over a rule, "SUPPER CLUB", and optionally "EST. 2025".
struct Wordmark: View {
    var scale: CGFloat = 1
    var showsEst = true

    var body: some View {
        VStack(spacing: 6 * scale) {
            Text("10 PM")
                .font(Club.serif(46 * scale))
                .foregroundStyle(Club.cream)
                .fixedSize()
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Club.cream)
                        .frame(height: max(1, 1.6 * scale))
                        .padding(.horizontal, -6 * scale)
                        .offset(y: 4 * scale)
                }
                .padding(.bottom, 4 * scale)
            SpacedCaps(text: "Supper Club", size: 15 * scale, color: Club.cream)
            if showsEst {
                SpacedCaps(text: "Est. 2025", size: 9 * scale, color: Club.cream.opacity(0.8))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("10 PM Supper Club")
    }
}

/// "— VOLUME II · 2026 —".
struct VolumeLabel: View {
    let volume: Volume?
    var size: CGFloat = 11

    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Club.faint).frame(width: 18, height: 1)
            SpacedCaps(text: volume.map { "Volume \(Volume.roman($0.number)) · \(String($0.year))" } ?? "Volume I", size: size, color: Club.muted)
            Rectangle().fill(Club.faint).frame(width: 18, height: 1)
        }
    }
}

/// A member's initials in a thin cream ring; filled for you.
struct MemberBadge: View {
    let member: Member?
    var size: CGFloat = 30
    var isMe = false

    var body: some View {
        Text(member?.initials ?? "?")
            .font(Club.serif(size * 0.42))
            .foregroundStyle(isMe ? Club.black : Club.cream)
            .frame(width: size, height: size)
            .background(Circle().fill(isMe ? Club.cream : Club.raised))
            .overlay(Circle().stroke(Club.cream.opacity(isMe ? 0 : 0.35), lineWidth: 1))
            .accessibilityLabel(member?.name ?? "Unknown")
    }
}

/// A rank numeral: big serif, brightest for first.
struct RankNumeral: View {
    let rank: Int
    var size: CGFloat = 34

    var body: some View {
        Text("\(rank)")
            .font(Club.serif(size))
            .foregroundStyle(rank == 1 ? Club.cream : Club.cream.opacity(rank <= 3 ? 0.85 : 0.55))
            .monospacedDigit()
            .frame(minWidth: size * 0.9, alignment: .center)
    }
}

struct ClubCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Club.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Club.hairline, lineWidth: 1))
    }
}

extension View {
    func clubCard() -> some View { modifier(ClubCard()) }
}

/// A dinner's cover photo, or a quiet placeholder with its initial.
struct DinnerCover: View {
    let dinner: Dinner
    @Environment(ClubStore.self) private var store
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Club.raised, Club.card], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(String(dinner.name.prefix(1)))
                    .font(Club.serif(40))
                    .foregroundStyle(Club.cream.opacity(0.18))
            }
        }
        .clipped()
        .task(id: dinner.photoIDs.first) {
            guard let id = dinner.photoIDs.first else { image = nil; return }
            image = await store.image(id)
        }
    }
}

extension Date {
    /// "Oct 12".
    var shortDay: String { formatted(.dateTime.month(.abbreviated).day()) }
    /// "October 12, 2026".
    var longDay: String { formatted(.dateTime.month(.wide).day().year()) }
}
