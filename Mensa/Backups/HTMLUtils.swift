import Foundation
import Alamofire
import SwiftUI

struct HTMLUtils {
    static let baseURL = "https://mensa-idf.org/index.php"
    
    static func fetchActivity(by id: String) async throws -> Activity {
        let url = self.baseURL + "?action=iAgenda_iactivite&id=\(id)"
        let response = try await AF.request(url).serializingString().value
        
        // --- Extraction du bloc <dl> principal ---
        guard let dlRange = response.range(of: #"<dl[^>]*>([\s\S]*?)</dl>"#, options: .regularExpression) else {
            throw NSError(domain: "HTMLParsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Bloc <dl> introuvable dans la page HTML"])
        }
        let html = String(response[dlRange])

        // --- Création d’un objet Activity vide (qu’on remplira au fur et à mesure) ---
        var activity = Activity(
            id: UUID().uuidString,
            act_id: id,
            title: "?", // rempli depuis <h2> dans fetchActivity
            place: "?",
            date: "?",
            regState: 0
        )
        
        // --- Extraction du titre ---
        if let titleRegex = try? NSRegularExpression(
            pattern: #"<h2[^>]*>([\s\S]*?)</h2>"#,
            options: [.caseInsensitive]
        ), let match = titleRegex.firstMatch(in: response, options: [], range: NSRange(location: 0, length: response.utf16.count)),
           let range = Range(match.range(at: 1), in: response) {
            let rawTitle = String(response[range])
            activity.title = htmlToPlainText(rawTitle).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // --- Extraction du lieu et de la date ---
        if let infoRange = html.range(of: "<strong>([\\s\\S]*?)</strong>", options: .regularExpression) {
            let plainText = htmlToPlainText(String(html[infoRange]))
            let parts = plainText.components(separatedBy: "\n").filter {
                !$0.trimmingCharacters(in: .whitespaces).isEmpty
            }
            if parts.count >= 3 {
                activity.place = parts[1].trimmingCharacters(in: .whitespaces)
                activity.date = parts[2].trimmingCharacters(in: .whitespaces)
            }
        }

        // --- Auteur ---
        if let authorRange = html.range(of: #"Activit&eacute;\s*propos&eacute;e\s*par\s*<a[^>]*>([^<]+)</a>"#, options: .regularExpression) {
            let plainText = htmlToPlainText(String(html[authorRange]))
                .replacingOccurrences(of: "Activité proposée par", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            activity.author = plainText
        }

        // --- Coût estimé ---
        if let costRange = html.range(of: #"Co&ucirc;t\s+estim&eacute;\s+de\s+l'activit&eacute;\s*:\s*([^<]+)"#, options: .regularExpression) {
            let rawCost = String(html[costRange])
                .replacingOccurrences(of: "Coût estimé de l'activité :", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            activity.cost = htmlToPlainText(rawCost)
        }
        
        // --- Description (section Détails) ---
        if let detailsRegex = try? NSRegularExpression(
            pattern: #"<dt[^>]*>(?:Détails|D&eacute;tails)</dt>[\s\S]*?<dd[^>]*>([\s\S]*?)</dd>"#,
            options: [.caseInsensitive]
        ) {
            let nsHTML = html as NSString
            if let match = detailsRegex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length)),
               match.range(at: 1).location != NSNotFound {
                let htmlDescription = nsHTML.substring(with: match.range(at: 1))
                activity.description = htmlDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                print("⚠️ Aucun <dd> trouvé après <dt>Détails</dt>")
            }
        } else {
            print("⚠️ Regex Détails invalide ou introuvable")
        }
        // --- Nombre d’inscrits ---
        if let regex = try? NSRegularExpression(pattern: #"Nombre\s*d['’]inscrits\s*:\s*([0-9]+)"#, options: [.caseInsensitive]) {
            let nsHTML = html as NSString
            if let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length)) {
                let numberRange = match.range(at: 1)
                if numberRange.location != NSNotFound {
                    let numberString = nsHTML.substring(with: numberRange)
                    activity.attendees = Int(numberString) ?? 0
                }
            }
        }
        
        // --- Nombre maximum de personnes ---
        if let regex = try? NSRegularExpression(
            pattern: #"Nombre\s+de\s+personnes\s*(illimité|maximum\s*:\s*([0-9]+))"#,
            options: [.caseInsensitive]
        ) {
            let nsHTML = html as NSString
            if let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length)) {
                // Groupe 1 : "illimité" ou "maximum : N"
                let fullMatch = nsHTML.substring(with: match.range(at: 1)).lowercased()
                
                if fullMatch.contains("illimité") {
                    activity.max_attendees = -1
                } else if match.numberOfRanges > 2, match.range(at: 2).location != NSNotFound {
                    let numberString = nsHTML.substring(with: match.range(at: 2))
                    activity.max_attendees = Int(numberString) ?? -1
                }
            }
        }

        // --- Nombre maximum d'invités ---
        if let regex = try? NSRegularExpression(pattern: #"([0-9]+)\s*invit&eacute;\(s\)\s*maximum\s*par\s*membre"#),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           let range = Range(match.range(at: 1), in: html) {
            activity.max_guests = Int(html[range]) ?? 0
        } else {
            activity.max_guests = 0
        }
        
        // --- Extraire la liste des invités ---
        if let range = html.range(of: "<p>Vous venez avec&nbsp;: ") {
            let substring = html[range.upperBound...]
            if let endRange = substring.range(of: "</p>") {
                let pContent = String(substring[..<endRange.lowerBound])

                let guestNames = pContent
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "(d&eacute;sinscription invit&eacute;)", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: " - ")
                                
                activity.guestsList = guestNames
                activity.guests = guestNames.count
            }
        } else {
            activity.guestsList = []
            activity.guests = 0
        }

        // --- État d’inscription ---
        if html.contains("Les inscriptions à cette activité sont closes") ||
           html.contains("Les inscriptions &agrave; cette activit&eacute; sont closes.") {
            activity.regState = -1
        } else if html.contains("name=\"d\" value=\"1\"") {
            activity.regState = 1
        } else if html.contains("name=\"d\" value=\"10\"") {
            activity.regState = 10
        } else if html.contains("name=\"d\" value=\"11\"") {
            activity.regState = 11
        } else {
            activity.regState = 0
        }

        return activity
    }

    // --- Conversion HTML → texte brut ---
    static func htmlToPlainText(_ html: String) -> String {
        var cleaned = html
        cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
        
        cleaned = cleaned.replacingOccurrences(of: "<a [^>]+>", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "</a>", with: "")
        cleaned = cleaned.replacingOccurrences(of: "<img[^>]+>", with: "", options: .regularExpression)
  
        guard let data = cleaned.data(using: .utf8) else { return html }
        if let attr = try? NSAttributedString(data: data,
                                              options: [.documentType: NSAttributedString.DocumentType.html,
                                                        .characterEncoding: String.Encoding.utf8.rawValue],
                                              documentAttributes: nil) {
            return attr.string
        }
        return html
    }
}
