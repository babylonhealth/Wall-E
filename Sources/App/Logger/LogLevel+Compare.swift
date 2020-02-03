import Logging

extension LogLevel: Equatable {
    public static func == (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.description == rhs.description
    }

    /// From more verbose to less verbose (i.e. from less important to more important)
    private static let allLevels: [LogLevel] = [
        .verbose, .debug, .info, .warning, .error, .fatal
    ]

    // Note: Didn't implement it as Comparable and `<` operator because `.custom` case doesn't follow semantics.
    public func isAtLeast(minimumLevel: LogLevel) -> Bool {
        // If minimumLevel is .custom, only keep the ones that are exactly using the same custom level name
        if case .custom(let minValue) = minimumLevel, case .custom(let selfValue) = self {
            return selfValue == minValue
        }
        // Otherwise, consider custom levels have the same "importance" as .info
        let defaultIndex = LogLevel.allLevels.firstIndex(of: .info)!
        let minIndex = LogLevel.allLevels.firstIndex(of: minimumLevel) ?? defaultIndex
        let selfIndex = LogLevel.allLevels.firstIndex(of: self) ?? defaultIndex
        return selfIndex >= minIndex
    }
}

extension LogLevel {
    init(string: String) {
        self = LogLevel.allLevels.first {
            $0.description.caseInsensitiveCompare(string) == .orderedSame
        } ?? .custom(string)
    }
}
