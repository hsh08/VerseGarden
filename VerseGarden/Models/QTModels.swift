import Foundation

enum QTContentSource: String, Codable, Hashable {
    case local
    case global
    case community
}

struct QTVerseLine: Identifiable, Codable, Hashable {
    let id: String
    let verseNumber: Int
    let text: String
}

struct QTContent: Identifiable, Hashable {
    let id: String
    let date: Date
    let verseId: String?
    let startVerseId: String?
    let endVerseId: String?
    let reference: String
    let verseText: String
    let verseLines: [QTVerseLine]
    let title: String
    let devotionalText: String
    let reflectionQuestions: [String]
    let reflectionPrompt: String
    let applicationPrompt: String
    let prayerPrompt: String
    let contentId: String?
    let contentDateKey: String?
    let contentVersion: Int?
    let source: QTContentSource
    let communityId: String?
    let communityName: String?

    init(
        date: Date,
        calendar: Calendar = .current,
        todayVerse: TodayVerseContent?,
        fallbackVerse: LocalBibleVerse? = nil
    ) {
        let resolvedVerse = todayVerse?.verse ?? fallbackVerse
        self.id = QTRecord.dateKey(for: date, calendar: calendar)
        self.date = calendar.startOfDay(for: date)
        self.verseId = resolvedVerse?.id
        self.startVerseId = resolvedVerse?.id
        self.endVerseId = resolvedVerse?.id
        self.reference = resolvedVerse?.referenceText ?? todayVerse?.referenceText ?? "오늘의 말씀"
        self.verseText = resolvedVerse?.text ?? todayVerse?.displayText ?? "오늘의 말씀을 준비하는 중입니다."
        self.verseLines = resolvedVerse.map {
            [QTVerseLine(id: $0.id, verseNumber: $0.verse, text: $0.text)]
        } ?? []
        self.title = "오늘의 QT"
        self.devotionalText = "천천히 읽고, 오늘의 마음과 실천을 짧게 남겨보세요."
        self.reflectionQuestions = [
            "오늘 말씀에서 가장 마음에 남는 단어는 무엇인가요?",
            "오늘 내가 순종으로 심을 작은 행동은 무엇인가요?"
        ]
        self.reflectionPrompt = "오늘 마음에 남은 말씀"
        self.applicationPrompt = "오늘 내가 심을 작은 행동"
        self.prayerPrompt = "오늘의 기도"
        self.contentId = nil
        self.contentDateKey = nil
        self.contentVersion = nil
        self.source = .local
        self.communityId = nil
        self.communityName = nil
    }

    init(
        id: String,
        date: Date,
        verseId: String?,
        startVerseId: String?,
        endVerseId: String?,
        reference: String,
        verseText: String,
        verseLines: [QTVerseLine],
        title: String,
        devotionalText: String,
        reflectionQuestions: [String],
        reflectionPrompt: String,
        applicationPrompt: String,
        prayerPrompt: String,
        contentId: String?,
        contentDateKey: String?,
        contentVersion: Int?,
        source: QTContentSource,
        communityId: String? = nil,
        communityName: String? = nil
    ) {
        self.id = id
        self.date = date
        self.verseId = verseId
        self.startVerseId = startVerseId
        self.endVerseId = endVerseId
        self.reference = reference
        self.verseText = verseText
        self.verseLines = verseLines
        self.title = title
        self.devotionalText = devotionalText
        self.reflectionQuestions = reflectionQuestions
        self.reflectionPrompt = reflectionPrompt
        self.applicationPrompt = applicationPrompt
        self.prayerPrompt = prayerPrompt
        self.contentId = contentId
        self.contentDateKey = contentDateKey
        self.contentVersion = contentVersion
        self.source = source
        self.communityId = communityId
        self.communityName = communityName
    }
}

struct QTRecord: Identifiable, Codable, Hashable {
    let id: String
    let dateKey: String
    let date: Date
    let verseId: String?
    let startVerseId: String?
    let endVerseId: String?
    let reference: String
    let verseText: String
    let contentId: String?
    let contentDateKey: String?
    let contentVersion: Int?
    let contentSource: QTContentSource?
    let communityId: String?
    var reflectionAnswer: String
    var applicationText: String
    var prayerText: String
    var completedAt: Date?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        dateKey: String,
        date: Date,
        verseId: String?,
        startVerseId: String? = nil,
        endVerseId: String? = nil,
        reference: String,
        verseText: String,
        contentId: String? = nil,
        contentDateKey: String? = nil,
        contentVersion: Int? = nil,
        contentSource: QTContentSource? = nil,
        communityId: String? = nil,
        reflectionAnswer: String = "",
        applicationText: String = "",
        prayerText: String = "",
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dateKey = dateKey
        self.date = date
        self.verseId = verseId
        self.startVerseId = startVerseId
        self.endVerseId = endVerseId
        self.reference = reference
        self.verseText = verseText
        self.contentId = contentId
        self.contentDateKey = contentDateKey
        self.contentVersion = contentVersion
        self.contentSource = contentSource
        self.communityId = communityId
        self.reflectionAnswer = reflectionAnswer
        self.applicationText = applicationText
        self.prayerText = prayerText
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(content: QTContent, calendar: Calendar = .current) {
        let dateKey = content.contentDateKey ?? QTRecord.dateKey(for: content.date, calendar: calendar)
        self.init(
            id: "qt-\(dateKey)",
            dateKey: dateKey,
            date: calendar.startOfDay(for: content.date),
            verseId: content.verseId,
            startVerseId: content.startVerseId,
            endVerseId: content.endVerseId,
            reference: content.reference,
            verseText: content.verseText,
            contentId: content.contentId,
            contentDateKey: content.contentDateKey,
            contentVersion: content.contentVersion,
            contentSource: content.source,
            communityId: content.communityId
        )
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var hasDraft: Bool {
        !reflectionAnswer.trimmedForQT.isEmpty
            || !applicationText.trimmedForQT.isEmpty
            || !prayerText.trimmedForQT.isEmpty
    }

    static func dateKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

private extension String {
    var trimmedForQT: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
