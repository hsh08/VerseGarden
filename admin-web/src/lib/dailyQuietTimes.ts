import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  updateDoc,
  where
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import {
  findVerseById,
  getVerseRange,
  isValidSameChapterRange,
  referenceForRange
} from "@/lib/bible";
import { isValidDateKey, todayDateKey, weekDateRange } from "@/lib/date";
import type {
  DailyQuietTime,
  DailyQuietTimeContentSnapshot,
  DailyQuietTimeFormState,
  DailyQuietTimeQuestion,
  DailyQuietTimeScope,
  DailyQuietTimeStatus
} from "@/types/dailyQuietTime";

const COLLECTION_NAME = "dailyQuietTimes";
const CONTENT_FIELDS: Array<keyof DailyQuietTimeContentSnapshot> = [
  "title",
  "verseId",
  "startVerseId",
  "endVerseId",
  "reference",
  "devotionalText",
  "reflectionPrompt",
  "applicationPrompt",
  "prayerPrompt",
  "questions"
];

export function dailyQuietTimeDoc(dateKey: string, scope?: DailyQuietTimeScope) {
  return scope
    ? doc(db, "communities", scope.communityId, COLLECTION_NAME, dateKey)
    : doc(db, COLLECTION_NAME, dateKey);
}

export async function getDailyQuietTime(
  dateKey: string,
  scope?: DailyQuietTimeScope
): Promise<DailyQuietTime | null> {
  const snapshot = await getDoc(dailyQuietTimeDoc(dateKey, scope));
  if (!snapshot.exists()) {
    return null;
  }
  return snapshot.data() as DailyQuietTime;
}

export async function listDailyQuietTimes(scope?: DailyQuietTimeScope) {
  const base = scope
    ? collection(db, "communities", scope.communityId, COLLECTION_NAME)
    : collection(db, COLLECTION_NAME);
  const snapshot = await getDocs(query(base, orderBy("dateKey", "desc"), limit(120)));
  return snapshot.docs.map((item) => item.data() as DailyQuietTime);
}

export async function getDashboardSummary() {
  const today = todayDateKey();
  const todayContent = await getDailyQuietTime(today);
  const range = weekDateRange(today);
  const weeklySnapshot = await getDocs(
    query(
      collection(db, COLLECTION_NAME),
      where("dateKey", ">=", range.start),
      where("dateKey", "<=", range.end),
      orderBy("dateKey", "desc")
    )
  );
  const weeklyItems = weeklySnapshot.docs.map((item) => item.data() as DailyQuietTime);

  return {
    today,
    todayContent,
    weeklyCount: weeklyItems.length,
    weeklyPublishedCount: weeklyItems.filter((item) => item.status === "published").length
  };
}

export function createEmptyFormState(dateKey = todayDateKey()): DailyQuietTimeFormState {
  return {
    dateKey,
    title: "",
    verseId: "",
    startVerseId: "",
    endVerseId: "",
    reference: "",
    verseText: "",
    verseLines: [],
    devotionalText: "",
    reflectionPrompt: "",
    applicationPrompt: "",
    prayerPrompt: "",
    questions: [],
    status: "draft"
  };
}

export function formStateFromContent(
  content: DailyQuietTime
): DailyQuietTimeFormState {
  const startVerseId = content.startVerseId || content.verseId;
  const endVerseId = content.endVerseId || startVerseId;
  const rangeVerses = getVerseRange(startVerseId, endVerseId);
  const fallbackVerse = findVerseById(content.verseId);
  const verseLines = rangeVerses.length
    ? rangeVerses.map((verse) => ({ verse: verse.verse, text: verse.text }))
    : fallbackVerse
      ? [{ verse: fallbackVerse.verse, text: fallbackVerse.text }]
      : [];

  return {
    dateKey: content.dateKey,
    title: content.title,
    verseId: content.verseId || startVerseId,
    startVerseId,
    endVerseId,
    reference: content.reference,
    verseText: verseLines.map((line) => line.text).join("\n"),
    verseLines,
    devotionalText: content.devotionalText,
    reflectionPrompt: content.reflectionPrompt,
    applicationPrompt: content.applicationPrompt,
    prayerPrompt: content.prayerPrompt,
    questions: content.questions ?? [],
    status: content.status
  };
}

export function validateDailyQuietTimeForm(form: DailyQuietTimeFormState, forPublish = false) {
  const errors: string[] = [];
  if (!isValidDateKey(form.dateKey)) {
    errors.push("날짜는 YYYY-MM-DD 형식이어야 합니다.");
  }
  if (!form.title.trim()) {
    errors.push("제목을 입력해주세요.");
  }
  if (!form.startVerseId.trim() || !form.endVerseId.trim() || !form.reference.trim()) {
    errors.push("성경 본문 범위를 선택해주세요.");
  } else if (!isValidSameChapterRange(form.startVerseId, form.endVerseId)) {
    errors.push("성경 본문 범위는 같은 장 안에서 시작 절이 끝 절보다 앞서야 합니다.");
  }

  if (forPublish) {
    if (!form.devotionalText.trim()) errors.push("묵상 글을 입력해주세요.");
    if (!form.reflectionPrompt.trim()) errors.push("묵상 질문을 입력해주세요.");
    if (!form.applicationPrompt.trim()) errors.push("적용 질문을 입력해주세요.");
    if (!form.prayerPrompt.trim()) errors.push("기도 질문을 입력해주세요.");
  }

  return errors;
}

