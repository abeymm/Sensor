//
//  SensorApp.swift
//  Sensor
//
//  Created by Abey Mullassery on 3/5/25.
//

import SwiftUI
import SwiftData

// Add conditional compilation to avoid @main conflicts with the WatchOS app
#if os(iOS)
@main
struct SensorApp: App {
    @State private var dataManager = DataManager.shared
    @State private var sensorManager = SensorManager.shared
    @State private var accessibilityManager = AccessibilityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sensorManager)
                .environment(accessibilityManager)
                .modelContainer(dataManager.container)
        }
        
#if os(watchOS)
        WKNotificationScene(controller: NotificationController.self, category: "glucoseAlert")
#endif
    }
}
#endif
    
//    var sharedModelContainer: ModelContainer = {
//        let schema = Schema([
//            Item.self,
//        ])
//        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
//
//        do {
//            return try ModelContainer(for: schema, configurations: [modelConfiguration])
//        } catch {
//            fatalError("Could not create ModelContainer: \(error)")
//        }
//    }()
//
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//        .modelContainer(sharedModelContainer)
//    }
//}
