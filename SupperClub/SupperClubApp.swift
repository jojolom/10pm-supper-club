//
//  SupperClubApp.swift
//  10PM Supper Club
//
//  Entry point. Picks the backend (iCloud, or the demo club for debug builds launched with
//  `-demo YES`, as a guest with `-guest YES`) and keeps the club fresh while the app is open.
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
