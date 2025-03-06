import ActivityKit
import SwiftUI
import WidgetKit

struct GlucoseActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentValue: Double
        var trend: String
        var timestamp: Date
        var isHigh: Bool
        var isLow: Bool
    }
}

struct GlucoseLiveActivityView: View {
    let context: ActivityViewContext<GlucoseActivityAttributes>
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(glucoseBackgroundColor)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Glucose")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(context.state.currentValue))")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        
                        Text("mg/dL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: trendImageName)
                        Text(context.state.trend)
                            .font(.caption2)
                    }
                }
                
                Spacer()
                
                VStack {
                    Text(timeAgo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    CircularGaugeView(value: context.state.currentValue, isHigh: context.state.isHigh, isLow: context.state.isLow)
                        .frame(width: 60, height: 60)
                }
            }
            .padding()
        }
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: context.state.timestamp, relativeTo: Date())
    }
    
    private var trendImageName: String {
        switch context.state.trend {
        case "rising_quickly":
            return "arrow.up.right.circle.fill"
        case "rising":
            return "arrow.up.right"
        case "stable":
            return "arrow.forward"
        case "falling":
            return "arrow.down.right"
        case "falling_quickly":
            return "arrow.down.right.circle.fill"
        default:
            return "arrow.forward"
        }
    }
    
    private var glucoseBackgroundColor: some ShapeStyle {
        if context.state.isLow {
            return Color.red.opacity(0.8).gradient
        } else if context.state.isHigh {
            return Color.orange.opacity(0.8).gradient
        } else {
            return Color.green.opacity(0.8).gradient
        }
    }
}

struct CircularGaugeView: View {
    let value: Double
    let isHigh: Bool
    let isLow: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 6)
            
            Circle()
                .trim(from: 0, to: min(CGFloat(value) / 300, 1.0))
                .stroke(gaugeColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(value))")
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
        }
    }
    
    private var gaugeColor: Color {
        if isLow {
            return .red
        } else if isHigh {
            return .orange
        } else {
            return .green
        }
    }
}

// Live Activity registration extension
extension GlucoseActivityAttributes {
    fileprivate static var preview: GlucoseActivityAttributes {
        GlucoseActivityAttributes()
    }
}

extension GlucoseActivityAttributes.ContentState {
    fileprivate static var preview: GlucoseActivityAttributes.ContentState {
        GlucoseActivityAttributes.ContentState(
            currentValue: 120,
            trend: "stable",
            timestamp: Date(),
            isHigh: false,
            isLow: false
        )
    }
    
    fileprivate static var highPreview: GlucoseActivityAttributes.ContentState {
        GlucoseActivityAttributes.ContentState(
            currentValue: 220,
            trend: "rising",
            timestamp: Date(),
            isHigh: true,
            isLow: false
        )
    }
    
    fileprivate static var lowPreview: GlucoseActivityAttributes.ContentState {
        GlucoseActivityAttributes.ContentState(
            currentValue: 65,
            trend: "falling",
            timestamp: Date(),
            isHigh: false,
            isLow: true
        )
    }
}

@available(iOS 16.2, *)
struct GlucoseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlucoseActivityAttributes.self) { context in
            GlucoseLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text("\(Int(context.state.currentValue))")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(context.state.isHigh || context.state.isLow ? .white : .primary)
                    } icon: {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(context.state.isLow ? .red : (context.state.isHigh ? .orange : .green))
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text(context.state.trend)
                            .font(.caption)
                    } icon: {
                        Image(systemName: trendImageFor(trend: context.state.trend))
                    }
                    .font(.caption)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text("mg/dL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label {
                            Text(RelativeDateTimeFormatter().localizedString(for: context.state.timestamp, relativeTo: Date()))
                        } icon: {
                            Image(systemName: "clock")
                        }
                        .font(.caption)
                        
                        Spacer()
                        
                        if context.state.isLow {
                            Label("Low", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else if context.state.isHigh {
                            Label("High", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(context.state.isLow ? .red : (context.state.isHigh ? .orange : .green))
            } compactTrailing: {
                Text("\(Int(context.state.currentValue))")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
            } minimal: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(context.state.isLow ? .red : (context.state.isHigh ? .orange : .green))
            }
        }
    }
    
    private func trendImageFor(trend: String) -> String {
        switch trend {
        case "rising_quickly":
            return "arrow.up.right.circle.fill"
        case "rising":
            return "arrow.up.right"
        case "stable":
            return "arrow.forward"
        case "falling":
            return "arrow.down.right"
        case "falling_quickly":
            return "arrow.down.right.circle.fill"
        default:
            return "arrow.forward"
        }
    }
}

// For older Xcode/SwiftUI versions
struct GlucoseLiveActivity_Previews: PreviewProvider {
    static var previews: some View {
        // We can't directly construct ActivityViewContext, so we'll use a placeholder
        VStack {
            Text("Live Activity Preview")
                .font(.headline)
            Text("120 mg/dL")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.green)
            Text("Preview Only - Run in simulator to see actual Live Activity")
                .font(.caption)
        }
        .padding()
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
