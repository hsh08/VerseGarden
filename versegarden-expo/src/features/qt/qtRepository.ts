import { collection, doc, getDoc, onSnapshot, serverTimestamp, setDoc, Timestamp } from "firebase/firestore";

import type { BibleRepository } from "@/features/bible/bibleRepository";
import type { CommunityMembership } from "@/features/community/communityTypes";
import { createVerseReference } from "@/features/bible/bibleTypes";
import { firestoreDate, requireCurrentUserID, requireFirestore } from "@/features/shared/firestore";

import { dateForKey, dateKeyFor, type QTContent, type QTContentPreview, type QTContentSource, type QTRecord } from "./qtTypes";

function recordsCollection() { return collection(requireFirestore(), "users", requireCurrentUserID(), "qtRecords"); }

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() ? value : undefined;
}

function source(value: unknown): QTContentSource | undefined {
  return value === "local" || value === "global" || value === "community" ? value : undefined;
}

function recordFromDocument(id: string, value: Record<string, unknown>): QTRecord | null {
  const date = firestoreDate(value.date);
  if (!date) return null;
  const createdAt = firestoreDate(value.createdAt, date);
  const completedAt = firestoreDate(value.completedAt);
  const updatedAt = firestoreDate(value.updatedAt, completedAt ?? createdAt);
  if (!createdAt || !updatedAt) return null;
  const dateKey = optionalString(value.dateKey) ?? dateKeyFor(date);
  return {
    id: optionalString(value.recordId) ?? optionalString(value.qtId) ?? id,
    dateKey,
    date,
    verseId: optionalString(value.verseId),
    startVerseId: optionalString(value.startVerseId),
    endVerseId: optionalString(value.endVerseId),
    reference: typeof value.reference === "string" ? value.reference : "오늘의 말씀",
    verseText: typeof value.verseText === "string" ? value.verseText : "",
    contentId: optionalString(value.contentId),
    contentDateKey: optionalString(value.contentDateKey),
    contentVersion: typeof value.contentVersion === "number" ? value.contentVersion : undefined,
    contentSource: source(value.contentSource),
    communityId: optionalString(value.communityId),
    reflectionAnswer: typeof value.reflectionAnswer === "string" ? value.reflectionAnswer : Array.isArray(value.reflectionAnswers) ? value.reflectionAnswers.filter((item): item is string => typeof item === "string").join("\n") : "",
    applicationText: typeof value.applicationText === "string" ? value.applicationText : "",
    prayerText: typeof value.prayerText === "string" ? value.prayerText : "",
    completedAt,
    createdAt,
    updatedAt,
  };
}

function contentFromRemote(dateKey: string, value: Record<string, unknown>, repository: BibleRepository, source: QTContentSource, community?: CommunityMembership): QTContent | null {
  if (value.status !== "published" || value.dateKey !== dateKey || typeof value.timezone !== "string" || typeof value.translation !== "string" || typeof value.verseId !== "string" || typeof value.reference !== "string" || typeof value.title !== "string" || typeof value.devotionalText !== "string" || typeof value.reflectionPrompt !== "string" || typeof value.applicationPrompt !== "string" || typeof value.prayerPrompt !== "string" || typeof value.version !== "number") return null;
  if (source === "community" && (!community || value.communityId !== community.communityId)) return null;
  const startVerseId = optionalString(value.startVerseId) ?? value.verseId;
  const endVerseId = optionalString(value.endVerseId) ?? startVerseId;
  const start = repository.getVerse(startVerseId);
  const end = repository.getVerse(endVerseId);
  if (!start || !end) return null;
  const books = repository.getBooks();
  const startBookIndex = books.findIndex((book) => book.name === start.book);
  const endBookIndex = books.findIndex((book) => book.name === end.book);
  if (startBookIndex < 0 || endBookIndex < startBookIndex) return null;
  const verseLines = books.slice(startBookIndex, endBookIndex + 1).flatMap((book) => book.chapters.flatMap((chapter) => repository.getVerses(book.name, chapter).filter((verse) => {
    if (book.name === start.book && (chapter < start.chapter || (chapter === start.chapter && verse.verse < start.verse))) return false;
    if (book.name === end.book && (chapter > end.chapter || (chapter === end.chapter && verse.verse > end.verse))) return false;
    return true;
  })));
  const resolved = verseLines.length ? verseLines : [start];
  return { id: dateKey, dateKey, date: dateForKey(dateKey), verseId: resolved[0].id, startVerseId: resolved[0].id, endVerseId: resolved.at(-1)?.id, reference: value.reference, verseText: resolved.map((verse) => verse.text).join("\n"), verseLines: resolved, title: value.title, devotionalText: value.devotionalText, reflectionPrompt: value.reflectionPrompt, applicationPrompt: value.applicationPrompt, prayerPrompt: value.prayerPrompt, contentId: dateKey, contentDateKey: dateKey, contentVersion: value.version, source, ...(community ? { communityId: community.communityId, communityName: community.communityName } : {}) };
}

function previewFromRemote(dateKey: string, value: Record<string, unknown>, source: QTContentSource, community?: CommunityMembership): QTContentPreview | null {
  if (value.status !== "published" || value.dateKey !== dateKey || typeof value.title !== "string" || typeof value.devotionalText !== "string") return null;
  if (source === "community" && (!community || value.communityId !== community.communityId)) return null;
  return { dateKey, title: value.title, devotionalText: value.devotionalText, source, ...(community ? { communityId: community.communityId, communityName: community.communityName } : {}) };
}

