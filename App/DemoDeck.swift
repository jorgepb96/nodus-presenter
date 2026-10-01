import PresenterCore
import UIKit
import PDFKit

enum DemoDeck {
    static let titles = [L10n.text("Ideas connect us"), L10n.text("A map to guide us"), L10n.text("Knowledge networks"), L10n.text("Communities that transform"), L10n.text("From question to discovery"), L10n.text("Conversations that matter"), L10n.text("Connect to understand"), L10n.text("What we build together")]
    static let notes = Dictionary(uniqueKeysWithValues: titles.enumerated().map { i, _ in
        (String(i + 1), [
            L10n.text("Knowledge networks let us connect people, ideas and opportunities in meaningful ways."),
            L10n.text("In an increasingly connected world, real progress comes from sharing, collaborating and learning together."),
            L10n.text(i == 2 ? "Highlight the connections with Spotlight. The audience sees exactly where the focus is." : "Pause before moving to the next idea and leave room for a question.")
        ].joined(separator: "\n\n"))
    })
    static func make() -> PDFDocument? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 960, height: 540))
        let data = renderer.pdfData { context in
            for (index, title) in titles.enumerated() {
                context.beginPage()
                UIColor.white.setFill(); context.cgContext.fill(CGRect(x: 0, y: 0, width: 960, height: 540))
                let ink = UIColor(red: 0.08, green: 0.07, blue: 0.19, alpha: 1)
                let violet = UIColor(red: 0.50, green: 0.35, blue: 0.95, alpha: 1)
                (L10n.text("NODUS / IDEAS IN MOTION") as NSString).draw(at: CGPoint(x: 55, y: 45), withAttributes: [.font: UIFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: violet])
                let titleBounds = CGRect(x: 55, y: 150, width: 420, height: 160)
                var titleFont = UIFont.systemFont(ofSize: 48, weight: .bold)
                let words = title.components(separatedBy: .whitespacesAndNewlines).filter { $0.range(of: #"\p{Latin}"#, options: .regularExpression) != nil }
                while titleFont.pointSize > 28 && (
                    (title as NSString).boundingRect(with: titleBounds.size, options: .usesLineFragmentOrigin, attributes: [.font: titleFont], context: nil).height > titleBounds.height ||
                    words.contains { ($0 as NSString).size(withAttributes: [.font: titleFont]).width > titleBounds.width }
                ) {
                    titleFont = UIFont.systemFont(ofSize: titleFont.pointSize - 2, weight: .bold)
                }
                (title as NSString).draw(in: titleBounds, withAttributes: [.font: titleFont, .foregroundColor: ink])
                (L10n.text("People, ideas and opportunities\nin a more connected world.") as NSString).draw(in: CGRect(x: 55, y: 326, width: 405, height: 95), withAttributes: [.font: UIFont.systemFont(ofSize: 20), .foregroundColor: ink.withAlphaComponent(0.65)])
                let points = [CGPoint(x: 665, y: 180), CGPoint(x: 795, y: 150), CGPoint(x: 865, y: 245), CGPoint(x: 770, y: 300), CGPoint(x: 625, y: 325), CGPoint(x: 680, y: 420), CGPoint(x: 850, y: 400)]
                context.cgContext.setStrokeColor(violet.withAlphaComponent(0.25).cgColor); context.cgContext.setLineWidth(1.5)
                for (i, point) in points.enumerated() { for other in points.dropFirst(i + 1) where abs(point.x - other.x) < 200 {
                    context.cgContext.move(to: point); context.cgContext.addLine(to: other); context.cgContext.strokePath()
                } }
                for (i, point) in points.enumerated() {
                    violet.withAlphaComponent(0.35 + Double(i % 3) * 0.2).setFill()
                    let r = CGFloat(i == 1 || i == 3 ? 20 : 13)
                    context.cgContext.fillEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
                }
                (L10n.text("Research · Collaboration · Impact") as NSString).draw(at: CGPoint(x: 55, y: 485), withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: ink.withAlphaComponent(0.55)])
                ("\(index + 1) / \(titles.count)" as NSString).draw(at: CGPoint(x: 858, y: 485), withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium), .foregroundColor: violet])
            }
        }
        return PDFDocument(data: data)
    }
}
