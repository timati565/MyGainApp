import SwiftUI

struct StoryProgressBar: View {
    let count: Int
    let currentIndex: Int
    let progress: CGFloat  // 0...1 для текущей истории
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.4))
                        if index < currentIndex {
                            Capsule().fill(Color.white)
                        } else if index == currentIndex {
                            Capsule()
                                .fill(Color.white)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                }
                .frame(height: 2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
}
