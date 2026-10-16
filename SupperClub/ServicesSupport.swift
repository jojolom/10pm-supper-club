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

    /// A drafted email reporting a dinner's page (its notes, photos or scores).
    static func reportURL(about dinner: Dinner) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: "10PM: report \(dinner.name)"),
            URLQueryItem(name: "body", value: "What's wrong on the \(dinner.name) page (dinner \(dinner.id))?\n\n"),
        ]
        return components.url ?? URL(string: "mailto:\(email)")!
    }
}
