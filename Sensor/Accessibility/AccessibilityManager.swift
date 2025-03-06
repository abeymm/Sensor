import SwiftUI
import Observation

@Observable
class AccessibilityManager {
    static let shared = AccessibilityManager()
    
    var largerTextEnabled = false
    var highContrastEnabled = false
    var reduceMotionEnabled = false
    var voiceOverRunning = false
    
    private init() {
        // In a real app, we would detect system settings
        updateAccessibilitySettings()
        
        // Set up notification observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func accessibilitySettingsChanged() {
        updateAccessibilitySettings()
    }
    
    private func updateAccessibilitySettings() {
        voiceOverRunning = UIAccessibility.isVoiceOverRunning
        reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        highContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
    }
}

// Example extension to make glucose readings more accessible
extension GlucoseReading {
    var accessibilityDescription: String {
        let glucoseDescription: String
        if valueMgdl < 70 {
            glucoseDescription = "Low glucose reading of \(Int(valueMgdl)) milligrams per deciliter"
        } else if valueMgdl > 180 {
            glucoseDescription = "High glucose reading of \(Int(valueMgdl)) milligrams per deciliter"
        } else {
            glucoseDescription = "Glucose reading of \(Int(valueMgdl)) milligrams per deciliter"
        }
        
        let timeDescription = RelativeDateTimeFormatter().localizedString(for: timestamp, relativeTo: Date())
        
        return "\(glucoseDescription), recorded \(timeDescription)"
    }
}

// Example of an accessible view modifier
struct AccessibleGlucoseReading: ViewModifier {
    let reading: GlucoseReading
    let trendDescription: String
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Glucose Reading")
            .accessibilityValue(reading.accessibilityDescription)
            .accessibilityHint("Double tap to view details")
            .accessibilityAction {
                // In a real app, this would navigate to details
            }
    }
} 