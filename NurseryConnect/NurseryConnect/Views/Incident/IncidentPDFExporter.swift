// Views/Incident/IncidentPDFExporter.swift
// NurseryConnect
// PDFKit-backed incident report generator.
// Produces a printable A4 document suitable for Ofsted inspection records.
// Uses UIGraphicsPDFRenderer for layout and PDFDocument for metadata/export.

import PDFKit
import UIKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Transferable wrapper (enables SwiftUI ShareLink)

struct IncidentReport: Transferable {
    let pdfData: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { $0.pdfData }
    }
}

// MARK: - PDF Generator

enum IncidentPDFExporter {

    // A4 at 72 pt/inch
    private static let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
    private static let margin:  CGFloat = 48
    // ncAccent #2a6677
    private static let accentUI = UIColor(red: 0.165, green: 0.400, blue: 0.467, alpha: 1)
    private static let warnUI   = UIColor(red: 0.941, green: 0.627, blue: 0.125, alpha: 1)

    // MARK: Public entry point

    static func generate(incident: Incident, child: Child) -> IncidentReport {
        // 1 — Render via UIKit PDF renderer
        let rawData = UIGraphicsPDFRenderer(bounds: pageRect).pdfData { ctx in
            ctx.beginPage()
            drawPage(ctx: ctx.cgContext, incident: incident, child: child)
        }

        // 2 — Wrap in PDFDocument (PDFKit) to inject document metadata
        let pdf = PDFDocument(data: rawData) ?? PDFDocument()
        pdf.documentAttributes = [
            PDFDocumentAttribute.titleAttribute:         "Incident Report — \(child.fullName)" as AnyObject,
            PDFDocumentAttribute.authorAttribute:        incident.keyworkerName as AnyObject,
            PDFDocumentAttribute.creatorAttribute:       "NurseryConnect v1.0" as AnyObject,
            PDFDocumentAttribute.creationDateAttribute:  incident.timestamp as AnyObject,
            PDFDocumentAttribute.keywordsAttribute:      ["EYFS", "Incident", "NurseryConnect", incident.incidentType.rawValue] as AnyObject,
        ]
        let finalData = pdf.dataRepresentation() ?? rawData
        let filename  = "Incident_\(child.lastName)_\(incident.id.uuidString.prefix(8).uppercased()).pdf"
        return IncidentReport(pdfData: finalData, filename: filename)
    }

    // MARK: Page drawing

    private static func drawPage(ctx: CGContext, incident: Incident, child: Child) {
        var y = margin

        // ── Header band ──────────────────────────────────────────────
        ctx.setFillColor(accentUI.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pageRect.width, height: 68))

        draw("NurseryConnect — Incident Report",
             at: .init(x: margin, y: 14),
             font: .boldSystemFont(ofSize: 17), color: .white)
        draw("Confidential  |  EYFS Statutory Framework 2024  |  RIDDOR",
             at: .init(x: margin, y: 41),
             font: .systemFont(ofSize: 9), color: UIColor(white: 1, alpha: 0.72))

        y = 80

