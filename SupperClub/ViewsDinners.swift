//
//  ViewsDinners.swift
//  10PM Supper Club
//
//  The Volume's dinners as a gallery or on a dark map of the city; a dinner's page (cover and
//  photos, where it ranks for the club and for each of you, everyone's note and best dish, the
//  address); adding a dinner (find it with Apple Maps, pick the date and who was there, add a
//  cover); and inviting friends (the club's iCloud share).
//

import CloudKit
import MapKit
import PhotosUI
import SwiftUI

// MARK: - Dinners

struct DinnersView: View {
    @Environment(ClubStore.self) private var store
    @State private var showsMap = false
    @State private var adding = false

    var body: some View {
        ClubPage(title: "Dinners") {
            Group {
                if showsMap {
                    DinnerMap(dinners: store.dinners)
                } else {
                    ScrollView {
                        if store.dinners.isEmpty {
                            EmptyState(title: "The table's set", message: "Add the first dinner of \(store.volume?.title ?? "the Volume").")
                                .padding(.top, 60)
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(store.dinners) { dinner in
                                NavigationLink(value: dinner) { DinnerTile(dinner: dinner) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationDestination(for: Dinner.self) { DinnerDetailView(dinnerID: $0.id) }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.snappy) { showsMap.toggle() }
                    } label: {
                        Image(systemName: showsMap ? "square.grid.2x2" : "map")
                    }
                    .accessibilityLabel(showsMap ? "Show as gallery" : "Show on map")
                    Button { adding = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add a dinner")
                }
            }
            .sheet(isPresented: $adding) { AddDinnerView() }
        }
    }
}

private struct DinnerTile: View {
    let dinner: Dinner
    @Environment(ClubStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DinnerCover(dinner: dinner)
                .frame(height: 130)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topLeading) {
                    if let rank = store.standings.firstIndex(where: { $0.dinner.id == dinner.id }), store.standings[rank].average != nil {
                        Text("\(rank + 1)")
                            .font(Club.serif(16))
                            .foregroundStyle(Club.black)
                            .frame(width: 28, height: 28)
                            .background(Club.cream, in: Circle())
                            .padding(10)
                    }
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(dinner.name)
                    .font(Club.serif(17))
                    .foregroundStyle(Club.cream)
                    .lineLimit(1)
                SpacedCaps(text: dinner.date.shortDay, size: 9)
            }
            .padding(12)
        }
        .clubCard()
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DinnerMap: View {
    let dinners: [Dinner]
    @State private var selected: String?

    var body: some View {
        Map(selection: $selected) {
            ForEach(dinners.filter(\.hasLocation)) { dinner in
                Annotation(dinner.name, coordinate: CLLocationCoordinate2D(latitude: dinner.latitude!, longitude: dinner.longitude!)) {
                    NavigationLink(value: dinner) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Club.black)
                            .frame(width: 30, height: 30)
                            .background(Club.cream, in: Circle())
                    }
                }
                .tag(dinner.id)
            }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .colorScheme(.dark)
    }
}

// MARK: - A dinner

struct DinnerDetailView: View {
    let dinnerID: String
    @Environment(ClubStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editingReview = false
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var confirmDelete = false

    var body: some View {
        if let dinner = store.dinner(dinnerID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DinnerCover(dinner: dinner)
                        .frame(height: 280)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            LinearGradient(colors: [.clear, Club.black.opacity(0.95)], startPoint: .center, endPoint: .bottom)
                        }
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 8) {
                                SpacedCaps(text: dinner.date.longDay, size: 10, color: Club.cream.opacity(0.85))
                                Text(dinner.name)
                                    .font(Club.serif(36))
                                    .foregroundStyle(Club.cream)
                                if !dinner.subtitle.isEmpty {
                                    SpacedCaps(text: dinner.subtitle, size: 10)
                                }
                            }
                            .padding(20)
                        }

                    rankings(dinner).padding(.horizontal, 16)
                    reviews(dinner).padding(.horizontal, 16)
                    photos(dinner)
                    details(dinner).padding(.horizontal, 16)
                }
                .padding(.bottom, 40)
            }
            .ignoresSafeArea(edges: .top)
            .background(Club.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { editingReview = true } label: { Label("My Note & Best Dish", systemImage: "square.and.pencil") }
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Delete Dinner", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis") }
                }
            }
            .confirmationDialog("Delete \(dinner.name) for everyone?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Dinner", role: .destructive) {
                    store.delete(dinner)
                    dismiss()
                }
            }
            .sheet(isPresented: $editingReview) { ReviewEditor(dinner: dinner) }
            .onChange(of: pickedPhotos) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    var jpegs: [Data] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self), let jpeg = Self.jpeg(data) { jpegs.append(jpeg) }
                    }
                    pickedPhotos = []
                    await store.addPhotos(jpegs, to: dinner.id)
                }
            }
        } else {
            EmptyState(title: "Dinner removed", message: "Someone deleted this dinner.")
        }
    }

    /// Photos are shrunk to 1600 px on the long side, so they upload quickly.
    static func jpeg(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.8)
    }

    @ViewBuilder
    private func rankings(_ dinner: Dinner) -> some View {
        let rows = store.standings
        let index = rows.firstIndex { $0.dinner.id == dinner.id }
        let row = index.map { rows[$0] }
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SpacedCaps(text: "Club rank", size: 10)
                Spacer()
                if let index, row?.average != nil {
                    Text("#\(index + 1)")
                        .font(Club.serif(28))
                        .foregroundStyle(Club.cream)
                    Text("of \(rows.count)")
                        .font(Club.italic(15))
                        .foregroundStyle(Club.muted)
                } else {
                    Text("Not ranked yet").font(Club.italic(16)).foregroundStyle(Club.muted)
                }
            }
            Divider().overlay(Club.hairline)
            HStack(spacing: 0) {
                ForEach(store.members.filter { dinner.attendeeIDs.contains($0.id) }) { member in
                    VStack(spacing: 6) {
                        MemberBadge(member: member, size: 34, isMe: member.id == store.meID)
                        Text(row?.positions[member.id].map { "\($0)" } ?? "–")
                            .font(Club.serif(20))
                            .foregroundStyle(Club.cream)
                        SpacedCaps(text: member.id == store.meID ? "You" : member.firstName, size: 8.5)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .clubCard()
    }

    @ViewBuilder
    private func reviews(_ dinner: Dinner) -> some View {
        let reviews = store.reviews(for: dinner.id)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SpacedCaps(text: "Notes from the table", size: 10)
                Spacer()
                Button { editingReview = true } label: {
                    SpacedCaps(text: store.review(by: store.meID, of: dinner.id)?.isEmpty == false ? "Edit mine" : "Add mine",
                               size: 9.5, color: Club.cream)
                }
            }
            if reviews.isEmpty {
                Text("No notes yet. What was the dish of the night?")
                    .font(Club.italic(16))
                    .foregroundStyle(Club.muted)
            }
            ForEach(reviews) { review in
                HStack(alignment: .top, spacing: 12) {
                    MemberBadge(member: store.member(review.memberID), size: 30, isMe: review.memberID == store.meID)
                    VStack(alignment: .leading, spacing: 6) {
                        if !review.bestDish.isEmpty {
                            HStack(spacing: 6) {
                                SpacedCaps(text: "Best", size: 8.5, color: Club.faint)
                                Text(review.bestDish).font(Club.serif(16)).foregroundStyle(Club.cream)
                            }
                        }
                        if !review.note.isEmpty {
                            Text("“\(review.note)”").font(Club.italic(16)).foregroundStyle(Club.cream.opacity(0.85))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .clubCard()
            }
        }
    }

    @ViewBuilder
    private func photos(_ dinner: Dinner) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SpacedCaps(text: "Photos", size: 10)
                Spacer()
                PhotosPicker(selection: $pickedPhotos, maxSelectionCount: 10, matching: .images) {
                    SpacedCaps(text: "Add", size: 9.5, color: Club.cream)
                }
            }
            .padding(.horizontal, 16)
            if dinner.photoIDs.isEmpty {
                Text("Add photos from the night.")
                    .font(Club.italic(16))
                    .foregroundStyle(Club.muted)
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(dinner.photoIDs, id: \.self) { id in
                            PhotoThumb(photoID: id)
                                .frame(width: 150, height: 190)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func details(_ dinner: Dinner) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SpacedCaps(text: "The spot", size: 10)
            if dinner.hasLocation {
                let coordinate = CLLocationCoordinate2D(latitude: dinner.latitude!, longitude: dinner.longitude!)
                Map(initialPosition: .camera(MapCamera(centerCoordinate: coordinate, distance: 1200))) {
                    Marker(dinner.name, coordinate: coordinate).tint(Club.cream)
                }
                .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
                .colorScheme(.dark)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .allowsHitTesting(false)
            }
            if !dinner.address.isEmpty {
                Button {
                    openInMaps(dinner)
                } label: {
                    HStack {
                        Text(dinner.address).font(Club.serif(16)).foregroundStyle(Club.cream)
                        Spacer()
                        Image(systemName: "arrow.up.right").foregroundStyle(Club.muted)
                    }
                    .padding(14)
                    .clubCard()
                }
                .buttonStyle(.plain)
            }
            if let adder = store.member(dinner.addedBy) {
                Text("Added by \(adder.firstName)")
                    .font(Club.italic(14))
                    .foregroundStyle(Club.faint)
            }
        }
    }

    private func openInMaps(_ dinner: Dinner) {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [URLQueryItem(name: "q", value: dinner.name), URLQueryItem(name: "address", value: dinner.address)]
        if let url = components.url { UIApplication.shared.open(url) }
    }
}

private struct PhotoThumb: View {
    let photoID: String
    @Environment(ClubStore.self) private var store
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Club.raised
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ProgressView().tint(Club.muted)
            }
        }
        .clipped()
        .task { image = await store.image(photoID) }
    }
}

