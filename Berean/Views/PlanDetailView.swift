//
//  PlanDetailView.swift
//  Berean
//
//  Created by Sergio Bonatto on 13/11/26.
//

import SwiftData
import SwiftUI

struct PlanDetailView: View {
    private enum Confirmation: String, Identifiable {
        case restart, stop

        var id: String { rawValue }
        var title: String { self == .restart ? "Restart this plan?" : "Stop this plan?" }
        var action: String { self == .restart ? "Restart plan" : "Stop plan" }
    }

    @Environment(BibleStore.self) private var store
    @Environment(PlanStore.self) private var plans
    @Environment(\.modelContext) private var context
    @Query private var enrollments: [PlanEnrollment]
    @State private var selectedDay: Int?
    @State private var confirmation: Confirmation?

    let planID: String
    let onOpenReference: (Reference) -> Void

    private var plan: ReadingPlan? { plans.plan(id: planID) }
    private var enrollment: PlanEnrollment? { enrollments.first { $0.planID == planID } }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if let plan {
                    if let enrollment {
                        let shown = selectedDay
                            ?? enrollment.nextDay(total: plan.days.count)
                            ?? plan.days.count
                        Section {
                            dayCard(plan, enrollment, day: shown).id("card")
                        }
                        Section {
                            ForEach(plan.days.indices, id: \.self) { index in
                                dayRow(
                                    index + 1,
                                    plan: plan,
                                    enrollment: enrollment,
                                    isShown: index + 1 == shown
                                ) {
                                    selectedDay = index + 1
                                    withAnimation { proxy.scrollTo("card", anchor: .top) }
                                }
                            }
                        } header: {
                            Text("ALL DAYS")
                                .font(Theme.serif(.caption, weight: .semibold))
                                .tracking(1.5)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    } else {
                        Section { startCard(plan) }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
        }
        .navigationTitle(plan?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if enrollment != nil {
                    Menu {
                        Button { confirmation = .restart } label: {
                            Label("Restart plan", systemImage: "arrow.counterclockwise")
                        }
                        Button(role: .destructive) { confirmation = .stop } label: {
                            Label("Stop plan", systemImage: "xmark.circle")
                        }
                    } label: {
                        Label("Plan options", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(
            confirmation?.title ?? "",
            isPresented: Binding(
                get: { confirmation != nil },
                set: { if !$0 { confirmation = nil } }
            ),
            titleVisibility: .visible,
            presenting: confirmation
        ) { item in
            Button(item.action, role: .destructive) { perform(item) }
        }
        .task { await plans.load() }
    }

    private func startCard(_ plan: ReadingPlan) -> some View {
        let chapters = plan.days.reduce(0) { $0 + $1.count }
        return VStack(alignment: .leading, spacing: 12) {
            if let subtitle = plan.subtitle {
                Text(subtitle).font(Theme.serif(.body))
            }
            Text("\(plan.days.count) days · \(chapters) chapters")
                .font(Theme.serif(.footnote))
                .foregroundStyle(Theme.inkSoft)
            Button("Start plan") { start(plan) }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 6)
        .listRowBackground(Theme.paperAlt)
    }

    private func dayCard(_ plan: ReadingPlan, _ enrollment: PlanEnrollment, day: Int) -> some View {
        let isDone = enrollment.completedDays.contains(day)
        let note = scheduleNote(plan, enrollment, day: day)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("DAY \(day) OF \(plan.days.count)")
                    .font(Theme.serif(.caption, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                if let note {
                    Text(note)
                        .font(Theme.serif(.caption))
                        .foregroundStyle(Theme.star)
                }
            }
            ProgressView(
                value: Double(enrollment.completedDays.count),
                total: Double(plan.days.count)
            )
            .tint(Theme.accent)
            ForEach(plan.days[day - 1], id: \.self) { entry in
                readingRow(entry)
            }
            Button { toggle(day, in: enrollment) } label: {
                Label(
                    isDone ? "Completed — undo" : "Mark day complete",
                    systemImage: isDone ? "checkmark.circle.fill" : "circle"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
        .listRowBackground(Theme.paperAlt)
    }

    private func readingRow(_ entry: String) -> some View {
        let reference = store.references(matching: entry).first
        let title = reference.flatMap { found in store.bible.map { found.title(in: $0) } } ?? entry
        return Button {
            if let reference { onOpenReference(reference) }
        } label: {
            HStack {
                Text(title)
                    .font(Theme.serif(.body))
                    .foregroundStyle(reference == nil ? Theme.inkSoft : Theme.ink)
                Spacer()
                if reference != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(reference == nil)
    }

    private func dayRow(
        _ day: Int,
        plan: ReadingPlan,
        enrollment: PlanEnrollment,
        isShown: Bool,
        onSelect: @escaping () -> Void
    ) -> some View {
        let isDone = enrollment.completedDays.contains(day)
        let summary = store.bible.map { plan.summary(ofDay: day, in: $0) } ?? ""
        return Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isDone ? Theme.accent : Theme.inkSoft)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(day)")
                        .font(Theme.serif(.body))
                        .foregroundStyle(Theme.ink)
                    Text(summary)
                        .font(Theme.serif(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(2)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isShown ? Theme.paperAlt : Theme.paper)
        .listRowSeparatorTint(Theme.border)
    }

    private func scheduleNote(_ plan: ReadingPlan, _ enrollment: PlanEnrollment, day: Int) -> String? {
        guard day == enrollment.nextDay(total: plan.days.count) else { return nil }
        let behind = enrollment.scheduledDay(total: plan.days.count) - day
        guard behind > 0 else { return nil }
        return behind == 1 ? "1 day behind" : "\(behind) days behind"
    }

    private func start(_ plan: ReadingPlan) {
        context.insert(PlanEnrollment(planID: plan.id))
        try? context.save()
    }

    private func toggle(_ day: Int, in enrollment: PlanEnrollment) {
        var done = Set(enrollment.completedDays)
        if done.contains(day) {
            done.remove(day)
        } else {
            done.insert(day)
        }
        enrollment.completedDays = done.sorted()
        selectedDay = nil
        try? context.save()
    }

    private func perform(_ item: Confirmation) {
        guard let enrollment else { return }
        switch item {
        case .restart:
            enrollment.completedDays = []
            enrollment.startedAt = .now
            selectedDay = nil
        case .stop:
            context.delete(enrollment)
        }
        try? context.save()
    }
}
