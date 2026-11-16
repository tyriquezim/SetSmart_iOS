import SwiftUI

struct AddFoodView: View {
    var meal: Meal
    var eatenOn: String
    var onAdded: (FoodLog) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var recents: [RecentFood] = []
    @State private var myFoods: [Food] = []
    @State private var usdaResults: [Food] = []
    @State private var offResults: [Food] = []
    @State private var isSearching = false
    @State private var isLoadingRecents = true
    @State private var searchError: String?
    @State private var selectedFood: Food?
    @State private var showScanner = false
    @State private var showQuickAdd = false
    @State private var showNewFood = false
    @State private var searchTask: Task<Void, Never>?

    private let repo = FoodRepository()
    private let usda = USDAService()
    private let off  = OFFService()

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty { emptyState } else { searchResults }
            }
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search foods…"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showScanner  = true } label: { Label("Scan Barcode", systemImage: "barcode.viewfinder") }
                        Button { showQuickAdd = true } label: { Label("Quick Add",    systemImage: "bolt.fill") }
                        Button { showNewFood  = true } label: { Label("New Food",     systemImage: "plus") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .onChange(of: query) { _, new in debounceSearch(new) }
            .task { await loadRecents() }
            .sheet(item: $selectedFood) { food in
                AmountSheetView(food: food, meal: meal, eatenOn: eatenOn) { log in
                    onAdded(log)
                    dismiss()
                }
                .environment(appState)
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView(onScan: handleBarcode, onDismiss: { showScanner = false })
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddView(meal: meal, eatenOn: eatenOn) { log in onAdded(log); dismiss() }
                    .environment(appState)
            }
            .sheet(isPresented: $showNewFood) {
                FoodDetailFormView(mode: .create) { food in selectedFood = food }
                    .environment(appState)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        List {
            if isLoadingRecents {
                HStack { Spacer(); ProgressView(); Spacer() }.listRowBackground(Color.ssBackground)
            } else {
                if !recents.isEmpty {
                    Section("Recents") {
                        ForEach(recents) { recent in
                            foodRow(recent.food) { selectedFood = recent.food }
                        }
                    }
                }
                if !myFoods.isEmpty {
                    Section("My Foods") {
                        ForEach(myFoods) { food in
                            foodRow(food) { selectedFood = food }
                        }
                    }
                }
                if recents.isEmpty && myFoods.isEmpty {
                    Section {
                        Text("Search above, scan a barcode, or Quick Add.")
                            .font(.subheadline)
                            .foregroundStyle(Color.ssTextMuted)
                            .listRowBackground(Color.ssBackground)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Search results

    private var searchResults: some View {
        List {
            if isSearching {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.ssBackground)
            }
            if let searchError {
                Section {
                    Text(searchError)
                        .foregroundStyle(Color.ssWarningText)
                        .listRowBackground(Color.ssBackground)
                }
            }

            let local = localMatches
            if !local.isEmpty {
                Section("Your Foods") {
                    ForEach(local) { food in foodRow(food) { selectedFood = food } }
                }
            }
            if !usdaResults.isEmpty {
                Section("USDA Database") {
                    ForEach(usdaResults) { food in foodRow(food) { selectedFood = food } }
                }
            }
            if !offResults.isEmpty {
                Section("Open Food Facts") {
                    ForEach(offResults) { food in foodRow(food) { selectedFood = food } }
                }
            }
            if !isSearching && usdaResults.isEmpty && offResults.isEmpty && local.isEmpty {
                Section {
                    Text("No results for \"\(query)\".")
                        .font(.subheadline)
                        .foregroundStyle(Color.ssTextMuted)
                        .listRowBackground(Color.ssBackground)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var localMatches: [Food] {
        let all = recents.map(\.food) + myFoods
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            ($0.brand ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Row

    private func foodRow(_ food: Food, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name).foregroundStyle(Color.ssTextPrimary)
                    if let brand = food.brand {
                        Text(brand).font(.caption).foregroundStyle(Color.ssTextMuted)
                    }
                }
                Spacer()
                Text("\(Int(food.energyKj.rounded())) kJ")
                    .font(.caption)
                    .foregroundStyle(Color.ssTextSecondary)
            }
        }
        .listRowBackground(Color.ssSurface)
    }

    // MARK: - Networking

    private func loadRecents() async {
        isLoadingRecents = true
        do {
            async let r = repo.fetchRecents()
            async let m = repo.fetchMyFoods()
            (recents, myFoods) = try await (r, m)
        } catch {}
        isLoadingRecents = false
    }

    private func debounceSearch(_ newQuery: String) {
        searchTask?.cancel()
        usdaResults = []
        offResults = []
        searchError = nil
        guard !newQuery.isEmpty else { isSearching = false; return }

        let q = newQuery
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await search(query: q)
        }
    }

    private func search(query: String) async {
        isSearching = true
        do {
            async let u = usda.search(query: query)
            async let o = off.search(query: query)
            let (ur, or) = try await (u, o)
            usdaResults = ur
            offResults  = or
        } catch {
            searchError = "Search failed: \(error.localizedDescription)"
        }
        isSearching = false
    }

    private func handleBarcode(_ code: String) {
        showScanner = false
        Task {
            isSearching = true
            do {
                if let food = try await off.lookup(barcode: code) {
                    selectedFood = food
                } else {
                    searchError = "No product found for barcode \(code)."
                }
            } catch {
                searchError = "Barcode lookup failed: \(error.localizedDescription)"
            }
            isSearching = false
        }
    }
}
