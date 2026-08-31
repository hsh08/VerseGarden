import type { BibleRepository } from "@/features/bible/bibleRepository";
import type { BibleVerse } from "@/features/bible/bibleTypes";

import type { PlanAssignment, PlanPreview, WritingPlan } from "./writingTypes";

export function buildPlanPreview(repository: BibleRepository, input: { book: string; startChapter: number; endChapter: number; startDate: Date; totalDays: number }): PlanPreview {
  if (input.startChapter > input.endChapter) throw new Error("invalid-chapter-range");
  const verses = Array.from({ length: input.endChapter - input.startChapter + 1 }, (_, index) => repository.getVerses(input.book, input.startChapter + index)).flat();
  if (!verses.length) throw new Error("empty-range");
  if (input.totalDays < 1 || input.totalDays > verses.length) throw new Error("invalid-duration");

  const dailyCounts = balancedCounts(verses.length, input.totalDays);
  const startDate = startOfDay(input.startDate);
  let cursor = 0;
  const assignments = dailyCounts.map((count, index) => {
    const dayVerses = verses.slice(cursor, cursor + count);
    cursor += count;
    const first = dayVerses[0];
    const last = dayVerses.at(-1);
    if (!first || !last) throw new Error("empty-range");
    return { dayIndex: index + 1, date: addDays(startDate, index), book: input.book, startChapter: first.chapter, startVerse: first.verse, endChapter: last.chapter, endVerse: last.verse, verseCount: dayVerses.length };
  });

  return { title: input.startChapter === input.endChapter ? `${input.book} ${input.startChapter}장 필사` : `${input.book} ${input.startChapter}–${input.endChapter}장 필사`, book: input.book, startChapter: input.startChapter, endChapter: input.endChapter, startDate, endDate: addDays(startDate, input.totalDays - 1), totalDays: input.totalDays, totalVerses: verses.length, assignments };
}

export function balancedCounts(totalVerses: number, totalDays: number): number[] {
  const base = Math.floor(totalVerses / totalDays);
  const remainder = totalVerses % totalDays;
  return Array.from({ length: totalDays }, (_, index) => index < remainder ? base + 1 : base);
}

export function assignmentVerses(repository: BibleRepository, assignment: PlanAssignment): readonly BibleVerse[] {
  return Array.from({ length: assignment.endChapter - assignment.startChapter + 1 }, (_, index) => repository.getVerses(assignment.book, assignment.startChapter + index).filter((verse) => {
    if (verse.chapter === assignment.startChapter) return verse.verse >= assignment.startVerse;
    if (verse.chapter === assignment.endChapter) return verse.verse <= assignment.endVerse;
    return true;
  })).flat();
}

export function todayAssignment(plan: WritingPlan, assignments: readonly PlanAssignment[], now = new Date()): PlanAssignment | null {
  const today = startOfDay(now).getTime();
  return assignments.find((assignment) => assignment.planId === plan.id && startOfDay(assignment.date).getTime() === today) ?? null;
}

export function nextIncompleteAssignment(plan: WritingPlan, assignments: readonly PlanAssignment[]): PlanAssignment | null {
  return assignments.filter((assignment) => assignment.planId === plan.id).sort((left, right) => left.dayIndex - right.dayIndex).find((assignment) => assignment.state !== "completed") ?? null;
}

export function progressForPlan(plan: WritingPlan, assignments: readonly PlanAssignment[]) {
  const items = assignments.filter((assignment) => assignment.planId === plan.id);
  const completed = items.filter((assignment) => assignment.state === "completed").length;
  return { completed, total: plan.totalDays, ratio: plan.totalDays ? completed / plan.totalDays : 0 };
}

export function deterministicPlanRecordID(planId: string, assignmentId: string, verseId: string): string {
  return ["plan", planId, "assignment", assignmentId, "verse", verseId].map((value) => value.replace(/[\/#?]/g, "_").trim()).join("_");
}

export function startOfDay(value: Date): Date {
  return new Date(value.getFullYear(), value.getMonth(), value.getDate());
}

export function addDays(value: Date, amount: number): Date {
  const next = new Date(value);
  next.setDate(next.getDate() + amount);
  return next;
}
