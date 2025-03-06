import SwiftUI
import SwiftData

#if os(watchOS)
import WatchKit
import UserNotifications
#endif


struct GlucoseMonitorWatchApp: App {
    @State private var dataManager = DataManager.shared
    @State private var sensorManager = SensorManager.shared
    
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(sensorManager)
                .modelContainer(dataManager.container)
        }
        
        #if os(watchOS)
        // Only include notification scene when building for watchOS
        WKNotificationScene(controller: NotificationController.self, category: "glucoseAlert")
        #endif
    }
}

#if os(watchOS)
// Define NotificationController if it's not already defined elsewhere
// This assumes NotificationView is defined somewhere in your project
class NotificationController: WKUserNotificationHostingController<NotificationView> {
    override var body: NotificationView {
        return NotificationView()
    }
    
    override func didReceive(_ notification: UNNotification) {
        // You can process the notification content here
        // For example:
        // let glucoseValue = notification.request.content.userInfo["glucoseValue"] as? Double ?? 0
    }
}
#endif 