function localContent(repository: BibleRepository, date = new Date()): QTContent {
  const books = repository.getBooks();
  const firstBook = books[Math.abs(Number(dateKeyFor(date).replaceAll("-", ""))) % books.length];
  const verse = repository.getVerses(firstBook.name, firstBook.chapters[0])[0];
  if (!verse) throw new Error("local-verse-unavailable");
  const dateKey = dateKeyFor(date);
  return { id: dateKey, dateKey, date: dateForKey(dateKey), verseId: verse.id, startVerseId: verse.id, endVerseId: verse.id, reference: createVerseReference(verse), verseText: verse.text, verseLines: [verse], title: "오늘의 QT", devotionalText: "천천히 읽고 오늘의 마음과 실천을 짧게 남겨보세요.", reflectionPrompt: "오늘 마음에 남은 말씀", applicationPrompt: "오늘 내가 심을 작은 행동", prayerPrompt: "오늘의 기도", source: "local" };
}

export const qtRepository = {
  subscribe(onValue: (records: QTRecord[]) => void, onError: (error: unknown) => void) {
    return onSnapshot(recordsCollection(), (snapshot) => {
      const deduped = new Map<string, QTRecord>();
      snapshot.docs.forEach((item) => {
        const record = recordFromDocument(item.id, item.data());
        if (!record) return;
        const current = deduped.get(record.dateKey);
        if (!current || record.updatedAt >= current.updatedAt) deduped.set(record.dateKey, record);
      });
      onValue([...deduped.values()].sort((left, right) => right.date.getTime() - left.date.getTime()));
    }, onError);
  },
  async resolveToday(repository: BibleRepository, date = new Date(), community?: CommunityMembership | null): Promise<QTContent> {
    if (community?.communityStatus === "active" && community.membershipStatus === "active") {
      const communityDateKey = dateKeyFor(date, community.timezone);
      try {
        const remote = await getDoc(doc(requireFirestore(), "communities", community.communityId, "dailyQuietTimes", communityDateKey));
        if (remote.exists()) {
          const content = contentFromRemote(communityDateKey, remote.data(), repository, "community", community);
          if (content) return content;
        }
      } catch {
        // A denied or unavailable Community QT must not block the global/local fallback.
      }
    }
    const dateKey = dateKeyFor(date);
    try {
      const remote = await getDoc(doc(requireFirestore(), "dailyQuietTimes", dateKey));
      if (remote.exists()) {
        const content = contentFromRemote(dateKey, remote.data(), repository, "global");
        if (content) return content;
      }
    } catch {
      // The bundled Bible fallback keeps today's QT usable when remote content is unavailable.
    }
    return localContent(repository, date);
  },
  async resolveTodayPreview(date = new Date(), community?: CommunityMembership | null): Promise<QTContentPreview> {
    if (community?.communityStatus === "active" && community.membershipStatus === "active") {
      const communityDateKey = dateKeyFor(date, community.timezone);
      try {
        const remote = await getDoc(doc(requireFirestore(), "communities", community.communityId, "dailyQuietTimes", communityDateKey));
        if (remote.exists()) {
          const content = previewFromRemote(communityDateKey, remote.data(), "community", community);
          if (content) return content;
        }
      } catch {
        // Home metadata follows the same non-blocking Community -> global -> local fallback as the QT screen.
      }
    }
    const dateKey = dateKeyFor(date);
    try {
      const remote = await getDoc(doc(requireFirestore(), "dailyQuietTimes", dateKey));
      if (remote.exists()) {
        const content = previewFromRemote(dateKey, remote.data(), "global");
        if (content) return content;
      }
    } catch {
      // The local preview remains available when remote metadata cannot be read.
    }
    return { dateKey, title: "오늘의 QT", devotionalText: "말씀을 읽고 묵상과 기도를 남겨보세요.", source: "local" };
  },
  async save(content: QTContent, input: Pick<QTRecord, "reflectionAnswer" | "applicationText" | "prayerText">, completed: boolean): Promise<QTRecord> {
    const now = new Date();
    const id = `qt-${content.contentDateKey ?? content.dateKey}`;
    const reference = doc(recordsCollection(), id);
    const existing = await getDoc(reference);
    const createdAt = firestoreDate(existing.data()?.createdAt, now) ?? now;
    const existingCompletedAt = firestoreDate(existing.data()?.completedAt);
    await setDoc(reference, {
      recordId: id, qtId: id, dateKey: content.contentDateKey ?? content.dateKey, date: Timestamp.fromDate(content.date), verseId: content.verseId ?? null, startVerseId: content.startVerseId ?? null, endVerseId: content.endVerseId ?? null, reference: content.reference, verseText: content.verseText, contentId: content.contentId ?? null, contentDateKey: content.contentDateKey ?? null, contentVersion: content.contentVersion ?? null, contentSource: content.source, communityId: content.communityId ?? null, reflectionAnswer: input.reflectionAnswer, reflectionAnswers: input.reflectionAnswer.trim() ? [input.reflectionAnswer] : [], applicationText: input.applicationText, prayerText: input.prayerText, createdAt: Timestamp.fromDate(createdAt), updatedAt: Timestamp.fromDate(now), lastSyncedAt: serverTimestamp(), ...(completed ? { completedAt: Timestamp.fromDate(existingCompletedAt ?? now) } : {}),
    }, { merge: true });
    const completedAt = completed ? existingCompletedAt ?? now : existingCompletedAt ?? null;
    return {
      id, dateKey: content.contentDateKey ?? content.dateKey, date: content.date, verseId: content.verseId,
      startVerseId: content.startVerseId, endVerseId: content.endVerseId, reference: content.reference,
      verseText: content.verseText, contentId: content.contentId, contentDateKey: content.contentDateKey,
      contentVersion: content.contentVersion, contentSource: content.source, communityId: content.communityId,
      reflectionAnswer: input.reflectionAnswer, applicationText: input.applicationText, prayerText: input.prayerText,
      completedAt, createdAt, updatedAt: now,
    };
  },
};
