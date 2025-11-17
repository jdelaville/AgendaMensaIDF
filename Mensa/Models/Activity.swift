import Foundation

struct Activity: Identifiable, Equatable {
    let id: String // id propre à Swift
    let act_id: String
    var title: String = "?"
    var place: String = "?"
    var date: String = "?"
    var time: String = "?"
    var author: String = "?"
    var cost: String = "?"
    var attendees: Int = 0
    var guests: Int = 0
    var guestsList: [String] = []
    var max_attendees: Int = -1 // -1 pour illimité
    var max_guests: Int = 0
    var description: String = "Pas de description."
    var regState: Int = 0 // 0=non inscrit, 1=inscrit, 10=liste d'attente, 11=inscrit sur liste d'attente

    static func ==(lhs: Activity, rhs: Activity) -> Bool {
        return lhs.id == rhs.id
    }
}
