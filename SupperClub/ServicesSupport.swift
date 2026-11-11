//
//  ServicesSupport.swift
//  10PM Supper Club
//
//  Where people reach the club: the support and privacy page (also the App Store listing's
//  support and privacy URL, from docs/index.html), and an email to report something on a
//  dinner's page.
//

import Foundation

enum Support {
    static let email = "jojolom.lombardi@icloud.com"
    static let pageURL = URL(string: "https://jojolom.github.io/10pm-supper-club/")!
    /// The terms everyone agrees to before adding anything: no objectionable content.
    static let termsURL = URL(string: "https://jojolom.github.io/10pm-supper-club/#terms")!

    /// A drafted email reporting a dinner's page (its notes, photos or scores), or one note on it.
    static func reportURL(about dinner: Dinner, note: Review? = nil, by author: Member? = nil) -> URL {
        var body = "What's wrong on the \(dinner.name) page (dinner \(dinner.id))?\n\n"
        if let note {
            // Say which note, so it can be found and taken down.
            let words = [note.bestDish.isEmpty ? nil : "Best: \(note.bestDish)", note.note.isEmpty ? nil : "\u{201C}\(note.note)\u{201D}"]
            body = "Reporting \(author?.name ?? "a member")'s note on \(dinner.name) (\(note.id)):\n"
                + words.compactMap { $0 }.joined(separator: "\n") + "\n\nWhat's wrong with it?\n\n"
        }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: "10PM: report \(note == nil ? dinner.name : "a note on \(dinner.name)")"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url ?? URL(string: "mailto:\(email)")!
    }
}
