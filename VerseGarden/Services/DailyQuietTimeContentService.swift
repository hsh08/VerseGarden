import FirebaseAuth
import FirebaseFirestore
import Foundation

struct RemoteDailyQuietTime: Hashable {
    struct Question: Hashable {
        let id: String
        let type: String
        let prompt: String
    }

    let dateKey: String
    let timezone: String
    let title: String
    let verseId: String
    let startVerseId: String?
    let endVerseId: String?
    let reference: String
    let translation: String
    let devotionalText: String
    let reflectionPrompt: String
    let applicationPrompt: String
    let prayerPrompt: String
    let questions: [Question]
    let status: String
    let version: Int
    let communityId: String?
}

struct DailyQuietTimeContentService {
    private var database: Firestore { Firestore.firestore() }
    private let globalDateKeyProvider = DailyQuietTimeDateKeyProvider()
    private let bibleService = BibleDataService.shared

    func fetchContent(
        for date: Date = Date(),
        community: Community? = nil
    ) async throws -> QTContent? {
        guard Auth.auth().currentUser != nil else {
            return nil
        }

        if let community, community.status == .active {
            let communityDateProvider = DailyQuietTimeDateKeyProvider(
                timeZoneIdentifier: community.timezone
            )
            let communityDateKey = communityDateProvider.dateKey(for: date)

            do {
                let snapshot = try await database
                    .collection("communities")
                    .document(community.id)
                    .collection("dailyQuietTimes")
                    .document(communityDateKey)
                    .getDocument()

                if let content = resolveContent(
                    snapshot: snapshot,
                    expectedDateKey: communityDateKey,
                    date: date,
                    source: .community,
                    expectedCommunity: community
                ) {
                    return content
                }
            } catch {
                #if DEBUG
                print("Community Daily QT fallback:", error.localizedDescription)
                #endif
            }
        }

        let globalDateKey = globalDateKeyProvider.dateKey(for: date)
        let snapshot = try await database
            .collection("dailyQuietTimes")
            .document(globalDateKey)
            .getDocument()

        return resolveContent(
            snapshot: snapshot,
            expectedDateKey: globalDateKey,
            date: date,
            source: .global,
            expectedCommunity: nil
        )
    }

    private func resolveContent(
        snapshot: DocumentSnapshot,
        expectedDateKey: String,
        date: Date,
        source: QTContentSource,
        expectedCommunity: Community?
    ) -> QTContent? {
        guard snapshot.exists,
              let data = snapshot.data(),
              let remote = makeRemoteDailyQuietTime(from: data),
              remote.status == "published",
              remote.dateKey == expectedDateKey else {
            return nil
        }

        if let expectedCommunity,
           remote.communityId != expectedCommunity.id {
            return nil
        }

        return makeQTContent(
            from: remote,
            date: date,
            source: source,
            community: expectedCommunity
        )
    }

    private func makeRemoteDailyQuietTime(from data: [String: Any]) -> RemoteDailyQuietTime? {
        guard let dateKey = data["dateKey"] as? String,
              let timezone = data["timezone"] as? String,
              let title = data["title"] as? String,
              let verseId = data["verseId"] as? String,
              let reference = data["reference"] as? String,
              let translation = data["translation"] as? String,
              let devotionalText = data["devotionalText"] as? String,
              let reflectionPrompt = data["reflectionPrompt"] as? String,
              let applicationPrompt = data["applicationPrompt"] as? String,
              let prayerPrompt = data["prayerPrompt"] as? String,
              let status = data["status"] as? String,
              let version = intValue(data["version"]) else {
            return nil
        }

        let questions = (data["questions"] as? [[String: Any]])?.compactMap { item -> RemoteDailyQuietTime.Question? in
            guard let id = item["id"] as? String,
                  let type = item["type"] as? String,
                  let prompt = item["prompt"] as? String else {
                return nil
            }
            return RemoteDailyQuietTime.Question(id: id, type: type, prompt: prompt)
        } ?? []

        return RemoteDailyQuietTime(
            dateKey: dateKey,
            timezone: timezone,
            title: title,
            verseId: verseId,
            startVerseId: data["startVerseId"] as? String,
            endVerseId: data["endVerseId"] as? String,
            reference: reference,
            translation: translation,
            devotionalText: devotionalText,
            reflectionPrompt: reflectionPrompt,
            applicationPrompt: applicationPrompt,
            prayerPrompt: prayerPrompt,
            questions: questions,
            status: status,
            version: version,
            communityId: data["communityId"] as? String
        )
    }

    private func makeQTContent(
        from remote: RemoteDailyQuietTime,
        date: Date,
        source: QTContentSource,
        community: Community?
    ) -> QTContent? {
        let startVerseId = remote.startVerseId ?? remote.verseId
        let endVerseId = remote.endVerseId ?? startVerseId
        let rangeVerses = bibleService.getVerseRange(startId: startVerseId, endId: endVerseId)
        let fallbackVerse = bibleService.getVerse(id: remote.verseId)
            ?? bibleService.getVerse(reference: remote.reference)
        let resolvedVerses = rangeVerses.isEmpty ? fallbackVerse.map { [$0] } ?? [] : rangeVerses

        guard let firstVerse = resolvedVerses.first,
              let lastVerse = resolvedVerses.last else {
            return nil
        }

        let verseLines = resolvedVerses.map { verse in
            QTVerseLine(id: verse.id, verseNumber: verse.verse, text: verse.text)
        }
        let verseText = resolvedVerses.map(\.text).joined(separator: "\n")

        return QTContent(
            id: remote.dateKey,
            date: DailyQuietTimeDateKeyProvider(
                timeZoneIdentifier: remote.timezone
            ).startOfDay(for: date),
            verseId: firstVerse.id,
            startVerseId: firstVerse.id,
            endVerseId: lastVerse.id,
            reference: remote.reference,
            verseText: verseText,
            verseLines: verseLines,
            title: remote.title,
            devotionalText: remote.devotionalText,
            reflectionQuestions: remote.questions.map(\.prompt),
            reflectionPrompt: remote.reflectionPrompt,
            applicationPrompt: remote.applicationPrompt,
            prayerPrompt: remote.prayerPrompt,
            contentId: remote.dateKey,
            contentDateKey: remote.dateKey,
            contentVersion: remote.version,
            source: source,
            communityId: community?.id,
            communityName: community?.name
        )
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        return (value as? NSNumber)?.intValue
    }
}
