import FirebaseAuth
import FirebaseFirestore
import Foundation

struct FirestoreQTRecordService {
    private var database: Firestore { Firestore.firestore() }

    func fetchRecords(for userID: String) async throws -> [QTRecord] {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            database
                .collection("users")
                .document(userID)
                .collection("qtRecords")
                .getDocuments { snapshot, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let snapshot {
                        continuation.resume(returning: snapshot)
                    } else {
                        continuation.resume(throwing: FirestoreSyncError.invalidSnapshot)
                    }
                }
        }

        return snapshot.documents.compactMap(makeRecord)
    }

    func upsert(_ record: QTRecord, for userID: String) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let document = database
            .collection("users")
            .document(userID)
            .collection("qtRecords")
            .document(record.id)

        var data: [String: Any] = [
            "recordId": record.id,
            "qtId": record.id,
            "dateKey": record.dateKey,
            "date": Timestamp(date: record.date),
            "reference": record.reference,
            "reflectionAnswer": record.reflectionAnswer,
            "reflectionAnswers": record.reflectionAnswer.isEmpty ? [] : [record.reflectionAnswer],
            "applicationText": record.applicationText,
            "prayerText": record.prayerText,
            "createdAt": Timestamp(date: record.createdAt),
            "updatedAt": Timestamp(date: record.updatedAt),
            "lastSyncedAt": FieldValue.serverTimestamp()
        ]

        if let verseId = record.verseId, !verseId.isEmpty {
            data["verseId"] = verseId
        }

        if let startVerseId = record.startVerseId, !startVerseId.isEmpty {
            data["startVerseId"] = startVerseId
        } else {
            data["startVerseId"] = FieldValue.delete()
        }

        if let endVerseId = record.endVerseId, !endVerseId.isEmpty {
            data["endVerseId"] = endVerseId
        } else {
            data["endVerseId"] = FieldValue.delete()
        }

        if let contentId = record.contentId, !contentId.isEmpty {
            data["contentId"] = contentId
        } else {
            data["contentId"] = FieldValue.delete()
        }

        if let contentDateKey = record.contentDateKey, !contentDateKey.isEmpty {
            data["contentDateKey"] = contentDateKey
        } else {
            data["contentDateKey"] = FieldValue.delete()
        }

        if let contentVersion = record.contentVersion {
            data["contentVersion"] = contentVersion
        } else {
            data["contentVersion"] = FieldValue.delete()
        }

        if let contentSource = record.contentSource {
            data["contentSource"] = contentSource.rawValue
        } else {
            data["contentSource"] = FieldValue.delete()
        }

        if let communityId = record.communityId, !communityId.isEmpty {
            data["communityId"] = communityId
        } else {
            data["communityId"] = FieldValue.delete()
        }

        if let completedAt = record.completedAt {
            data["completedAt"] = Timestamp(date: completedAt)
        } else {
            data["completedAt"] = FieldValue.delete()
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.setData(data, merge: true) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func makeRecord(from document: QueryDocumentSnapshot) -> QTRecord? {
        let data = document.data()
        guard let dateTimestamp = data["date"] as? Timestamp else { return nil }

        let id = (data["recordId"] as? String)
            ?? (data["qtId"] as? String)
            ?? document.documentID
        let date = dateTimestamp.dateValue()
        let dateKey = (data["dateKey"] as? String) ?? QTRecord.dateKey(for: date)
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? date
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
            ?? (data["completedAt"] as? Timestamp)?.dateValue()
            ?? createdAt

        let reflectionAnswer: String
        if let storedReflection = data["reflectionAnswer"] as? String {
            reflectionAnswer = storedReflection
        } else if let reflectionAnswers = data["reflectionAnswers"] as? [String] {
            reflectionAnswer = reflectionAnswers.first ?? ""
        } else {
            reflectionAnswer = ""
        }

        let verseId = data["verseId"] as? String
        let startVerseId = data["startVerseId"] as? String
        let endVerseId = data["endVerseId"] as? String
        let reference = (data["reference"] as? String) ?? "오늘의 QT"
        let verseText = resolvedVerseText(
            verseId: verseId,
            startVerseId: startVerseId,
            endVerseId: endVerseId,
            reference: reference
        )

        return QTRecord(
            id: id,
            dateKey: dateKey,
            date: date,
            verseId: verseId,
            startVerseId: startVerseId,
            endVerseId: endVerseId,
            reference: reference,
            verseText: verseText,
            contentId: data["contentId"] as? String,
            contentDateKey: data["contentDateKey"] as? String,
            contentVersion: intValue(data["contentVersion"]),
            contentSource: (data["contentSource"] as? String).flatMap(QTContentSource.init(rawValue:)),
            communityId: data["communityId"] as? String,
            reflectionAnswer: reflectionAnswer,
            applicationText: (data["applicationText"] as? String) ?? "",
            prayerText: (data["prayerText"] as? String) ?? "",
            completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func resolvedVerseText(
        verseId: String?,
        startVerseId: String?,
        endVerseId: String?,
        reference: String
    ) -> String {
        let service = BibleDataService.shared

        if let startVerseId,
           let endVerseId {
            let verses = service.getVerseRange(startId: startVerseId, endId: endVerseId)
            if !verses.isEmpty {
                return verses.map(\.text).joined(separator: "\n")
            }
        }

        if let verseId,
           !verseId.isEmpty,
           let verse = service.getVerse(id: verseId) {
            return verse.text
        }

        if let verse = service.getVerse(reference: reference) {
            return verse.text
        }

        return ""
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        return nil
    }
}
