import Foundation
//import CoreML
import SwiftUI
import Observation

@Observable
class GlucosePredictionService {
    static let shared = GlucosePredictionService()
    
    private init() {
        // Simplified initialization
    }
    
    func predictGlucoseValues(from currentValue: Double, recentReadings: [GlucoseReading], minutesAhead: Int = 30) -> [GlucoseDataPoint] {
        var predictions: [GlucoseDataPoint] = []
        let now = Date()
        
        // For each 5-minute interval
        for minute in stride(from: 5, to: minutesAhead + 1, by: 5) {
            let predictedTime = now.addingTimeInterval(Double(minute) * 60)
            
            // Calculate trend from recent readings
            let ratePerMinute = calculateTrend(from: recentReadings)
            
            // Apply time-of-day effects
            let hour = Calendar.current.component(.hour, from: predictedTime)
            let timeOfDayFactor = calculateTimeOfDayFactor(hour: hour)
            
            // Calculate prediction
            let predictedValue = currentValue + (ratePerMinute * Double(minute)) + timeOfDayFactor
            
            // Add to predictions
            predictions.append(GlucoseDataPoint(timestamp: predictedTime, value: predictedValue))
        }
        
        return predictions
    }
    
    private func calculateTrend(from readings: [GlucoseReading]) -> Double {
        // More sophisticated trend calculation
        guard readings.count >= 4 else { return 0 }
        
        let recentReadings = Array(readings.prefix(4))
        let values = recentReadings.map { $0.valueMgdl }
        let timestamps = recentReadings.map { $0.timestamp.timeIntervalSince1970 }
        
        // Simple linear regression to find trend
        let n = Double(values.count)
        let sumX = timestamps.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(timestamps, values).map { $0 * $1 }.reduce(0, +)
        let sumXX = timestamps.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        
        // Convert slope to mg/dL per minute
        return slope * 60
    }
    
    private func calculateTimeOfDayFactor(hour: Int) -> Double {
        // Dawn phenomenon (early morning rise)
        if hour >= 4 && hour <= 8 {
            return Double(hour - 4) * 2
        }
        
        // Post-meal peaks (lunch and dinner)
        if hour == 12 || hour == 13 || hour == 18 || hour == 19 {
            return 5.0
        }
        
        // Nighttime stability/drop
        if hour >= 22 || hour <= 3 {
            return -3.0
        }
        
        return 0.0
    }
} 
