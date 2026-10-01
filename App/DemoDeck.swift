import UIKit
import PDFKit

enum DemoDeck {
    static let titles = ["Las ideas nos conectan", "Un mapa para orientarnos", "Redes de conocimiento", "Comunidades que transforman", "De la pregunta al hallazgo", "Conversaciones que importan", "Conectar para comprender", "Lo que construimos juntos"]
    static let notes = Dictionary(uniqueKeysWithValues: titles.enumerated().map { i, _ in
        (String(i + 1), "Las redes de conocimiento nos permiten conectar personas, ideas y oportunidades de forma significativa.\n\nEn un mundo cada vez más interconectado, el verdadero avance surge cuando compartimos, colaboramos y aprendemos juntos.\n\n\(i == 2 ? "Señala las conexiones con Spotlight. La audiencia ve exactamente dónde está el foco." : "Haz una pausa antes de pasar a la siguiente idea y deja espacio para una pregunta.")")
    })
    static func make() -> PDFDocument? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 960, height: 540))
        let data = renderer.pdfData { context in
            for (index, title) in titles.enumerated() {
                context.beginPage()
                UIColor.white.setFill(); context.cgContext.fill(CGRect(x: 0, y: 0, width: 960, height: 540))
                let ink = UIColor(red: 0.08, green: 0.07, blue: 0.19, alpha: 1)
                let violet = UIColor(red: 0.50, green: 0.35, blue: 0.95, alpha: 1)
                ("NODUS / IDEAS EN MOVIMIENTO" as NSString).draw(at: CGPoint(x: 55, y: 45), withAttributes: [.font: UIFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: violet])
                (title as NSString).draw(in: CGRect(x: 55, y: 150, width: 420, height: 160), withAttributes: [.font: UIFont.systemFont(ofSize: 48, weight: .bold), .foregroundColor: ink])
                ("Personas, ideas y oportunidades\nen un mundo más conectado." as NSString).draw(in: CGRect(x: 55, y: 326, width: 405, height: 95), withAttributes: [.font: UIFont.systemFont(ofSize: 20), .foregroundColor: ink.withAlphaComponent(0.65)])
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
                ("Investigación · Colaboración · Impacto" as NSString).draw(at: CGPoint(x: 55, y: 485), withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: ink.withAlphaComponent(0.55)])
                ("\(index + 1) / \(titles.count)" as NSString).draw(at: CGPoint(x: 858, y: 485), withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium), .foregroundColor: violet])
            }
        }
        return PDFDocument(data: data)
    }
}
