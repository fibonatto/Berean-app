nonisolated enum Translation: String, CaseIterable, Identifiable, Sendable {
	case kjv, acf, bam, naa, kjf, nvt, nvi, ntlh

	var id: String { rawValue }
	var title: String { rawValue.uppercased() }
	var fileName: String { "bible-\(rawValue)" }
}
