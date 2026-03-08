import Foundation
import CoreGraphics
import SwiftUI

enum UIConstants {
    enum General {
        static let defaultSpacing: CGFloat = 8
        static let smallSpacing: CGFloat = 4
        static let mediumSpacing: CGFloat = 12
        static let largeSpacing: CGFloat = 16
        static let xlSpacing: CGFloat = 20
        static let cornerRadius: CGFloat = 4
    }
    
    enum Window {
        static let minWidth: CGFloat = 800
        static let minHeight: CGFloat = 600
    }
    
    enum Sidebar {
        static let minWidth: CGFloat = 250
        static let idealWidth: CGFloat = 300
        static let maxWidth: CGFloat = 600
    }

    enum TopBar {
        static let dividerHeight: CGFloat = 18
        static let addressBarMinWidth: CGFloat = 200
        static let horizontalPadding: CGFloat = 10
        static let verticalPadding: CGFloat = 6
    }
    
    enum IconButton {
        static let frameSize: CGFloat = 20
        static let font: Font = .title3
        static let foregroundColor: Color = .secondary
    }
    
    enum PieChart {
        static let innerRadiusRatio: CGFloat = 0.5
        static let angularInset: CGFloat = 1.5
        static let smallSliceThreshold: Double = 20 // threshold = totalChartSize / 20
    }

    enum Tree {
        static let iconTextSpacing: CGFloat = 6
        static let progressBarHeight: CGFloat = 6
        static let progressBarWidth: CGFloat = 40
        static let rowVerticalPadding: CGFloat = 2
        static let rowVerticalPaddingVolume: CGFloat = 4
        static let cornerRadius: CGFloat = 3
    }
    
    enum StatusBar {
        static let height: CGFloat = 24
        static let progressStripHeight: CGFloat = 2
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 4
        static let spinnerScale: CGFloat = 0.75
    }
}
