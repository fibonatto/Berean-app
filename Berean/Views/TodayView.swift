//
//  TodayView.swift
//  Berean
//
//  Created by Sergio Bonatto on 14/11/26.
//

import SwiftData
import SwiftUI

struct TodayView: View {
    private struct RecentItem: Identifiable {
        let position: Position
        let title: String

        var id: Position { position }
    }

    @Environment(BibleStore.self) private var store
    @Environment(PlanStore.self) private var plans
    @Environment(\.modelContext) private var context
    @Query(sort: \PlanEnrollment.startedAt, order: .reverse) private var enrollments: [PlanEnrollment]

    let bible: Bible
    let onOpen: (Reference) -> Void

    private let cardShape = RoundedRectangle(cornerRadius: 12)

    private var activePlan: (plan: ReadingPlan, enrollment: PlanEnrollment, day: Int)? {
        for enrollment in enrollments {
            guard let plan = plans.plan(id: enrollment.planID),
                  let day = enrollment.nextDay(total: plan.days.count)
            else { continue }
            return (plan, enrollment, day)
        }
        return nil
    }

    private var recentItems: [RecentItem] {
        store.recents.dropFirst().prefix(8).compactMap { position in
            guard let book = bible.book(key: position.bookKey),
                  book.chapter(position.chapter) != nil
            else { return nil }
            return RecentItem(position: position, title: "\(book.name) \(position.chapter)")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .environment(\.locale, Locale(identifier: "en_US"))
                    .font(Theme.serif(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
                verseCard
                continueCard
                planCard
                recentSection
                browseCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.paper)
        .task { await plans.load() }
    }

    @ViewBuilder
    private var verseCard: some View {
        if let verse = DailyVerseResolver.resolve(on: .now, store: store, bible: bible) {
            card {
                VStack(alignment: .leading, spacing: 12) {
                    label("Verse of the day")
                    Button { onOpen(verse.reference) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(verse.text)
                                .font(Theme.serif(.title3))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                            Text("\(verse.title) · \(store.translation.title)")
                                .font(Theme.serif(.subheadline, weight: .semibold))
                                .foregroundStyle(Theme.verseNumber)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    HStack {
                        Spacer()
                        ShareLink(item: "“\(verse.text)”\n— \(verse.title) (\(store.translation.title))") {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var continueCard: some View {
        if let last = store.lastPosition,
           let book = bible.book(key: last.bookKey),
           book.chapter(last.chapter) != nil {
            Button {
                onOpen(Reference(bookKey: last.bookKey, chapter: last.chapter, verse: nil, endVerse: nil))
            } label: {
                card {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            label("Continue reading")
                            Text("\(book.name) \(last.chapter)")
                                .font(Theme.serif(.title2))
                                .foregroundStyle(Theme.ink)
                            Text(store.translation.title)
                                .font(Theme.serif(.footnote))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var planCard: some View {
        if let active = activePlan {
            card {
                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink(value: PlanRoute(id: active.plan.id)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                label("Reading plan · day \(active.day) of \(active.plan.days.count)")
                                Text(active.plan.title)
                                    .font(Theme.serif(.headline))
                                    .foregroundStyle(Theme.ink)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    ForEach(active.plan.days[active.day - 1], id: \.self) { entry in
                        readingRow(entry)
                    }
                    Button { complete(day: active.day, in: active.enrollment) } label: {
                        Label("Mark day complete", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        } else if plans.isLoaded {
            NavigationLink(value: PlansRoute()) {
                card {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            label("Reading plans")
                            Text("Choose a plan to read through the Bible")
                                .font(Theme.serif(.body))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        let items = recentItems
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                label("Recent")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items) { item in
                            Button {
                                onOpen(Reference(
                                    bookKey: item.position.bookKey,
                                    chapter: item.position.chapter,
                                    verse: nil,
                                    endVerse: nil
                                ))
                            } label: {
                                Text(item.title)
                                    .font(Theme.serif(.subheadline))
                                    .foregroundStyle(Theme.ink)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Theme.paperAlt, in: Capsule())
                                    .overlay { Capsule().stroke(Theme.border, lineWidth: 1) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var browseCard: some View {
        card {
            VStack(spacing: 0) {
                browseRow("Bible", detail: "Old and New Testament", symbol: "book", value: BooksRoute())
                Divider().overlay(Theme.border)
                browseRow(
                    "Library",
                    detail: "Creeds, confessions, catechisms and more",
                    symbol: "books.vertical",
                    value: LibraryRoute()
                )
                Divider().overlay(Theme.border)
                browseRow(
                    "Marks",
                    detail: "Favorites, highlights and notes",
                    symbol: "bookmark",
                    value: MarksRoute()
                )
            }
        }
    }

    private func browseRow<Value: Hashable>(
        _ title: String,
        detail: String,
        symbol: String,
        value: Value
    ) -> some View {
        NavigationLink(value: value) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .frame(width: 24)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.serif(.body))
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(Theme.serif(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func readingRow(_ entry: String) -> some View {
        let reference = store.references(matching: entry).first
        let title = reference.map { $0.title(in: bible) } ?? entry
        return Button {
            if let reference { onOpen(reference) }
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

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paperAlt, in: cardShape)
            .overlay { cardShape.stroke(Theme.border, lineWidth: 1) }
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.serif(.caption, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(Theme.inkSoft)
    }

    private func complete(day: Int, in enrollment: PlanEnrollment) {
        var done = Set(enrollment.completedDays)
        done.insert(day)
        enrollment.completedDays = done.sorted()
        try? context.save()
    }
}
