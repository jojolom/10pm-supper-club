//
//  ViewsRoot.swift
//  10PM Supper Club
//
//  What's on screen for where you stand: loading, iCloud missing, not in a club yet (start one
//  or open a friend's invite), asked for your name, or the club itself: four tabs (the Club's
//  ranking, My List, Dinners, Members).
//

import SwiftUI

struct RootView: View {
    @Environment(ClubStore.self) private var store

    var body: some View {
        ZStack {
            Club.black.ignoresSafeArea()
            switch store.phase {
            case .loading:
                Wordmark(scale: 1.1)
            case .noAccount(let message):
                WelcomeView(message: message)
            case .noClub:
                WelcomeView(message: nil)
            case .needsProfile:
                ProfileSetupView()
            case .ready:
                ClubTabs()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: store.phase)
    }
}

// MARK: - Welcome

struct WelcomeView: View {
    let message: String?
    @Environment(ClubStore.self) private var store
    @State private var inbox = ShareInbox.shared
    @State private var isStarting = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Wordmark(scale: 1.35)
            Spacer()
            VStack(spacing: 16) {
                if let message {
                    Text(message)
                        .font(Club.italic(17))
                        .foregroundStyle(Club.muted)
                        .multilineTextAlignment(.center)
                } else {
                    Button {
                        isStarting = true
                        Task {
                            do { try await store.createClub() } catch { self.error = error.localizedDescription }
                            isStarting = false
                        }
                    } label: {
                        HStack {
                            if isStarting { ProgressView().tint(Club.black) }
                            SpacedCaps(text: "Start the Club", size: 14, color: Club.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Club.cream, in: Capsule())
                    }
                    .disabled(isStarting)
                    Text("Got an invite? Open the link a friend sent you, and you're in.")
                        .font(Club.italic(16))
                        .foregroundStyle(Club.muted)
                        .multilineTextAlignment(.center)
                }
                if let error = error ?? inbox.error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
            SpacedCaps(text: "New York City", size: 10, color: Club.faint)
                .padding(.bottom, 12)
        }
    }
}

// MARK: - Profile

struct ProfileSetupView: View {
    @Environment(ClubStore.self) private var store
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Wordmark(scale: 0.8, showsEst: false)
            VStack(spacing: 10) {
                Text("Your seat at the table")
                    .font(Club.serif(28))
                    .foregroundStyle(Club.cream)
                Text("What should the club call you?")
                    .font(Club.italic(17))
                    .foregroundStyle(Club.muted)
            }
            TextField("", text: $name, prompt: Text("Your name").foregroundStyle(Club.faint))
                .font(Club.serif(26))
                .foregroundStyle(Club.cream)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($focused)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Club.cream.opacity(0.5)).frame(height: 1) }
                .padding(.horizontal, 48)
                .onSubmit(save)
            Spacer()
            Button(action: save) {
                SpacedCaps(text: "Take My Seat", size: 14, color: Club.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Club.cream.opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.35 : 1), in: Capsule())
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .onAppear { focused = true }
    }

    private func save() { store.setMyName(name) }
}

// MARK: - Tabs

struct ClubTabs: View {
    /// Debug builds can open on a tab (`-tab 2`) or a dinner (`-dinner carbone`), for screenshots.
    #if DEBUG
    @State private var tab = UserDefaults.standard.integer(forKey: "tab")
    @State private var path: [Dinner] = []
    #else
    @State private var tab = 0
    @State private var path: [Dinner] = []
    #endif
    @Environment(ClubStore.self) private var store

    var body: some View {
        TabView(selection: $tab) {
            Tab("Club", systemImage: "crown", value: 0) {
                NavigationStack(path: $path) { ClubRankingView() }
            }
            Tab("My List", systemImage: "arrow.up.arrow.down", value: 1) {
                NavigationStack { MyListView() }
            }
            Tab("Dinners", systemImage: "fork.knife", value: 2) {
                NavigationStack { DinnersView() }
            }
            Tab("Members", systemImage: "person.2", value: 3) {
                NavigationStack { MembersView() }
            }
        }
        #if DEBUG
        .onAppear {
            if let id = UserDefaults.standard.string(forKey: "dinner"), let dinner = store.dinner(id) { path = [dinner] }
        }
        #endif
    }
}

/// The top of each tab: the Volume on screen, tap to switch or start a new one.
struct VolumeSwitcher: View {
    @Environment(ClubStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Menu {
            Picker("Volume", selection: Binding(get: { store.volume?.id }, set: { store.volumeID = $0 })) {
                ForEach(store.volumes.reversed()) { volume in
                    Text(volume.title).tag(Optional(volume.id))
                }
            }
            Divider()
            Button {
                store.startVolume()
            } label: {
                Label("Start Volume \(Volume.roman((store.volumes.last?.number ?? 0) + 1))", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 6) {
                SpacedCaps(text: store.volume.map { "Vol. \(Volume.roman($0.number))" } ?? "Vol. I", size: 12, color: Club.cream)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Club.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Club.raised, in: Capsule())
        }
        .accessibilityLabel("Volume, \(store.volume?.title ?? "")")
    }
}

/// Common chrome for a tab's page: black, a title in spaced capitals, the Volume switcher.
struct ClubPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(ClubStore.self) private var store

    var body: some View {
        content
            .scrollContentBackground(.hidden)
            .background(Club.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SpacedCaps(text: title, size: 13, color: Club.cream)
                }
                ToolbarItem(placement: .topBarLeading) {
                    VolumeSwitcher()
                }
            }
            .refreshable { await store.refresh() }
    }
}
