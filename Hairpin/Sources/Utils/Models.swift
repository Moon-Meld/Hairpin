import Foundation

// MARK: - Trigger Mode

/// How the user triggers expand/collapse.
enum TriggerMode: Int, CaseIterable, Identifiable {
    case clickOnly = 0
    case hoverAndClick = 1

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .clickOnly:    return "Click Only"
        case .hoverAndClick: return "Hover & Click"
        }
    }
}

// MARK: - Auto-Collapse Delay

/// Predefined auto-collapse delay options (in seconds).
enum AutoCollapseDelay: Double, CaseIterable, Identifiable {
    case immediate = 0
    case threeSeconds = 3
    case fiveSeconds = 5
    case tenSeconds = 10
    case never = -1

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .immediate:     return "Immediately"
        case .threeSeconds:  return "3 seconds"
        case .fiveSeconds:   return "5 seconds"
        case .tenSeconds:    return "10 seconds"
        case .never:         return "Never"
        }
    }
}

// MARK: - Separator Style

/// Visual style for the separator status item.
enum SeparatorStyle: Int, CaseIterable, Identifiable {
    case invisible = 0
    case verticalLine = 1
    case dot = 2
    case arrowLeft = 3
    case arrowRight = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .invisible:    return "Invisible"
        case .verticalLine: return "Vertical Line  |"
        case .dot:          return "Dot  •"
        case .arrowLeft:    return "Arrow  ‹"
        case .arrowRight:   return "Arrow  ›"
        }
    }

    /// The string to display on the separator button when expanded.
    var expandedSymbol: String {
        switch self {
        case .invisible:    return ""
        case .verticalLine: return "|"
        case .dot:          return "•"
        case .arrowLeft:    return "‹"
        case .arrowRight:   return "›"
        }
    }
}

// MARK: - Collapse State

/// The current state of the menu bar folding engine.
enum CollapseState {
    case collapsed
    case expanded
}
