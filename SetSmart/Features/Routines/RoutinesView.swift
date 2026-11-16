import SwiftUI

struct RoutinesView: View {
    @State private var routines: [RoutineSummary] = []
    @State private var isLoading = false
    @State private var showNewRoutine = false
    @State private var showExercises = false
    @State private var routineToDelete: RoutineSummary? = nil

    private let repo = RoutineRepository()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && routines.isEmpty {
                    ProgressView().tint(Color.ssAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if routines.isEmpty {
                    emptyState
                } else {
                    routineList
                }
            }
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("Routines")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showExercises = true } label: {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(Color.ssTextSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewRoutine = true } label: {
                        Image(systemName: "plus").foregroundStyle(Color.ssAccent)
                    }
                }
            }
            .navigationDestination(isPresented: $showExercises) {
                ExercisesView()
            }
            .sheet(isPresented: $showNewRoutine, onDismiss: refresh) {
                NavigationStack { RoutineEditorView() }
            }
            .confirmationDialog(
                "Delete \"\(routineToDelete?.name ?? "")\"?",
                isPresented: Binding(get: { routineToDelete != nil }, set: { if !$0 { routineToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let r = routineToDelete { delete(r) }
                }
            } message: {
                Text("This can't be undone.")
            }
            .task { await load() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle.fill")
                .font(.system(size: 48)).foregroundStyle(Color.ssTextMuted)
            Text("No routines yet")
                .font(.headline).foregroundStyle(Color.ssTextPrimary)
            Text("Create a routine to start tracking workouts.")
                .font(.subheadline).foregroundStyle(Color.ssTextSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button("New routine") { showNewRoutine = true }
                .buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var routineList: some View {
        List {
            ForEach(routines) { routine in
                NavigationLink(destination: RoutineDetailView(routineId: routine.id, onUpdate: refresh)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.ssTextPrimary)
                        Text("\(routine.exerciseCount) exercise\(routine.exerciseCount == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(Color.ssTextSecondary)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.ssSurface)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { routineToDelete = routine } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .refreshable { await load() }
    }

    private func refresh() { Task { await load() } }

    @MainActor
    private func load() async {
        isLoading = true
        routines = (try? await repo.listRoutines()) ?? []
        isLoading = false
    }

    private func delete(_ routine: RoutineSummary) {
        Task {
            try? await repo.deleteRoutine(id: routine.id)
            await load()
        }
    }
}
