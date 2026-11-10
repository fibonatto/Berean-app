nonisolated enum Translation: String, CaseIterable, Identifiable, Sendable {
    case kjv, acf, bam, naa, kjf, nvt, nvi

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
    var fileName: String { "bible-\(rawValue)" }

    var name: String {
        switch self {
        case .kjv: "King James Version"
        case .acf: "Almeida Corrigida Fiel"
        case .bam: "Bíblia Ave Maria"
        case .naa: "Nova Almeida Atualizada"
        case .kjf: "King James Fiel"
        case .nvt: "Nova Versão Transformadora"
        case .nvi: "Nova Versão Internacional"
        }
    }
}
