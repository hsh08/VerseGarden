import Foundation

struct ScriptureWritingPlanPreview {
    let title: String
    let book: String
    let startChapter: Int
    let endChapter: Int
    let startDate: Date
    let endDate: Date
    let totalDays: Int
    let totalVerses: Int
    let dailyCounts: [Int]
    let warningMessage: String?
    let verseSlices: [ScriptureWritingPlanSlice]
}

struct ScriptureWritingPlanSlice {
    let dayIndex: Int
    let date: Date
    let verses: [LocalBibleVerse]

    var startChapter: Int { verses.first?.chapter ?? 0 }
    var startVerse: Int { verses.first?.verse ?? 0 }
    var endChapter: Int { verses.last?.chapter ?? 0 }
    var endVerse: Int { verses.last?.verse ?? 0 }
    var verseCount: Int { verses.count }
}

enum ScriptureWritingPlanBuilderError: LocalizedError {
    case invalidChapterRange
    case emptyRange
    case durationExceedsVerseCount

    var errorDescription: String? {
        switch self {
        case .invalidChapterRange:
            return "시작 장과 끝 장을 다시 확인해보세요."
        case .emptyRange:
            return "선택한 범위에 구절이 없습니다."
        case .durationExceedsVerseCount:
            return "총 일수는 전체 구절 수보다 많을 수 없습니다."
        }
    }
}

enum ScriptureWritingPlanBuilder {
    private static let minimumTarget = 3
    private static let recommendedMaximumTarget = 25

    static func buildPreview(
        book: String,
        startChapter: Int,
        endChapter: Int,
        startDate: Date,
        totalDays: Int,
        service: BibleDataService = .shared,
        calendar: Calendar = .current
    ) throws -> ScriptureWritingPlanPreview {
        let verses = try fetchVerses(
            book: book,
            startChapter: startChapter,
            endChapter: endChapter,
            service: service
        )
        guard totalDays <= verses.count else {
            throw ScriptureWritingPlanBuilderError.durationExceedsVerseCount
        }

        let counts = balancedCounts(totalVerses: verses.count, totalDays: totalDays)
        let slices = buildSlices(
            verses: verses,
            counts: counts,
            startDate: startDate,
            calendar: calendar
        )
        let endDate = calendar.date(byAdding: .day, value: max(totalDays - 1, 0), to: calendar.startOfDay(for: startDate)) ?? startDate

        return ScriptureWritingPlanPreview(
            title: planTitle(book: book, startChapter: startChapter, endChapter: endChapter),
            book: book,
            startChapter: startChapter,
            endChapter: endChapter,
            startDate: calendar.startOfDay(for: startDate),
            endDate: endDate,
            totalDays: totalDays,
            totalVerses: verses.count,
            dailyCounts: counts,
            warningMessage: warningMessage(for: counts),
            verseSlices: slices
        )
    }

    static func createPlan(
        ownerUserId: String,
        preview: ScriptureWritingPlanPreview,
        folderColorRaw: String? = nil
    ) -> (plan: ScriptureWritingPlan, assignments: [PlanDayAssignment]) {
        let now = Date()
        let plan = ScriptureWritingPlan(
            ownerUserId: ownerUserId,
            title: preview.title,
            book: preview.book,
            startChapter: preview.startChapter,
            endChapter: preview.endChapter,
            startDate: preview.startDate,
            endDate: preview.endDate,
            totalDays: preview.totalDays,
            totalVerses: preview.totalVerses,
            folderColorRaw: folderColorRaw,
            status: .active,
            createdAt: now,
            updatedAt: now
        )

        let assignments = preview.verseSlices.map { slice in
            PlanDayAssignment(
                planLocalId: plan.id,
                ownerUserId: ownerUserId,
                dayIndex: slice.dayIndex,
                date: slice.date,
                book: preview.book,
                startChapter: slice.startChapter,
                startVerse: slice.startVerse,
                endChapter: slice.endChapter,
                endVerse: slice.endVerse,
                verseCount: slice.verseCount,
                state: .pending,
                createdAt: now,
                updatedAt: now
            )
        }

        return (plan, assignments)
    }

