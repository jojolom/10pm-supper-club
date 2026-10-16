//
//  ViewsRoot.swift
//  10PM Supper Club
//
//  What's on screen for where you stand: loading, no club yet (start it), first open (in the
//  club, or just browsing), asked for your name, or the club itself: the Club's ranking, My
//  List (members only), Dinners, Members.
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
            case .noClub, .welcome:
                WelcomeView()
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

/// First open: start the club if nobody has, otherwise say you're in it (and ask to be let in)
/// or just look around as a guest.
struct WelcomeView: View {
    @Environment(ClubStore.self) private var store
    @State private var isStarting = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Wordmark(scale: 1.35)
            Spacer()
            VStack(spacing: 16) {
                if store.phase == .noClub {
                    if store.isSignedIn {
                        WelcomeButton(title: "Start the Club", isWorking: isStarting) {
                            isStarting = true
                            Task {
                                do { try await store.startClub() } catch { self.error = error.localizedDescription }
                                isStarting = false
                            }
                        }
                    } else {
                        note("Sign in to iCloud in Settings to start the club.")
                    }
                } else {
                    WelcomeButton(title: "Just Browsing") { store.browse() }
                    if store.isSignedIn {
                        WelcomeButton(title: "I'm in the Club", isPrimary: false) { store.askToJoin() }
                        note("Browse the club's dinners and score the ones they've rated. In the club? Ask to be let in.")
                    } else {
                        note("Browse the club's dinners. To score them, sign in to iCloud in Settings.")
                    }
                }
                if let error = error ?? store.lastError {
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

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Club.italic(16))
            .foregroundStyle(Club.muted)
            .multilineTextAlignment(.center)
    }
}

/// A full-width capsule: cream for the main choice, outlined for the other.
private struct WelcomeButton: View {
    let title: String
    var isPrimary = true
    var isWorking = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isWorking { ProgressView().tint(Club.black) }
                SpacedCaps(text: title, size: 14, color: isPrimary ? Club.black : Club.cream)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isPrimary ? Club.cream : .clear, in: Capsule())
            .overlay(Capsule().stroke(Club.cream.opacity(isPrimary ? 0 : 0.5), lineWidth: 1))
        }
        .disabled(isWorking)
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
                Text(store.isMember ? "What should the club call you?"
                     : "Tell the club who you are, and \(store.founder?.firstName ?? "the founder") will let you in.")
                    .font(Club.italic(17))
                    .foregroundStyle(Club.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
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
                SpacedCaps(text: store.isMember ? "Take My Seat" : "Ask to Join", size: 14, color: Club.black)
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
            if store.isMember {
                Tab("My List", systemImage: "arrow.up.arrow.down", value: 1) {
                    NavigationStack { MyListView() }
                }
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

/// The top of each tab: the Volume on screen (a year), tap to switch.
struct VolumeSwitcher: View {
    @Environment(ClubStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Menu {
            Picker("Volume", selection: Binding(get: { store.volume?.id }, set: { store.volumeID = $0 })) {
                ForEach(store.volumes.reversed()) { volume in
                    Text("\(volume.title) · \(String(volume.year))").tag(Optional(volume.id))
                }
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
        .accessibilityLabel("Volume, \(store.volume.map { "\($0.title), \(String($0.year))" } ?? "")")
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
