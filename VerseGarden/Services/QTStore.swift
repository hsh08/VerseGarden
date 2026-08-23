import Combine
import Foundation

final class QTStore: ObservableObject {
    @Published private(set) var records: [QTRecord] = []
    var onRecordChanged: ((QTRecord) -> Void)?

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let baseStorageKey = "versegarden_qt_records"
    private var activeUserID: String?
    private var isApplyingSync = false

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        loadRecords()
    }

    func setActiveUserID(_ userID: String?) {
        guard activeUserID != userID else { return }
        activeUserID = userID
        loadRecords()
    }

    func record(on date: Date = Date()) -> QTRecord? {
        let dateKey = QTRecord.dateKey(for: date, calendar: calendar)
        return record(dateKey: dateKey)
    }

    func record(dateKey: String) -> QTRecord? {
        return records.first { $0.dateKey == dateKey }
    }

    func record(for content: QTContent) -> QTRecord {
        let dateKey = content.contentDateKey ?? content.id
        if let existing = record(dateKey: dateKey) {
            guard shouldRefresh(existing, with: content) else {
                return existing
            }

            let refreshedRecord = refreshed(existing, with: content)
            upsert(refreshedRecord)
            return refreshedRecord
        }

        let newRecord = QTRecord(content: content, calendar: calendar)
        records.insert(newRecord, at: 0)
        persistRecords()
        return newRecord
    }

    func isCompleted(on date: Date = Date()) -> Bool {
        record(on: date)?.isCompleted == true
    }

    func isCompleted(dateKey: String) -> Bool {
        record(dateKey: dateKey)?.isCompleted == true
    }

    func hasDraft(on date: Date = Date()) -> Bool {
        guard let record = record(on: date) else { return false }
        return record.hasDraft && !record.isCompleted
    }

    func hasDraft(dateKey: String) -> Bool {
        guard let record = record(dateKey: dateKey) else { return false }
        return record.hasDraft && !record.isCompleted
    }

    @discardableResult
    func saveDraft(
        for content: QTContent,
        reflectionAnswer: String,
        applicationText: String,
        prayerText: String
    ) -> QTRecord {
        var record = self.record(for: content)
        record.reflectionAnswer = reflectionAnswer
        record.applicationText = applicationText
        record.prayerText = prayerText
        record.updatedAt = Date()
        upsert(record)
        return record
    }

    @discardableResult
    func complete(
        content: QTContent,
        reflectionAnswer: String,
        applicationText: String,
        prayerText: String
    ) -> QTRecord {
        var record = saveDraft(
            for: content,
            reflectionAnswer: reflectionAnswer,
            applicationText: applicationText,
            prayerText: prayerText
        )

        if record.completedAt == nil {
            record.completedAt = Date()
        }
        record.updatedAt = Date()
        upsert(record)
        return record
    }

    func mergeRecordsFromSync(_ remoteRecords: [QTRecord]) {
        isApplyingSync = true

        var recordsById = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for remoteRecord in remoteRecords {
            if let localRecord = recordsById[remoteRecord.id] {
                recordsById[remoteRecord.id] = newestRecord(localRecord, remoteRecord)
            } else if let sameDateCompleted = recordsById.values.first(where: { local in
                local.dateKey == remoteRecord.dateKey
                    && local.isCompleted
                    && remoteRecord.isCompleted
            }) {
                recordsById[sameDateCompleted.id] = newestRecord(sameDateCompleted, remoteRecord)
            } else {
                recordsById[remoteRecord.id] = remoteRecord
            }
        }

        records = Array(recordsById.values)
            .sorted { $0.date > $1.date }
        persistRecords()

        isApplyingSync = false
    }

    private func upsert(_ record: QTRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.insert(record, at: 0)
        }
        records.sort { $0.date > $1.date }
        persistRecords()
        notifyRecordChanged(record)
    }

    private func shouldRefresh(_ record: QTRecord, with content: QTContent) -> Bool {
        guard !record.isCompleted else { return false }
        return record.verseId != content.verseId
            || record.startVerseId != content.startVerseId
            || record.endVerseId != content.endVerseId
            || record.reference != content.reference
            || record.verseText != content.verseText
            || record.contentId != content.contentId
            || record.contentDateKey != content.contentDateKey
            || record.contentVersion != content.contentVersion
    }

    private func refreshed(_ record: QTRecord, with content: QTContent) -> QTRecord {
        QTRecord(
            id: record.id,
            dateKey: record.dateKey,
            date: record.date,
            verseId: content.verseId,
            startVerseId: content.startVerseId,
            endVerseId: content.endVerseId,
            reference: content.reference,
            verseText: content.verseText,
            contentId: content.contentId,
            contentDateKey: content.contentDateKey,
            contentVersion: content.contentVersion,
            reflectionAnswer: record.reflectionAnswer,
            applicationText: record.applicationText,
            prayerText: record.prayerText,
            completedAt: record.completedAt,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    private func newestRecord(_ lhs: QTRecord, _ rhs: QTRecord) -> QTRecord {
        let selected = lhs.updatedAt >= rhs.updatedAt ? lhs : rhs
        let fallback = selected.id == lhs.id ? rhs : lhs

        return QTRecord(
            id: selected.id,
            dateKey: selected.dateKey,
            date: selected.date,
            verseId: selected.verseId ?? fallback.verseId,
            startVerseId: selected.startVerseId ?? fallback.startVerseId,
            endVerseId: selected.endVerseId ?? fallback.endVerseId,
            reference: selected.reference.isEmpty ? fallback.reference : selected.reference,
            verseText: selected.verseText.isEmpty ? fallback.verseText : selected.verseText,
            contentId: selected.contentId ?? fallback.contentId,
            contentDateKey: selected.contentDateKey ?? fallback.contentDateKey,
            contentVersion: selected.contentVersion ?? fallback.contentVersion,
            reflectionAnswer: selected.reflectionAnswer,
            applicationText: selected.applicationText,
            prayerText: selected.prayerText,
            completedAt: selected.completedAt ?? fallback.completedAt,
            createdAt: min(selected.createdAt, fallback.createdAt),
            updatedAt: selected.updatedAt
        )
    }

    private func notifyRecordChanged(_ record: QTRecord) {
        guard !isApplyingSync else { return }
        onRecordChanged?(record)
    }

    private func loadRecords() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([QTRecord].self, from: data) else {
            records = []
            return
        }

        records = decoded.sorted { $0.date > $1.date }
    }

    private func persistRecords() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private var storageKey: String {
        guard let activeUserID, !activeUserID.isEmpty else {
            return baseStorageKey
        }
        return "\(baseStorageKey)_\(activeUserID)"
    }
}
