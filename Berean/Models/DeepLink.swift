//
//  DeepLink.swift
//  Berean
//
//  Created by Sergio Bonatto on 12/11/26.
//

import Foundation

enum DeepLink {
    static func url(for reference: Reference) -> URL {
        var components = URLComponents()
        components.scheme = "berean"
        components.host = reference.verse == nil ? "read" : "verse"
        var items = [URLQueryItem(name: "book", value: reference.bookKey)]
        if let chapter = reference.chapter {
            items.append(URLQueryItem(name: "chapter", value: String(chapter)))
        }
        if let verse = reference.verse {
            items.append(URLQueryItem(name: "verse", value: String(verse)))
        }
        if let end = reference.endVerse {
            items.append(URLQueryItem(name: "end", value: String(end)))
        }
        components.queryItems = items
        return components.url ?? URL(string: "berean://")!
    }

    static func reference(from url: URL) -> Reference? {
        guard url.scheme == "berean",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let book = items.first(where: { $0.name == "book" })?.value
        else { return nil }

        func number(_ name: String) -> Int? {
            items.first { $0.name == name }?.value.flatMap(Int.init)
        }

        return Reference(
            bookKey: book,
            chapter: number("chapter"),
            verse: number("verse"),
            endVerse: number("end")
        )
    }
}