private struct ReviewEditor: View {
    let dinner: Dinner
    @Environment(ClubStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var bestDish = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Best dish") {
                    TextField("The one you'd order again", text: $bestDish)
                        .font(Club.serif(18))
                }
                Section("Your note") {
                    TextField("How was the night?", text: $note, axis: .vertical)
                        .font(Club.italic(17))
                        .lineLimit(3...8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Club.black)
            .navigationTitle(dinner.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.saveMyReview(of: dinner.id, note: note, bestDish: bestDish)
                        dismiss()
                    }
                }
            }
            .onAppear {
                let mine = store.review(by: store.meID, of: dinner.id)
                note = mine?.note ?? ""
                bestDish = mine?.bestDish ?? ""
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Adding a dinner

struct AddDinnerView: View {
    @Environment(ClubStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var search = RestaurantSearch()
    @State private var name = ""
    @State private var address = ""
    @State private var neighborhood = ""
    @State private var cuisine = ""
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var date = Date()
    @State private var attendees: Set<String> = []
    @State private var cover: PhotosPickerItem?
    @State private var coverImage: UIImage?
    @State private var bestDish = ""
    @State private var note = ""
    @State private var isSaving = false

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !attendees.isEmpty && !isSaving }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Search restaurants", text: $search.query)
                        .font(Club.serif(18))
                        .autocorrectionDisabled()
                    ForEach(search.results.prefix(5), id: \.self) { result in
                        Button {
                            Task { await choose(result) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title).font(Club.serif(17)).foregroundStyle(Club.cream)
                                Text(result.subtitle).font(.caption).foregroundStyle(Club.muted)
                            }
                        }
                    }
                } header: {
                    Text("Find it")
                }

                Section("The dinner") {
                    TextField("Restaurant", text: $name).font(Club.serif(18))
                    TextField("Neighborhood", text: $neighborhood)
                    TextField("Cuisine", text: $cuisine)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    if !address.isEmpty {
                        Text(address).font(.footnote).foregroundStyle(Club.muted)
                    }
                }

                Section("Who was there") {
                    ForEach(store.members) { member in
                        Button {
                            if attendees.contains(member.id) { attendees.remove(member.id) } else { attendees.insert(member.id) }
                        } label: {
                            HStack {
                                MemberBadge(member: member, size: 28, isMe: member.id == store.meID)
                                Text(member.id == store.meID ? "\(member.name) (you)" : member.name)
                                    .foregroundStyle(Club.cream)
                                Spacer()
                                Image(systemName: attendees.contains(member.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(attendees.contains(member.id) ? Club.cream : Club.faint)
                            }
                        }
                    }
                }

                Section("Cover photo") {
                    PhotosPicker(selection: $cover, matching: .images) {
                        if let coverImage {
                            Image(uiImage: coverImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Label("Choose a photo", systemImage: "photo")
                        }
                    }
                }

                Section("Your take (optional)") {
                    TextField("Best dish", text: $bestDish)
                    TextField("A note on the night", text: $note, axis: .vertical).lineLimit(2...5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Club.black)
            .navigationTitle("New Dinner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await save() } }.disabled(!canSave)
                }
            }
            .onAppear { attendees = Set(store.members.map(\.id)) }
            .onChange(of: cover) { _, item in
                Task {
                    guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                    coverImage = UIImage(data: data)
                }
            }
        }
    }

    private func choose(_ result: MKLocalSearchCompletion) async {
        guard let item = await search.details(for: result) else {
            name = result.title
            return
        }
        name = item.name ?? result.title
        let placemark = item.placemark
        let street = [placemark.subThoroughfare, placemark.thoroughfare].compactMap { $0 }.joined(separator: " ")
        address = [street, placemark.locality ?? ""].filter { !$0.isEmpty }.joined(separator: ", ")
        neighborhood = placemark.subLocality ?? neighborhood
        if let category = item.pointOfInterestCategory { cuisine = Self.cuisineName(category) ?? cuisine }
        coordinate = placemark.coordinate
        search.query = ""
    }

    private static func cuisineName(_ category: MKPointOfInterestCategory) -> String? {
        switch category {
        case .bakery: return "Bakery"
        case .brewery: return "Brewery"
        case .cafe: return "Café"
        case .winery: return "Wine Bar"
        case .nightlife: return "Bar"
        default: return nil
        }
    }

    private func save() async {
        guard let volume = store.volume else { return }
        isSaving = true
        var dinner = Dinner(volumeID: volume.id, name: name.trimmingCharacters(in: .whitespaces), address: address,
                            neighborhood: neighborhood, cuisine: cuisine, date: date,
                            latitude: coordinate?.latitude, longitude: coordinate?.longitude,
                            attendeeIDs: store.members.map(\.id).filter(attendees.contains), addedBy: store.meID)
        store.save(dinner)
        if !bestDish.isEmpty || !note.isEmpty { store.saveMyReview(of: dinner.id, note: note, bestDish: bestDish) }
        if let cover, let data = try? await cover.loadTransferable(type: Data.self), let jpeg = DinnerDetailView.jpeg(data) {
            await store.addPhotos([jpeg], to: dinner.id)
            dinner = store.dinner(dinner.id) ?? dinner
        }
        isSaving = false
        dismiss()
    }
}