        // ── RIDDOR warning banner ────────────────────────────────────
        if incident.riddorRequired {
            ctx.setFillColor(warnUI.withAlphaComponent(0.12).cgColor)
            ctx.fill(CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: 26))
            ctx.setStrokeColor(warnUI.withAlphaComponent(0.55).cgColor)
            ctx.setLineWidth(0.75)
            ctx.stroke(CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: 26))
            draw("⚠  RIDDOR Reportable — Notify Responsible Person & report to HSE within required period",
                 at: .init(x: margin + 8, y: y + 6),
                 font: .boldSystemFont(ofSize: 9),
                 color: UIColor(red: 0.60, green: 0.33, blue: 0, alpha: 1))
            y += 36
        }

        y += 6

        // ── Child Information ────────────────────────────────────────
        y = section("Child Information", y: y, ctx: ctx)
        y = field("Full Name",       child.fullName,            y: y, ctx: ctx)
        y = field("Date of Birth",   child.birthdayFormatted,   y: y, ctx: ctx)
        y = field("Age",             child.ageDescription,      y: y, ctx: ctx)
        y = field("Keyworker",       incident.keyworkerName,    y: y, ctx: ctx)
        y += 6

        // ── Incident Details ─────────────────────────────────────────
        y = section("Incident Details", y: y, ctx: ctx)
        y = field("Type",        incident.incidentType.rawValue,         y: y, ctx: ctx)
        y = field("Title",       incident.title,                         y: y, ctx: ctx)
        y = field("Location",    incident.location.isEmpty ? "Not specified" : incident.location, y: y, ctx: ctx)
        y = field("Date & Time", incident.timestamp.fullDateTime,         y: y, ctx: ctx)
        y += 6

        // ── Description ──────────────────────────────────────────────
        y = section("Description of Incident", y: y, ctx: ctx)
        y = multiline(incident.descriptionText, y: y, ctx: ctx)
        y += 6

        // ── Witnesses ────────────────────────────────────────────────
        if !incident.witnessNames.isEmpty {
            y = section("Witnesses", y: y, ctx: ctx)
            y = multiline(incident.witnessNames, y: y, ctx: ctx)
            y += 6
        }

        // ── Notification & Review ────────────────────────────────────
        y = section("Notification & Review Status", y: y, ctx: ctx)
        y = field("Parent/Carer Notified", incident.parentNotified ? "Yes" : "No", y: y, ctx: ctx)
        if incident.parentNotified && !incident.parentSignature.isEmpty {
            y = field("Parent/Carer Name", incident.parentSignature, y: y, ctx: ctx)
        }
        y = field("Review Status", incident.reviewStatus.rawValue, y: y, ctx: ctx)
        y = field("RIDDOR Ref.",   incident.riddorRef.isEmpty ? "N/A" : incident.riddorRef, y: y, ctx: ctx)
        y += 14

        // ── Signature boxes ──────────────────────────────────────────
        let boxW = (pageRect.width - margin * 2 - 18) / 2

        // Keyworker
        signatureBox(
            label: "Keyworker Signature",
            name:  incident.keyworkerName,
            rect:  CGRect(x: margin, y: y, width: boxW, height: 62),
            ctx:   ctx
        )
        // Manager
        signatureBox(
            label: "Manager Countersignature",
            name:  incident.managerName.isEmpty ? "(awaiting)" : incident.managerName,
            rect:  CGRect(x: margin + boxW + 18, y: y, width: boxW, height: 62),
            ctx:   ctx
        )

        // ── Footer ───────────────────────────────────────────────────
        draw("Generated \(Date().fullDateTime)  |  NurseryConnect  |  Ref: \(incident.id.uuidString.prefix(8).uppercased())",
             at: .init(x: margin, y: pageRect.height - 26),
             font: .systemFont(ofSize: 8),
             color: .systemGray)
    }

    // MARK: Drawing helpers

    @discardableResult
    private static func section(_ title: String, y: CGFloat, ctx: CGContext) -> CGFloat {
        ctx.setFillColor(accentUI.withAlphaComponent(0.09).cgColor)
        ctx.fill(CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: 19))
        draw(title.uppercased(),
             at: .init(x: margin + 7, y: y + 4),
             font: .boldSystemFont(ofSize: 8.5),
             color: accentUI)
        return y + 24
    }

    @discardableResult
    private static func field(_ label: String, _ value: String, y: CGFloat, ctx: CGContext) -> CGFloat {
        let labelW: CGFloat = 132
        let valueX = margin + 10 + labelW
        let valueW = pageRect.width - margin - 8 - valueX

        draw(label + ":",
             at: .init(x: margin + 10, y: y + 3),
             font: .boldSystemFont(ofSize: 9.5),
             color: UIColor(white: 0.35, alpha: 1))
        draw(value.isEmpty ? "—" : value,
             at: .init(x: valueX, y: y + 3),
             font: .systemFont(ofSize: 9.5),
             color: .darkGray,
             maxWidth: valueW)

        ctx.setStrokeColor(UIColor(white: 0, alpha: 0.07).cgColor)
        ctx.setLineWidth(0.4)
        ctx.move(to: .init(x: margin + 10, y: y + 19))
        ctx.addLine(to: .init(x: pageRect.width - margin - 8, y: y + 19))
        ctx.strokePath()

        return y + 21
    }

    @discardableResult
    private static func multiline(_ text: String, y: CGFloat, ctx: CGContext) -> CGFloat {
        let t      = text.isEmpty ? "—" : text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9.5),
            .foregroundColor: UIColor.darkGray,
        ]
        let maxW = pageRect.width - margin * 2 - 16
        let sz   = (t as NSString).boundingRect(
            with: .init(width: maxW, height: 300),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs, context: nil
        ).size
        (t as NSString).draw(in: .init(x: margin + 8, y: y + 5, width: maxW, height: sz.height + 4), withAttributes: attrs)
        return y + sz.height + 12
    }

    private static func signatureBox(label: String, name: String, rect: CGRect, ctx: CGContext) {
        ctx.setStrokeColor(UIColor(white: 0.75, alpha: 1).cgColor)
        ctx.setLineWidth(0.6)
        ctx.stroke(rect)
        draw(name,
             at: .init(x: rect.minX + 8, y: rect.minY + 8),
             font: .systemFont(ofSize: 9.5),
             color: .darkGray,
             maxWidth: rect.width - 16)
        draw(label,
             at: .init(x: rect.minX + 8, y: rect.maxY - 18),
             font: .systemFont(ofSize: 8),
             color: .systemGray,
             maxWidth: rect.width - 16)
    }

    private static func draw(
        _ text: String,
        at point: CGPoint,
        font: UIFont,
        color: UIColor,
        maxWidth: CGFloat = 500
    ) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(in: .init(x: point.x, y: point.y, width: maxWidth, height: 60), withAttributes: attrs)
    }
}
