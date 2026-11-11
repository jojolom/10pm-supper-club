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
        // The demo bar sits above every screen (not over it: an inset would cover the tabs'
        // toolbars).
        VStack(spacing: 0) {
            if store.isDemo, !Self.hidesDemoBar { DemoBar() }
            phaseView
        }
        .background(Club.black.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.35), value: store.phase)
    }

    /// Debug builds launched with `-noDemoBar YES` leave it off, for App Store screenshots.
    #if DEBUG
    private static let hidesDemoBar = UserDefaults.standard.bool(forKey: "noDemoBar")
    #else
    private static let hidesDemoBar = false
    #endif

    private var phaseView: some View {
        ZStack {
            Club.black.ignoresSafeArea()
            switch store.phase {
            case .loading:
                Wordmark(scale: 1.1)
            case .unreachable:
                UnreachableView()
            case .noClub, .welcome:
                WelcomeView()
            case .needsProfile:
                ProfileSetupView()
            case .ready:
                ClubTabs()
            }
        }
    }
}

// MARK: - Welcome

/// First open: start the club if nobody has, otherwise say you're in it (and ask to be let in)
/// or just look around as a guest.
struct WelcomeView: View {
    @Environment(ClubStore.self) private var store
    @Environment(\.showDemo) private var showDemo
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
                if !store.isDemo {
                    Button { showDemo(true) } label: {
                        Text("Explore the demo club")
                            .font(Club.serif(16))
                            .underline()
                            .foregroundStyle(Club.cream.opacity(0.85))
                    }
                    .padding(.top, 4)
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

/// The first load failed (offline, or iCloud is down): say so and try again, rather than
/// guessing there's no club.
private struct UnreachableView: View {
    @Environment(ClubStore.self) private var store
    @Environment(\.showDemo) private var showDemo

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Wordmark(scale: 1.35)
            Spacer()
            VStack(spacing: 16) {
                Text("Can't reach the club right now. Check your connection.")
                    .font(Club.italic(16))
                    .foregroundStyle(Club.muted)
                    .multilineTextAlignment(.center)
                WelcomeButton(title: "Try Again", isWorking: store.isRefreshing) {
                    Task { await store.start() }
                }
                Button { showDemo(true) } label: {
                    Text("Explore the demo club")
                        .font(Club.serif(16))
                        .underline()
                        .foregroundStyle(Club.cream.opacity(0.85))
                }
                .padding(.top, 4)
                if let error = store.lastError {
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
            TermsNote(action: store.isMember ? "taking your seat" : "asking to join")
                .padding(.horizontal, 32)
                .padding(.bottom, store.isMember ? 24 : 4)
            if !store.isMember {
                // A way back for anyone who tapped "I'm in the Club" by mistake.
                Button("Not now") { store.cancelJoining() }
                    .font(Club.serif(16))
                    .foregroundStyle(Club.muted)
                    .padding(.bottom, 16)
            }
        }
        .onAppear { focused = true }
    }

    private func save() { store.setMyName(name) }
}

/// "By asking to join, you agree to the Terms…": shown wherever someone adds to the club.
struct TermsNote: View {
    let action: String

    var body: some View {
        Text("By \(action), you agree to the [Terms](\(Support.termsURL.absoluteString)): nothing offensive, abusive or unlawful. Report anything that is, and it's reviewed within 24 hours.")
            .font(Club.italic(13))
            .foregroundStyle(Club.faint)
            .tint(Club.muted)
            .multilineTextAlignment(.center)
    }
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
        // My List goes when you leave the club (removed, or deleted your info): don't sit on it.
        .onChange(of: store.isMember) { _, isMember in
            if !isMember, tab == 1 { tab = 0 }
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

/// Common chrome for a tab's page: black, the Volume switcher, pull to refresh (with the club's
/// cap for a spinner), save errors.
struct ClubPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(ClubStore.self) private var store
    /// How far the page is pulled down past its top (including the gap held open while it
    /// reloads).
    @State private var pull: CGFloat = 0
    /// The page's top inset at rest: while it reloads, the system adds the held-open gap to the
    /// scroll view's inset, which would otherwise read as no pull at all.
    @State private var restingInset: CGFloat?
    @State private var spin: RefreshHat.Spin?

    var body: some View {
        content
            .scrollContentBackground(.hidden)
            .background(Club.black.ignoresSafeArea())
            // The tab bar names the page, so the bar holds only the Volume and the page's actions
            // (a title squeezed between them sat off-center and got cut off). The title still
            // names the back button and VoiceOver's page.
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VolumeSwitcher()
                }
            }
            // Its own task: SwiftUI cancels the refresh action's task when the reload changes
            // what's on screen, which would cut the spin short.
            .refreshable { await Task { await pullToRefresh() }.value }
            .onScrollGeometryChange(for: [CGFloat].self) { geometry in
                [geometry.contentOffset.y, geometry.contentInsets.top]
            } action: { _, scroll in
                if spin == nil { restingInset = scroll[1] }
                pull = max(0, -(scroll[0] + (restingInset ?? scroll[1])))
                if pull < 1, spin?.end != nil { spin = nil }
            }
            .overlay(alignment: .top) { RefreshHat(pull: pull, spin: spin) }
            .safeAreaInset(edge: .top) {
                if let error = store.saveError { SaveErrorBar(message: error) }
            }
    }
}

extension ClubPage {
    /// Spins the cap the other way, fast, while it reloads (for at least a beat, so a quick
    /// reload still shows the spin).
    private func pullToRefresh() async {
        let started = Date.now
        spin = RefreshHat.Spin(start: started, from: RefreshHat.angle(forPull: pull))
        await store.refresh()
        let rest = 1.2 - Date.now.timeIntervalSince(started)
        if rest > 0 { try? await Task.sleep(for: .seconds(rest)) }
        spin?.end = .now
    }
}

/// Pull to refresh's spinner: the club's cap, turning slowly as the page is pulled down, then
/// spinning fast the other way once it reloads. (The system spinner is hidden in the app's init.)
struct RefreshHat: View {
    let pull: CGFloat
    let spin: Spin?

