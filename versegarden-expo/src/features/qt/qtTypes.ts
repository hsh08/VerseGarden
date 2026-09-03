import type { BibleVerse } from "@/features/bible/bibleTypes";

export type QTContentSource = "local" | "global" | "community";

export type QTContent = {
  id: string;
  dateKey: string;
  date: Date;
  verseId?: string;
  startVerseId?: string;
  endVerseId?: string;
  reference: string;
  verseText: string;
  verseLines: readonly BibleVerse[];
  title: string;
  devotionalText: string;
  reflectionPrompt: string;
  applicationPrompt: string;
  prayerPrompt: string;
  contentId?: string;
  contentDateKey?: string;
  contentVersion?: number;
  source: QTContentSource;
  communityId?: string;
  communityName?: string;
};

export type QTContentPreview = Pick<QTContent, "dateKey" | "title" | "devotionalText" | "source" | "communityId" | "communityName">;

export type QTRecord = {
  id: string;
  dateKey: string;
  date: Date;
  verseId?: string;
  startVerseId?: string;
  endVerseId?: string;
  reference: string;
  verseText: string;
  contentId?: string;
  contentDateKey?: string;
  contentVersion?: number;
  contentSource?: QTContentSource;
  communityId?: string;
  reflectionAnswer: string;
  applicationText: string;
  prayerText: string;
  completedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

export function hasQTDraft(record: QTRecord | null | undefined): boolean {
  if (!record) return false;
  return [record.reflectionAnswer, record.applicationText, record.prayerText].some((value) => value.trim().length > 0);
}

export function isQTComplete(record: QTRecord | null | undefined): boolean {
  return Boolean(record?.completedAt);
}

export function dateKeyFor(value = new Date(), timeZone = "Asia/Seoul"): string {
  const formatter = new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" });
  const parts = Object.fromEntries(formatter.formatToParts(value).filter((part) => part.type !== "literal").map((part) => [part.type, part.value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
}

export function dateForKey(dateKey: string): Date {
  return new Date(`${dateKey}T00:00:00+09:00`);
}
