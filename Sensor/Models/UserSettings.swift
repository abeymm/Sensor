import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    var glucoseUnit: GlucoseUnit
    var lowThreshold: Double
    var highThreshold: Double
    var urgentLowThreshold: Double
    var urgentHighThreshold: Double
    var notificationsEnabled: Bool
    var healthKitSyncEnabled: Bool
    var predictionsEnabled: Bool
    
    init(
        id: UUID = UUID(),
        glucoseUnit: GlucoseUnit = .mgdl,
        lowThreshold: Double = 70,
        highThreshold: Double = 180,
        urgentLowThreshold: Double = 55,
        urgentHighThreshold: Double = 250,
        notificationsEnabled: Bool = true,
        healthKitSyncEnabled: Bool = true,
        predictionsEnabled: Bool = true
    ) {
        self.id = id
        self.glucoseUnit = glucoseUnit
        self.lowThreshold = lowThreshold
        self.highThreshold = highThreshold
        self.urgentLowThreshold = urgentLowThreshold
        self.urgentHighThreshold = urgentHighThreshold
        self.notificationsEnabled = notificationsEnabled
        self.healthKitSyncEnabled = healthKitSyncEnabled
        self.predictionsEnabled = predictionsEnabled
    }
    
    enum GlucoseUnit: String, Codable {
        case mgdl
        case mmol
    }
} 