export function hasContentChanged(
  current: DailyQuietTime,
  nextForm: DailyQuietTimeFormState
): boolean {
  const currentSnapshot = contentSnapshotFromContent(current);
  const nextSnapshot = contentSnapshotFromForm(nextForm);

  return CONTENT_FIELDS.some((field) => {
    return JSON.stringify(currentSnapshot[field]) !== JSON.stringify(nextSnapshot[field]);
  });
}

export async function createDailyQuietTime(
  form: DailyQuietTimeFormState,
  adminUid: string,
  scope?: DailyQuietTimeScope
) {
  assertValidForStatus(form, form.status);
  assertCommunityIsWritable(scope);

  const reference = dailyQuietTimeDoc(form.dateKey, scope);

  const data = {
    dateKey: form.dateKey,
    timezone: scope?.timezone ?? "Asia/Seoul",
    ...(scope ? { communityId: scope.communityId } : {}),
    title: form.title.trim(),
    verseId: primaryVerseId(form),
    startVerseId: form.startVerseId,
    endVerseId: form.endVerseId,
    reference: normalizedReference(form),
    translation: "KRV",
    devotionalText: form.devotionalText.trim(),
    reflectionPrompt: form.reflectionPrompt.trim(),
    applicationPrompt: form.applicationPrompt.trim(),
    prayerPrompt: form.prayerPrompt.trim(),
    questions: [],
    status: form.status,
    version: 1,
    createdBy: adminUid,
    updatedBy: adminUid,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };

  await runTransaction(db, async (transaction) => {
    const existing = await transaction.get(reference);
    if (existing.exists()) {
      throw new Error("해당 날짜의 QT가 이미 존재합니다.");
    }
    transaction.set(reference, data);
  });
}

export async function updateDailyQuietTime(
  current: DailyQuietTime,
  form: DailyQuietTimeFormState,
  adminUid: string,
  statusOverride?: DailyQuietTimeStatus,
  scope?: DailyQuietTimeScope
) {
  assertCommunityIsWritable(scope);
  const nextStatus = statusOverride ?? form.status;
  assertValidForStatus(form, nextStatus);

  const contentChanged = hasContentChanged(current, form);
  const nextVersion = current.version + (contentChanged ? 1 : 0);
  const data = {
    title: form.title.trim(),
    verseId: primaryVerseId(form),
    startVerseId: form.startVerseId,
    endVerseId: form.endVerseId,
    reference: normalizedReference(form),
    translation: "KRV",
    devotionalText: form.devotionalText.trim(),
    reflectionPrompt: form.reflectionPrompt.trim(),
    applicationPrompt: form.applicationPrompt.trim(),
    prayerPrompt: form.prayerPrompt.trim(),
    questions: [],
    status: nextStatus,
    version: nextVersion,
    updatedBy: adminUid,
    updatedAt: serverTimestamp(),
    ...(nextStatus === "published" && current.status !== "published"
      ? { publishedAt: serverTimestamp() }
      : {}),
    ...(nextStatus === "archived" && current.status !== "archived"
      ? { archivedAt: serverTimestamp() }
      : {})
  };

  await updateDoc(dailyQuietTimeDoc(current.dateKey, scope), data);
}

function assertCommunityIsWritable(scope?: DailyQuietTimeScope) {
  if (scope && scope.communityStatus !== "active") {
    throw new Error("비활성 또는 보관된 공동체의 QT는 수정할 수 없습니다.");
  }
}

function assertValidForStatus(
  form: DailyQuietTimeFormState,
  status: DailyQuietTimeStatus
) {
  const requiresFullValidation = status === "published" || status === "archived";
  const errors = validateDailyQuietTimeForm(form, requiresFullValidation);
  if (errors.length) {
    throw new Error(errors[0]);
  }
}

function contentSnapshotFromContent(content: DailyQuietTime): DailyQuietTimeContentSnapshot {
  return {
    title: content.title,
    verseId: content.verseId,
    startVerseId: content.startVerseId || content.verseId,
    endVerseId: content.endVerseId || content.startVerseId || content.verseId,
    reference: content.reference,
    devotionalText: content.devotionalText,
    reflectionPrompt: content.reflectionPrompt,
    applicationPrompt: content.applicationPrompt,
    prayerPrompt: content.prayerPrompt,
    questions: sanitizeQuestions(content.questions ?? [])
  };
}

function contentSnapshotFromForm(form: DailyQuietTimeFormState): DailyQuietTimeContentSnapshot {
  return {
    title: form.title.trim(),
    verseId: primaryVerseId(form),
    startVerseId: form.startVerseId,
    endVerseId: form.endVerseId,
    reference: normalizedReference(form),
    devotionalText: form.devotionalText.trim(),
    reflectionPrompt: form.reflectionPrompt.trim(),
    applicationPrompt: form.applicationPrompt.trim(),
    prayerPrompt: form.prayerPrompt.trim(),
    questions: []
  };
}

function sanitizeQuestions(questions: DailyQuietTimeQuestion[]): DailyQuietTimeQuestion[] {
  return questions.map((question, index) => ({
    id: question.id.trim() || `q${index + 1}`,
    type: question.type,
    prompt: question.prompt.trim()
  }));
}

function primaryVerseId(form: DailyQuietTimeFormState): string {
  return form.startVerseId || form.verseId;
}

function normalizedReference(form: DailyQuietTimeFormState): string {
  return referenceForRange(form.startVerseId, form.endVerseId) || form.reference;
}
