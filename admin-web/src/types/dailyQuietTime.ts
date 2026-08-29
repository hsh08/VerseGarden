import type { Timestamp } from "firebase/firestore";

export type DailyQuietTimeStatus = "draft" | "published" | "archived";
export type DailyQuietTimeQuestionType = "reflection" | "application";

export type DailyQuietTimeQuestion = {
  id: string;
  type: DailyQuietTimeQuestionType;
  prompt: string;
};

export type DailyQuietTime = {
  dateKey: string;
  timezone: string;
  title: string;
  verseId: string;
  startVerseId?: string;
  endVerseId?: string;
  reference: string;
  translation: string;
  devotionalText: string;
  reflectionPrompt: string;
  applicationPrompt: string;
  prayerPrompt: string;
  questions: DailyQuietTimeQuestion[];
  status: DailyQuietTimeStatus;
  version: number;
  createdBy: string;
  updatedBy: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  publishedAt?: Timestamp;
  archivedAt?: Timestamp;
};

export type CommunityDailyQuietTime = DailyQuietTime & {
  communityId: string;
};

export type DailyQuietTimeScope = {
  communityId: string;
  communityName: string;
  communityStatus: "active" | "inactive" | "archived";
  timezone: string;
};

export type DailyQuietTimeFormState = {
  dateKey: string;
  title: string;
  verseId: string;
  startVerseId: string;
  endVerseId: string;
  reference: string;
  verseText: string;
  verseLines: Array<{ verse: number; text: string }>;
  devotionalText: string;
  reflectionPrompt: string;
  applicationPrompt: string;
  prayerPrompt: string;
  questions: DailyQuietTimeQuestion[];
  status: DailyQuietTimeStatus;
};

export type DailyQuietTimeContentSnapshot = Pick<
  DailyQuietTimeFormState,
  | "title"
  | "verseId"
  | "startVerseId"
  | "endVerseId"
  | "reference"
  | "devotionalText"
  | "reflectionPrompt"
  | "applicationPrompt"
  | "prayerPrompt"
  | "questions"
>;