/// Apple Maps search for restaurants as you type.
@Observable
final class RestaurantSearch: NSObject, MKLocalSearchCompleterDelegate {
    var query = "" {
        didSet { completer.queryFragment = query }
    }
    private(set) var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .pointOfInterest
        completer.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant, .cafe, .bakery, .brewery, .winery, .nightlife])
        // Around New York City unless told otherwise.
        completer.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.73, longitude: -73.99),
                                              latitudinalMeters: 30_000, longitudinalMeters: 30_000)
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in self.results = query.isEmpty ? [] : results }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {}

    func details(for completion: MKLocalSearchCompletion) async -> MKMapItem? {
        try? await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start().mapItems.first
    }
}

// MARK: - Inviting

/// The club's invite: iOS's share sheet for the iCloud share (copy the link, or send it in Messages).
struct InviteSheet: View {
    @Environment(ClubStore.self) private var store
    @State private var share: CKShare?
    @State private var error: String?

    var body: some View {
        Group {
            if let share, let cloud = store.backend as? CloudKitBackend {
                CloudSharingView(share: share, container: cloud.container)
                    .ignoresSafeArea()
            } else if let error {
                EmptyState(title: "Couldn't open the invite", message: error)
            } else {
                ProgressView().tint(Club.cream)
            }
        }
        .background(Club.black)
        .task {
            guard let cloud = store.backend as? CloudKitBackend else { error = "Invites need iCloud."; return }
            do { share = try await cloud.clubShare() } catch { self.error = error.localizedDescription }
        }
    }
}

private struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPublic]
        return controller
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}
}
