//
//  SupperClubApp.swift
//  10PM Supper Club
//
//  Entry point. Picks the backend (iCloud, or the demo club for debug builds launched with
//  `-demo YES`), keeps the club fresh while the app is open, and hands invite links to the
//  backend: iOS delivers an accepted CloudKit share to the scene delegate, which passes it on
//  through ShareInbox.
//

import CloudKit
import SwiftUI
import UIKit

@main
struct SupperClubApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: ClubStore
    @State private var inbox = ShareInbox.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        let demo = UserDefaults.standard.bool(forKey: "demo")
        #else
        let demo = false
        #endif
        _store = State(initialValue: ClubStore(backend: demo ? DemoBackend() : CloudKitBackend()))
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
                .onChange(of: inbox.pending) { _, metadata in
                    guard let metadata, let cloud = store.backend as? CloudKitBackend else { return }
                    inbox.pending = nil
                    Task {
                        do {
                            try await cloud.accept(metadata)
                            await store.joinedClub()
                        } catch {
                            inbox.error = error.localizedDescription
                        }
                    }
                }
        }
    }
}

/// An invite iOS handed the app, waiting to be accepted.
@Observable
final class ShareInbox {
    static let shared = ShareInbox()
    var pending: CKShare.Metadata?
    var error: String?
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    /// An invite opened while the app was closed.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata { ShareInbox.shared.pending = metadata }
    }

    /// An invite opened while the app was running.
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        ShareInbox.shared.pending = metadata
    }
}
