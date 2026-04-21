import SwiftUI

struct CircularProgressView: View {
    let progress: Double // 0...1
    let lineWidth: CGFloat
    let color: Color
    let showText: Bool
    let text: String?
    
    init(progress: Double, lineWidth: CGFloat = 12, color: Color = .accentColor) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.color = color
        self.showText = false
        self.text = nil
    }
    
    init(progress: Double, text: String, lineWidth: CGFloat = 12, color: Color = .accentColor) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.color = color
        self.showText = true
        self.text = text
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            if showText, let text = text {
                Text(text)
                    .font(.title3.bold())
                    .foregroundColor(.primary)
            }
        }
    }
}
