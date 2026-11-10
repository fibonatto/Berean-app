//
//  Canon.swift
//  Berean
//
//  Created by Sergio Bonatto on 10/11/26.
//

nonisolated enum Canon {
    static let order: [String] = [
        "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1KI", "2KI",
        "1CH", "2CH", "EZR", "NEH", "TOB", "JDT", "EST", "JOB", "PSA", "1MA", "2MA", "PRO",
        "ECC", "SNG", "WIS", "SIR", "ISA", "JER", "LAM", "BAR", "EZK", "DAN", "HOS", "JOL",
        "AMO", "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL", "MAT", "MRK",
        "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP", "COL", "1TH", "2TH",
        "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN", "3JN", "JUD",
        "REV",
    ]

    static func key(forBookID id: String) -> String {
        legacyKeys[id] ?? id
    }

    static func rank(of key: String) -> Int? {
        ranks[key]
    }

    private static let ranks: [String: Int] = Dictionary(
        uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) }
    )

    private static let legacyKeys: [String: String] = acfKeys.merging(bamKeys) { first, _ in first }

    private static let acfKeys: [String: String] = [
        "gn": "GEN", "ex": "EXO", "lv": "LEV", "nm": "NUM", "dt": "DEU", "js": "JOS",
        "jud": "JDG", "rt": "RUT", "1sm": "1SA", "2sm": "2SA", "1kgs": "1KI", "2kgs": "2KI",
        "1ch": "1CH", "2ch": "2CH", "ezr": "EZR", "ne": "NEH", "et": "EST", "job": "JOB",
        "ps": "PSA", "prv": "PRO", "ec": "ECC", "so": "SNG", "is": "ISA", "jr": "JER",
        "lm": "LAM", "ez": "EZK", "dn": "DAN", "ho": "HOS", "jl": "JOL", "am": "AMO",
        "ob": "OBA", "jn": "JON", "mi": "MIC", "na": "NAM", "hk": "HAB", "zp": "ZEP",
        "hg": "HAG", "zc": "ZEC", "ml": "MAL", "mt": "MAT", "mk": "MRK", "lk": "LUK",
        "jo": "JHN", "act": "ACT", "rm": "ROM", "1co": "1CO", "2co": "2CO", "gl": "GAL",
        "eph": "EPH", "ph": "PHP", "cl": "COL", "1ts": "1TH", "2ts": "2TH", "1tm": "1TI",
        "2tm": "2TI", "tt": "TIT", "phm": "PHM", "hb": "HEB", "jm": "JAS", "1pe": "1PE",
        "2pe": "2PE", "1jo": "1JN", "2jo": "2JN", "3jo": "3JN", "jd": "JUD", "re": "REV",
    ]

    private static let bamKeys: [String: String] = [
        "Gn": "GEN", "Ex": "EXO", "Lv": "LEV", "Nm": "NUM", "Dt": "DEU", "Js": "JOS",
        "Jz": "JDG", "Rt": "RUT", "1Sm": "1SA", "2Sm": "2SA", "1Rs": "1KI", "2Rs": "2KI",
        "1Cr": "1CH", "2Cr": "2CH", "Esd": "EZR", "Ne": "NEH", "Tb": "TOB", "Jt": "JDT",
        "Est": "EST", "Jb": "JOB", "Sl": "PSA", "1Mc": "1MA", "2Mc": "2MA", "Pr": "PRO",
        "Ecl": "ECC", "Ct": "SNG", "Sb": "WIS", "Eclo": "SIR", "Is": "ISA", "Jr": "JER",
        "Lm": "LAM", "Br": "BAR", "Ez": "EZK", "Dn": "DAN", "Os": "HOS", "Jl": "JOL",
        "Am": "AMO", "Ab": "OBA", "Jn": "JON", "Mq": "MIC", "Na": "NAM", "Hab": "HAB",
        "Sf": "ZEP", "Ag": "HAG", "Zc": "ZEC", "Ml": "MAL", "Mt": "MAT", "Mc": "MRK",
        "Lc": "LUK", "Jo": "JHN", "At": "ACT", "Rm": "ROM", "1Cor": "1CO", "2Cor": "2CO",
        "Gl": "GAL", "Ef": "EPH", "Fl": "PHP", "Cl": "COL", "1Ts": "1TH", "2Ts": "2TH",
        "1Tm": "1TI", "2Tm": "2TI", "Tt": "TIT", "Fm": "PHM", "Hb": "HEB", "Tg": "JAS",
        "1Pd": "1PE", "2Pd": "2PE", "1Jo": "1JN", "2Jo": "2JN", "3Jo": "3JN", "Jd": "JUD",
        "Ap": "REV",
    ]
}
