import Foundation
import SwiftData

@Model
final class SensorDevice {
    var id: String
    var name: String
    var batteryLevel: Double
    var serialNumber: String
    var firmwareVersion: String
    var activationDate: Date?
    var expirationDate: Date?
    var lastConnectionDate: Date?
    var status: SensorStatus
    var isCurrent: Bool
    
    init(
        id: String = UUID().uuidString,
        name: String = "GlucoSense Sensor",
        batteryLevel: Double = 1.0,
        serialNumber: String = UUID().uuidString,
        firmwareVersion: String = "1.0.0",
        activationDate: Date? = nil,
        expirationDate: Date? = nil,
        lastConnectionDate: Date? = nil,
        status: SensorStatus = .inactive,
        isCurrent: Bool = false
    ) {
        self.id = id
        self.name = name
        self.batteryLevel = batteryLevel
        self.serialNumber = serialNumber
        self.firmwareVersion = firmwareVersion
        self.activationDate = activationDate
        self.expirationDate = expirationDate
        self.lastConnectionDate = lastConnectionDate
        self.status = status
        self.isCurrent = isCurrent
    }
    
    enum SensorStatus: String, Codable {
        case inactive
        case active
        case expired
        case error
        case unknown
    }
} 
