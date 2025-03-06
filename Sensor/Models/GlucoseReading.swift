import Foundation
import SwiftData

@Model
class GlucoseReading: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var timestamp: Date = Date()
    var valueMgdl: Double
    var isSimulated: Bool = true
    var sensorId: String
    var readingQuality: ReadingQuality
    var metadata: ReadingMetadata?
    
    var valueInMmol: Double {
        return valueMgdl / 18.0
    }
    
    enum ReadingQuality: String, Codable {
        case good
        case uncertain
        case invalid
    }
    
    init(timestamp: Date = .now,
         valueMgdl: Double,
         isSimulated: Bool = true,
         sensorId: String,
         readingQuality: ReadingQuality = .good) {
        self.timestamp = timestamp
        self.valueMgdl = valueMgdl
        self.isSimulated = isSimulated
        self.sensorId = sensorId
        self.readingQuality = readingQuality
    }
    
    // Any other methods for the GlucoseReading class
}

// Remove the duplicate ReadingMetadata class here 
