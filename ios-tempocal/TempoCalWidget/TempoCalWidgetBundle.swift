//
//  TempoCalWidgetBundle.swift
//  TempoCalWidget
//

import WidgetKit
import SwiftUI

@main
struct TempoCalWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        UpcomingWidget()
    }
}