    static func planTitle(book: String, startChapter: Int, endChapter: Int) -> String {
        startChapter == endChapter ? "\(book) \(startChapter)장 필사" : "\(book) \(startChapter)–\(endChapter)장 필사"
    }

    static func verses(
        book: String,
        startChapter: Int,
        endChapter: Int,
        service: BibleDataService = .shared
    ) throws -> [LocalBibleVerse] {
        try fetchVerses(
            book: book,
            startChapter: startChapter,
            endChapter: endChapter,
            service: service
        )
    }

    static func slices(
        from verses: [LocalBibleVerse],
        startDate: Date,
        totalDays: Int,
        calendar: Calendar = .current
    ) -> (counts: [Int], warningMessage: String?, slices: [ScriptureWritingPlanSlice]) {
        let counts = balancedCounts(totalVerses: verses.count, totalDays: totalDays)
        let slices = buildSlices(
            verses: verses,
            counts: counts,
            startDate: startDate,
            calendar: calendar
        )
        return (counts, warningMessage(for: counts), slices)
    }

    private static func fetchVerses(
        book: String,
        startChapter: Int,
        endChapter: Int,
        service: BibleDataService
    ) throws -> [LocalBibleVerse] {
        guard startChapter <= endChapter else {
            throw ScriptureWritingPlanBuilderError.invalidChapterRange
        }

        let verses = (startChapter...endChapter).flatMap { service.getVerses(book: book, chapter: $0) }
        guard !verses.isEmpty else {
            throw ScriptureWritingPlanBuilderError.emptyRange
        }
        return verses
    }

    private static func buildSlices(
        verses: [LocalBibleVerse],
        counts: [Int],
        startDate: Date,
        calendar: Calendar
    ) -> [ScriptureWritingPlanSlice] {
        var cursor = 0
        let baseDate = calendar.startOfDay(for: startDate)

        return counts.enumerated().map { offset, count in
            let nextCursor = min(cursor + count, verses.count)
            let sliceVerses = Array(verses[cursor..<nextCursor])
            let date = calendar.date(byAdding: .day, value: offset, to: baseDate) ?? baseDate
            cursor = nextCursor
            return ScriptureWritingPlanSlice(dayIndex: offset + 1, date: date, verses: sliceVerses)
        }
    }

    private static func balancedCounts(totalVerses: Int, totalDays: Int) -> [Int] {
        let base = totalVerses / totalDays
        let remainder = totalVerses % totalDays
        var counts = (0..<totalDays).map { $0 < remainder ? base + 1 : base }

        func canBorrow(from source: Int, to target: Int) -> Bool {
            source >= 0 &&
            source < counts.count &&
            target >= 0 &&
            target < counts.count &&
            counts[source] > minimumTarget &&
            counts[target] < minimumTarget
        }

        var changed = true
        while changed {
            changed = false
            for index in counts.indices where counts[index] < minimumTarget {
                if canBorrow(from: index - 1, to: index) {
                    counts[index - 1] -= 1
                    counts[index] += 1
                    changed = true
                } else if canBorrow(from: index + 1, to: index) {
                    counts[index + 1] -= 1
                    counts[index] += 1
                    changed = true
                }
            }
        }

        changed = true
        while changed {
            changed = false
            for index in counts.indices where counts[index] > recommendedMaximumTarget {
                if index + 1 < counts.count, counts[index + 1] < recommendedMaximumTarget {
                    counts[index] -= 1
                    counts[index + 1] += 1
                    changed = true
                } else if index - 1 >= 0, counts[index - 1] < recommendedMaximumTarget {
                    counts[index] -= 1
                    counts[index - 1] += 1
                    changed = true
                }
            }
        }

        return counts
    }

    private static func warningMessage(for counts: [Int]) -> String? {
        guard let min = counts.min(), let max = counts.max() else { return nil }
        if min < minimumTarget || max > recommendedMaximumTarget {
            return "선택한 기간에서는 하루 분량 편차가 조금 생길 수 있습니다."
        }
        return nil
    }
}
