import type { BibleVerse } from "@/features/bible/bibleTypes";

export type WritingSourceType = "direct" | "theme" | "customList" | "plan";
export type PlanStatus = "active" | "paused" | "completed" | "cancelled";
export type PlanAssignmentState = "pending" | "completed" | "missed";

export type WritingRecord = {
  id: string;
  localId: string;
  date: Date;
  verseId: string;
  book: string;
  chapter: number;
  verse: number;
  originalText: string;
  userText: string;
  completedAt: Date;
  sourceType?: WritingSourceType;
  planId?: string;
  assignmentId?: string;
  planDayIndex?: number;
};

export type WritingPlan = {
  id: string;
  localId: string;
  title: string;
  book: string;
  startChapter: number;
  endChapter: number;
  startVerse?: number;
  endVerse?: number;
  startDate: Date;
  endDate: Date;
  totalDays: number;
  totalVerses: number;
  completedDays: number;
  status: PlanStatus;
  createdAt: Date;
  updatedAt: Date;
};

export type PlanAssignment = {
  id: string;
  localId: string;
  planId: string;
  planLocalId: string;
  dayIndex: number;
  date: Date;
  book: string;
  startChapter: number;
  startVerse: number;
  endChapter: number;
  endVerse: number;
  verseCount: number;
  state: PlanAssignmentState;
  completedAt: Date | null;
  completionRecordIds: string[];
  createdAt: Date;
  updatedAt: Date;
};

export type PlanPreview = {
  title: string;
  book: string;
  startChapter: number;
  endChapter: number;
  startDate: Date;
  endDate: Date;
  totalDays: number;
  totalVerses: number;
  assignments: Omit<PlanAssignment, "id" | "localId" | "planId" | "planLocalId" | "state" | "completedAt" | "completionRecordIds" | "createdAt" | "updatedAt">[];
};

export type PlanWritingContext = { plan: WritingPlan; assignment: PlanAssignment; verses: readonly BibleVerse[]; currentIndex: number };
