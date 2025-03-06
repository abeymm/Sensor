import Foundation
import SwiftData
import OSLog

@Observable
final class DataManager {
    @MainActor
    static let shared = DataManager()
    private let logger = Logger(subsystem: "com.expertcraft.sensor", category: "DataManager")
    
    let container: ModelContainer
    
    @MainActor
    private init() {
        do {
            let schema = Schema([
                GlucoseReading.self,
                ReadingMetadata.self,
                SensorDevice.self,
                UserSettings.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            container.mainContext.autosaveEnabled = true
            Task {
                await createInitialDataIfNeeded()
            }
        } catch {
            logger.error("Failed to create ModelContainer: \(error.localizedDescription)")
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func createInitialDataIfNeeded() async {
        let context = container.mainContext
        
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        
        guard (try? context.fetchCount(settingsDescriptor)) == 0 else { return }
        
        // Create default settings
        let defaultSettings = UserSettings()
        context.insert(defaultSettings)
        
        // Create a mock sensor
        let mockSensor = SensorDevice(
            activationDate: nil,
            expirationDate: nil,
            status: .inactive,
            isCurrent: false
        )
        context.insert(mockSensor)
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to save initial data: \(error.localizedDescription)")
        }
    }
} 
