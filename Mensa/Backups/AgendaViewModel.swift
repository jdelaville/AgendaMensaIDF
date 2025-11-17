import Foundation
import Combine
import SwiftUI
import Alamofire

@MainActor
class AgendaViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var currentMonth: Int
    @Published var currentYear: Int

    init() {
        let date = Date()
        let calendar = Calendar.current
        self.currentMonth = calendar.component(.month, from: date)
        self.currentYear = calendar.component(.year, from: date)
    }

    func fetchAgenda() {
        guard AuthService.shared.isLoggedIn else {
            errorMessage = "Non connecté"
            return
        }

        isLoading = true
        let url = HTMLUtils.baseURL + "?action=iAgenda_iagenda&mois=\(currentMonth)&annee=\(currentYear)"

        AF.request(url)
            .validate()
            .responseString { response in
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch response.result {
                    case .success(let html):
                        if let tbodyRange = html.range(of: #"<tbody[^>]*>([\s\S]*?)</tbody>"#, options: .regularExpression) {
                            self.parseHTML(String(html[tbodyRange]))
                        } else {
                            print("⚠️ Aucun bloc <tbody> trouvé.")
                        }
                    case .failure(let error):
                        self.activities = []
                        self.errorMessage = "Erreur réseau : \(error.localizedDescription)"
                    }
                }
            }
    }

    func goToNextMonth() {
        currentMonth += 1
        if currentMonth > 12 {
            currentMonth = 1
            currentYear += 1
        }
        fetchAgenda()
    }

    func goToPreviousMonth() {
        if currentMonth > 1 {
            currentMonth -= 1
        } else {
            currentMonth = 12
            currentYear -= 1
        }
        fetchAgenda()
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.monthSymbols[self.currentMonth - 1].capitalized
    }

    private func parseHTML(_ html: String) {
        let nsHTML = html as NSString
        activities = []

        guard let tdRegex = fetchRegex(#"<td\s+class=\"\s*(?:|activite_jour|week\-end)\s*\"[^>]*>.*?</td>"#) else { return }
        let tdMatches = tdRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length))

        for tdMatch in tdMatches {
            let tdContent = nsHTML.substring(with: tdMatch.range)
            let nsTD = tdContent as NSString
            let tdLength = nsTD.length

            // --- Extraction du jour complet depuis le <span> ---
            var fullDate = "?"

            if let spanRegex = try? NSRegularExpression(
                pattern: #"<span(?:\s+[^>]*)?>(.*?)</span>"#,
                options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let match = spanRegex.firstMatch(in: tdContent, options: [], range: NSRange(location: 0, length: tdLength)) {

                var extracted = nsTD.substring(with: match.range(at: 1))
                if let innerTagRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
                    extracted = innerTagRegex.stringByReplacingMatches(
                        in: extracted,
                        options: [],
                        range: NSRange(location: 0, length: extracted.utf16.count),
                        withTemplate: ""
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                fullDate = "\(extracted) \(monthName) \(self.currentYear)"
            }

            // --- Récupération des activités du jour ---
            guard let liRegex = fetchRegex(#"<li[^>]*>(.*?)</li>"#) else { continue }
            let liMatches = liRegex.matches(in: tdContent, options: [], range: NSRange(location: 0, length: nsTD.length))

            for liMatch in liMatches {
                let liContent = nsTD.substring(with: liMatch.range(at: 1))
                let nsLI = liContent as NSString

                var act_id = "?"
                var time = "?"
                var place = "?"
                var attendees = 0
                
                if let aRegex = fetchRegex(#"<a [^>]*class=\"([^\"]*)\"[^>]*href=\"([^\"]*)\"[^>]*title=\"([\s\S]*?)\"[^>]*>([\s\S]*?)</a>"#),
                   let aMatch = aRegex.firstMatch(in: liContent, options: [], range: NSRange(location: 0, length: nsLI.length)) {

                    let aClass = nsLI.substring(with: aMatch.range(at: 1))
                    let href = nsLI.substring(with: aMatch.range(at: 2))
                    let titleInfo = nsLI.substring(with: aMatch.range(at: 3))
                    let title = HTMLUtils.htmlToPlainText(nsLI.substring(with: aMatch.range(at: 4)))

                    // --- État d’inscription ---
                    var regState = 0
                    if aClass.contains("agenda_inscrit_attente") { regState = 11 }
                    else if aClass.contains("agenda_inscrit") { regState = 1 }

                    // --- Extraction de l'id de l'activité ---
                    if let idRange = href.range(of: "id=") {
                        act_id = String(href[idRange.upperBound...])
                    }

                    if let range = titleInfo.range(of: #"Nb d'inscrits\s*:\s*([^,]*)"#, options: .regularExpression) {
                        attendees = Int(titleInfo[range]
                                            .replacingOccurrences(of: "Nb d'inscrits :", with: "")
                                            .trimmingCharacters(in: .whitespaces)) ?? 0
                    }
                    
                    if let range = titleInfo.range(of: #"horaires de l'activité de\s*:\s*([^,]*)"#, options: .regularExpression) {
                        time = HTMLUtils.htmlToPlainText(String(titleInfo[range])
                            .replacingOccurrences(of: "horaires de l'activité de :", with: "")
                            .trimmingCharacters(in: .whitespaces))
                    }

                    if let lieuStart = titleInfo.range(of: "lieu :")?.upperBound,
                       let ecritRange = titleInfo.range(of: " a &eacute;crit :")?.lowerBound {
                        let lieuSection = titleInfo[lieuStart..<ecritRange]
                        if let lastComma = lieuSection.lastIndex(of: ",") {
                            place = HTMLUtils.htmlToPlainText(String(lieuSection[..<lastComma]).trimmingCharacters(in: .whitespacesAndNewlines))
                        } else {
                            place = HTMLUtils.htmlToPlainText(String(lieuSection).trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        if place.isEmpty { place = "?" }
                    }

                    // --- Création de l’activité ---
                    let activity = Activity(
                        id: UUID().uuidString,
                        act_id: act_id,
                        title: title,
                        place: place,
                        date: fullDate,
                        time: time,
                        attendees: attendees,
                        regState: regState
                    )
                    activities.append(activity)
                }
            }
        }

        errorMessage = activities.isEmpty ? "Aucune activité trouvée..." : nil
    }

    private func fetchRegex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
    }
}

extension AgendaViewModel {
    var activitiesGroupedByDate: [(date: String, activities: [Activity])] {
        var grouped: [(date: String, activities: [Activity])] = []
        
        for activity in activities {
            if let index = grouped.firstIndex(where: { $0.date == activity.date }) {
                grouped[index].activities.append(activity)
            } else {
                grouped.append((date: activity.date, activities: [activity]))
            }
        }
        
        return grouped
    }
}
