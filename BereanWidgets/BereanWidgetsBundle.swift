//
//  BereanWidgetsBundle.swift
//  Berean
//
//  Created by Sergio Bonatto on 12/11/26.
//

import SwiftUI
import WidgetKit

@main
struct BereanWidgetsBundle: WidgetBundle {
    var body: some Widget {
        VerseOfTheDayWidget()
        ContinueReadingWidget()
    }
}
