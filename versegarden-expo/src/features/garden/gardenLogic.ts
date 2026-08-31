import type { LikedVerse } from "@/features/likes/likedVerseRepository";
import type { PrayerRecord } from "@/features/prayer/prayerTypes";
import { dateForKey, dateKeyFor, type QTRecord } from "@/features/qt/qtTypes";
import type { WritingRecord } from "@/features/writing/writingTypes";

import { countsTowardGardenGrowth, gardenActivityLabels, type GardenActivity, type GardenDaySummary, type GardenStats } from "./gardenTypes";

export function gardenActivitiesFromSources(input: {
  likes: readonly LikedVerse[];
  writingRecords: readonly WritingRecord[];
  prayerRecords: readonly PrayerRecord[];
  qtRecords: readonly QTRecord[];
}): GardenActivity[] {
  const activities: GardenActivity[] = [];

  input.likes.forEach((record) => {
    if (!validDate(record.createdAt) || !record.verseId.trim()) return;
    activities.push({ id: `liked-${record.verseId}`, type: "verseLiked", title: gardenActivityLabels.verseLiked, verseId: record.verseId, sourceId: record.verseId, createdAt: record.createdAt });
  });

  input.writingRecords.forEach((record) => {
    if (!validDate(record.completedAt) || !record.id || !record.verseId.trim()) return;
    activities.push({ id: `writing-${record.id}`, type: "scriptureCopy", title: gardenActivityLabels.scriptureCopy, verseId: record.verseId, reference: `${record.book} ${record.chapter}:${record.verse}`, sourceId: record.id, createdAt: record.completedAt });
  });

  input.prayerRecords.forEach((record) => {
    if (!validDate(record.completedAt) || !record.id) return;
    activities.push({ id: `prayer-${record.id}`, type: "prayer", title: gardenActivityLabels.prayer, sourceId: record.id, createdAt: record.completedAt });
  });

  input.qtRecords.forEach((record) => {
    if (!record.completedAt || !validDate(record.completedAt) || !record.id) return;
    activities.push({ id: `qt-${record.id}`, type: "qtCompleted", title: gardenActivityLabels.qtCompleted, verseId: record.verseId, reference: record.reference, sourceId: record.id, createdAt: record.completedAt });
  });

  return deduplicateGardenActivities(activities);
}

export function deduplicateGardenActivities(activities: readonly GardenActivity[]): GardenActivity[] {
  const seenSources = new Set<string>();
  const seenQTDays = new Set<string>();
  const seenWritingKeys = new Set<string>();
  const seenLikeKeys = new Set<string>();

  return [...activities]
    .filter((activity) => validDate(activity.createdAt))
    .sort((left, right) => right.createdAt.getTime() - left.createdAt.getTime())
    .filter((activity) => {
      const dateKey = dateKeyFor(activity.createdAt);
      if (activity.type === "qtCompleted") {
        if (seenQTDays.has(dateKey)) return false;
        seenQTDays.add(dateKey);
      }
      if (activity.type === "scriptureCopy") {
        const identity = normalizedIdentity(activity.verseId ?? activity.reference ?? activity.title);
        const key = `${dateKey}|${identity}`;
        if (seenWritingKeys.has(key)) return false;
        seenWritingKeys.add(key);
      }
      if (activity.type === "verseLiked") {
        const identity = normalizedIdentity(activity.verseId ?? activity.reference ?? activity.title);
        if (seenLikeKeys.has(identity)) return false;
        seenLikeKeys.add(identity);
      }
      if (!activity.sourceId) return true;
      const key = `${activity.type}|${activity.sourceId}`;
      if (seenSources.has(key)) return false;
      seenSources.add(key);
      return true;
    });
}

export function summarizeGardenActivities(activities: readonly GardenActivity[], today = new Date()): GardenStats {
  const growth = activities.filter((activity) => countsTowardGardenGrowth(activity.type));
  const summaries = new Map<string, GardenDaySummary>();
  growth.forEach((activity) => {
    const dateKey = dateKeyFor(activity.createdAt);
    const current = summaries.get(dateKey) ?? emptyGardenDaySummary(dateKey);
    const next: GardenDaySummary = {
      ...current,
      verseLikedCount: current.verseLikedCount + Number(activity.type === "verseLiked"),
      scriptureCopyCount: current.scriptureCopyCount + Number(activity.type === "scriptureCopy"),
      prayerCount: current.prayerCount + Number(activity.type === "prayer"),
      qtCompletedCount: current.qtCompletedCount + Number(activity.type === "qtCompleted"),
      totalGrowthActivityCount: current.totalGrowthActivityCount + 1,
      hasGrowthActivity: true,
    };
    summaries.set(dateKey, next);
  });
  const todayKey = dateKeyFor(today);
  const summariesByDateKey = Object.fromEntries(summaries.entries());
  return {
    currentStreak: calculateCurrentStreak(summariesByDateKey, today),
    totalGrowthActivityCount: growth.length,
    today: summariesByDateKey[todayKey] ?? emptyGardenDaySummary(todayKey),
    summariesByDateKey,
    recentActivities: [...activities].sort((left, right) => right.createdAt.getTime() - left.createdAt.getTime()).slice(0, 12),
  };
}

export function emptyGardenDaySummary(dateKey: string): GardenDaySummary {
  return { dateKey, verseLikedCount: 0, scriptureCopyCount: 0, prayerCount: 0, qtCompletedCount: 0, totalGrowthActivityCount: 0, hasGrowthActivity: false };
}

export function calculateCurrentStreak(summaries: Readonly<Record<string, GardenDaySummary>>, today = new Date()): number {
  let cursor = dateForKey(dateKeyFor(today));
  if (!summaries[dateKeyFor(cursor)]?.hasGrowthActivity) {
    cursor = previousDate(cursor);
    if (!summaries[dateKeyFor(cursor)]?.hasGrowthActivity) return 0;
  }
  let streak = 0;
  while (summaries[dateKeyFor(cursor)]?.hasGrowthActivity) {
    streak += 1;
    cursor = previousDate(cursor);
  }
  return streak;
}

export function monthDateKeys(month: Date): string[] {
  const key = dateKeyFor(month);
  const [year, monthNumber] = key.split("-").map(Number);
  const first = dateForKey(`${year}-${String(monthNumber).padStart(2, "0")}-01`);
  const nextMonth = new Date(Date.UTC(year, monthNumber, 1));
  const days = new Date(nextMonth.getTime() - 24 * 60 * 60 * 1000).getUTCDate();
  return Array.from({ length: days }, (_, index) => dateKeyFor(new Date(first.getTime() + index * 24 * 60 * 60 * 1000)));
}

function previousDate(value: Date): Date {
  return new Date(value.getTime() - 24 * 60 * 60 * 1000);
}

function normalizedIdentity(value: string): string {
  return value.trim().replaceAll(" ", "").toLowerCase();
}

function validDate(value: unknown): value is Date {
  return value instanceof Date && Number.isFinite(value.getTime());
}
