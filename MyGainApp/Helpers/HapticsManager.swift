import SwiftUI
import AVFoundation

enum HapticStyle {
    case light, medium, heavy, success, warning, error
}

class HapticsManager {
    static let shared = HapticsManager()
    private var audioPlayer: AVAudioPlayer?
    
    private init() {}
    
    func play(_ style: HapticStyle, withSound: Bool = true) {
        guard UserDefaults.standard.bool(forKey: "hapticsEnabled") else { return }
        
        #if os(iOS)
        switch style {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        #endif
        
        if withSound && UserDefaults.standard.bool(forKey: "soundsEnabled") {
            playSound(for: style)
        }
    }
    
    private func playSound(for style: HapticStyle) {
        var soundName: String?
        switch style {
        case .success: soundName = "success"
        case .warning: soundName = "warning"
        case .error: soundName = "error"
        default: soundName = "click"
        }
        
        guard let name = soundName,
              let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Не удалось воспроизвести звук: \(error)")
        }
    }
}

// Удобные обёртки
func haptic(_ style: HapticStyle, sound: Bool = true) {
    HapticsManager.shared.play(style, withSound: sound)
}
