//
//  SupperClubApp.swift
//  10PM Supper Club
//
//  Entry point. Picks the backend (iCloud, or the demo club for debug builds launched with
//  `-demo YES`, as a guest with `-guest YES`) and keeps the club fresh while the app is open.
//  Anyone can also open the demo club from the welcome screen (`\.showDemo`), to try what
//  members can do; nothing in it is saved.
//

import SwiftUI

@main
struct SupperClubApp: App {
    @State private var store: ClubStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        let defaults = UserDefaults.standard
        let backend: ClubBackend = defaults.bool(forKey: "demo") ? DemoBackend(asGuest: defaults.bool(forKey: "guest")) : CloudKitBackend()
        #else
        let backend: ClubBackend = CloudKitBackend()
        #endif
        _store = State(initialValue: ClubStore(backend: backend))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.showDemo) { demo in
                    store = ClubStore(backend: demo ? DemoBackend() : CloudKitBackend())
                    Task { await store.start() }
                }
                .preferredColorScheme(.dark)
                .tint(Club.cream)
                .task { await store.start() }
                .task {
                    // Pick up friends' changes while the app is open.
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(30))
                        if scenePhase == .active, store.phase == .ready { await store.refresh() }
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active, store.phase == .ready { Task { await store.refresh() } }
                }
        }
    }
}

extension EnvironmentValues {
    /// Switches to the demo club (true) or back to the real one (false).
    @Entry var showDemo: (Bool) -> Void = { _ in }
}
