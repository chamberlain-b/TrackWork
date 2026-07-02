import Foundation

enum JurisdictionCatalog {
    static let all: [Jurisdiction] = [
        Jurisdiction(id: "AU-ACT", country: .australia, displayName: "Australian Capital Territory", shortName: "ACT"),
        Jurisdiction(id: "AU-NSW", country: .australia, displayName: "New South Wales", shortName: "NSW"),
        Jurisdiction(id: "AU-NT", country: .australia, displayName: "Northern Territory", shortName: "NT"),
        Jurisdiction(id: "AU-QLD", country: .australia, displayName: "Queensland", shortName: "QLD"),
        Jurisdiction(id: "AU-SA", country: .australia, displayName: "South Australia", shortName: "SA"),
        Jurisdiction(id: "AU-TAS", country: .australia, displayName: "Tasmania", shortName: "TAS"),
        Jurisdiction(id: "AU-VIC", country: .australia, displayName: "Victoria", shortName: "VIC"),
        Jurisdiction(id: "AU-WA", country: .australia, displayName: "Western Australia", shortName: "WA"),
        Jurisdiction(id: "NZ-NATIONAL", country: .newZealand, displayName: "New Zealand National", shortName: "NZ National"),
        Jurisdiction(id: "NZ-NORTHLAND", country: .newZealand, displayName: "Northland", shortName: "Northland"),
        Jurisdiction(id: "NZ-AUCKLAND", country: .newZealand, displayName: "Auckland", shortName: "Auckland"),
        Jurisdiction(id: "NZ-TARANAKI", country: .newZealand, displayName: "Taranaki", shortName: "Taranaki"),
        Jurisdiction(id: "NZ-HAWKES-BAY", country: .newZealand, displayName: "Hawke's Bay", shortName: "Hawke's Bay"),
        Jurisdiction(id: "NZ-WELLINGTON", country: .newZealand, displayName: "Wellington", shortName: "Wellington"),
        Jurisdiction(id: "NZ-MARLBOROUGH", country: .newZealand, displayName: "Marlborough", shortName: "Marlborough"),
        Jurisdiction(id: "NZ-NELSON", country: .newZealand, displayName: "Nelson", shortName: "Nelson"),
        Jurisdiction(id: "NZ-CANTERBURY", country: .newZealand, displayName: "Canterbury", shortName: "Canterbury"),
        Jurisdiction(id: "NZ-SOUTH-CANTERBURY", country: .newZealand, displayName: "South Canterbury", shortName: "South Canterbury"),
        Jurisdiction(id: "NZ-WESTLAND", country: .newZealand, displayName: "Westland", shortName: "Westland"),
        Jurisdiction(id: "NZ-OTAGO", country: .newZealand, displayName: "Otago", shortName: "Otago"),
        Jurisdiction(id: "NZ-SOUTHLAND", country: .newZealand, displayName: "Southland", shortName: "Southland"),
        Jurisdiction(id: "NZ-CHATHAM-ISLANDS", country: .newZealand, displayName: "Chatham Islands", shortName: "Chatham Islands")
    ]

    static func jurisdictions(for country: Country) -> [Jurisdiction] {
        all.filter { $0.country == country }
    }
}
