import Foundation
import SwiftUI

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var highContrast: Bool = false {
        didSet {
            UserDefaults.standard.set(highContrast, forKey: "highContrast")
        }
    }
    
    private init() {
        highContrast = UserDefaults.standard.bool(forKey: "highContrast")
    }
}

