/// Limits the split to the space in which the slide can actually grow.
public enum PresenterLayout {
    public static let defaultRange = 0.24...0.72

    public static func chromeHeight(hasNext: Bool) -> Double { hasNext ? 152 : 94 }

    public static func shareRange(width: Double, height: Double, aspectRatio: Double, hasNext: Bool) -> ClosedRange<Double> {
        guard width.isFinite, height.isFinite, aspectRatio.isFinite,
              width > 32, height > 24, aspectRatio > 0 else { return defaultRange }
        let chrome = chromeHeight(hasNext: hasNext)
        if width >= 700 {
            let available = width - 52
            let lower = max(defaultRange.lowerBound, 260 / available)
            let notesLimit = min(defaultRange.upperBound, (available - 220) / available)
            let usefulWidth = max(260, max(1, height - chrome) * aspectRatio)
            return lower...max(lower, min(notesLimit, usefulWidth / available))
        }
        let usefulHeight = (width - 32) / aspectRatio + chrome
        let upper = min(defaultRange.upperBound, usefulHeight / (height - 24))
        // Very tall windows or unusually wide slides can reach the sides before 24%.
        let lower = upper > defaultRange.lowerBound ? defaultRange.lowerBound : upper / 2
        return lower...upper
    }

    public static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : range.lowerBound
    }
}