    struct Spin: Equatable {
        var start: Date
        /// Where the slow turn had got to when the reload began.
        var from: Double
        /// When the reload finished: the cap stops there and fades as the page settles.
        var end: Date?
    }

    private static let width: CGFloat = 76
    /// Degrees per point pulled, and per second while reloading (the other way).
    private static let dragTurn = 1.6
    private static let spinSpeed = 900.0

    static func angle(forPull pull: CGFloat) -> Double { Double(pull) * dragTurn }

    var body: some View {
        let height = Self.width * 0.8
        // Sized to the gap the pull opens and centred in it, the same way while dragging, while
        // reloading (a gap of about 60 points) and while the page settles, so it never covers
        // the page or jumps in size. Its width bounds it however it's turned.
        let fit = min(1, max(0, (pull - 8) / Self.width))
        TimelineView(.animation(paused: spin == nil || spin?.end != nil)) { context in
            ClubHat(width: Self.width, fabric: Club.raised, line: Club.cream, thread: Club.cream)
                .rotationEffect(.degrees(angle(at: context.date)))
        }
        .frame(width: Self.width, height: height)
        .scaleEffect(fit)
        .opacity(min(1, fit * 2.5))
        .offset(y: pull / 2 - height / 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func angle(at date: Date) -> Double {
        guard let spin else { return Self.angle(forPull: pull) }
        return spin.from - (spin.end ?? date).timeIntervalSince(spin.start) * Self.spinSpeed
    }
}

/// An edit iCloud wouldn't save: says so (rather than letting it quietly vanish), tap to dismiss.
private struct SaveErrorBar: View {
    let message: String
    @Environment(ClubStore.self) private var store

    var body: some View {
        Button { store.dismissSaveError() } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.icloud")
                Text(message).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "xmark").font(.caption)
            }
            .font(.footnote)
            .foregroundStyle(Club.cream)
            .padding(12)
            .background(Color.red.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}

/// Across the top of the demo club: it's a sample, and the way back.
private struct DemoBar: View {
    @Environment(\.showDemo) private var showDemo

    var body: some View {
        HStack(spacing: 10) {
            SpacedCaps(text: "Demo club", size: 9.5, color: Club.black)
            Text("Sample dinners. Nothing is saved.")
                .font(Club.italic(13))
                .foregroundStyle(Club.black.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Button { showDemo(false) } label: {
                SpacedCaps(text: "Leave", size: 9.5, color: Club.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(Capsule().stroke(Club.black.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Club.cream, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}
