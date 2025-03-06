import Foundation
import SwiftData

// Consolidated ReadingMetadata class
@Model
final class ReadingMetadata {
    // Relationship field
    var reading: GlucoseReading?
    
    // Meal properties (combining both versions)
    enum MealProximity: String, Codable {
        case preMeal = "pre_meal"
        case postMeal = "post_meal"
        case fasting = "fasting"
    }
    
    // Properties (combining from both versions)
    var meal: MealProximity?
    var note: String?
    var userActivity: String?
    var hasExercise: Bool = false
    
    // Combined initializer
    init(reading: GlucoseReading? = nil, 
         note: String? = nil, 
         meal: MealProximity? = nil, 
         userActivity: String? = nil,
         hasExercise: Bool = false) {
        self.reading = reading
        self.note = note
        self.meal = meal
        self.userActivity = userActivity
        self.hasExercise = hasExercise
    }
} 