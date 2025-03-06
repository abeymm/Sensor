import SwiftUI

struct ShapeShiftCircleToSquare: View {
    @State private var isCircle = true
    
    var body: some View {
        VStack {
            // In iOS 18, we would use the new ShapeShifter API
            // For now, we can simulate with shape morphing
            Rectangle()
                .fill(.blue.gradient)
                .frame(width: 100, height: 100)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: isCircle ? 50 : 10,
                        style: .continuous
                    )
                )
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isCircle)
                .onTapGesture {
                    isCircle.toggle()
                }
            
            Text("Tap to animate")
                .font(.caption)
                .padding(.top)
        }
    }
}

struct GlucoseValueTransition: ViewModifier {
    let value: Double
    let threshold: Double
    let urgentThreshold: Double
    @State private var previousColor: Color = .green
    @State private var currentColor: Color = .green
    
    func body(content: Content) -> some View {
        content
            .foregroundStyle(currentColor)
            .onChange(of: value) { oldValue, newValue in
                withAnimation(.easeInOut(duration: 0.5)) {
                    previousColor = currentColor
                    currentColor = calculateColor(for: newValue)
                }
            }
            .onAppear {
                currentColor = calculateColor(for: value)
            }
    }
    
    private func calculateColor(for value: Double) -> Color {
        if value < urgentThreshold {
            return .red
        } else if value < threshold {
            return .orange
        } else if value > urgentThreshold * 2 {
            return .red
        } else if value > threshold {
            return .orange
        } else {
            return .green
        }
    }
}

extension View {
    func glucoseValueTransition(value: Double, threshold: Double, urgentThreshold: Double) -> some View {
        modifier(GlucoseValueTransition(value: value, threshold: threshold, urgentThreshold: urgentThreshold))
    }
} 