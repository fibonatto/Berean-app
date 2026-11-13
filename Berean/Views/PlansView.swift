//
//  PlansView.swift
//  Berean
//
//  Created by Sergio Bonatto on 13/11/26.
//

import SwiftData
import SwiftUI

struct PlansView: View {
    @Environment(PlanStore.self) private var plans
    @Query private var enrollments: [PlanEnrollment]

    var body: some View {
        List {
            ForEach(plans.plans) { plan in row(plan) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .overlay {
            if plans.isLoaded, plans.plans.isEmpty {
                ContentUnavailableView(
                    "No plans",
                    systemImage: "calendar",
                    description: Text("Add plan-*.json files to Resources/Plans.")
                )
            }
        }
        .navigationTitle("Reading Plans")
        .navigationBarTitleDisplayMode(.inline)
        .task { await plans.load() }
    }

    private func row(_ plan: ReadingPlan) -> some View {
        let enrollment = enrollments.first { $0.planID == plan.id }
        return NavigationLink(value: PlanRoute(id: plan.id)) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(Theme.serif(.body))
                        .foregroundStyle(Theme.ink)
                    if let subtitle = plan.subtitle {
                        Text(subtitle)
                            .font(Theme.serif(.footnote))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Spacer()
                if let enrollment {
                    Text("\(enrollment.completedDays.count)/\(plan.days.count)")
                        .font(Theme.serif(.caption))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .listRowBackground(Theme.paper)
        .listRowSeparatorTint(Theme.border)
    }
}

struct PlansHomeRow: View {
    @Environment(PlanStore.self) private var plans
    @Environment(BibleStore.self) private var store
    @Query(sort: \PlanEnrollment.startedAt, order: .reverse) private var enrollments: [PlanEnrollment]

    private var active: (plan: ReadingPlan, day: Int)? {
        for enrollment in enrollments {
            guard let plan = plans.plan(id: enrollment.planID),
                  let day = enrollment.nextDay(total: plan.days.count)
            else { continue }
            return (plan, day)
        }
        return nil
    }

    var body: some View {
        Group {
            if let active {
                NavigationLink(value: PlanRoute(id: active.plan.id)) {
                    label(
                        title: active.plan.title,
                        detail: "Day \(active.day) · "
                            + (store.bible.map { active.plan.summary(ofDay: active.day, in: $0) } ?? "")
                    )
                }
            } else {
                NavigationLink(value: PlansRoute()) {
                    label(title: "Reading plans", detail: "Choose a plan to read through the Bible")
                }
            }
        }
        .task { await plans.load() }
    }

    private func label(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.serif(.body))
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(Theme.serif(.footnote))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(2)
        }
    }
}
