"use client";

import { useRouter } from "next/navigation";
import { FormEvent, RefObject, useMemo, useRef, useState } from "react";
import { BibleVerseSelector } from "@/components/BibleVerseSelector";
import { DialogAction, FormDialog } from "@/components/FormDialog";
import { useGlobalLoading } from "@/components/GlobalLoadingProvider";
import { friendlyErrorMessage } from "@/components/PermissionError";
import { StatusBadge } from "@/components/StatusBadge";
import {
  createDailyQuietTime,
  createEmptyFormState,
  updateDailyQuietTime,
  validateDailyQuietTimeForm
} from "@/lib/dailyQuietTimes";
import { useAdminAuth } from "@/lib/auth";
import type {
  DailyQuietTime,
  DailyQuietTimeFormState,
  DailyQuietTimeScope
} from "@/types/dailyQuietTime";

type Props = {
  mode: "create" | "edit";
  initialContent?: DailyQuietTime;
  initialForm?: DailyQuietTimeFormState;
  scope?: DailyQuietTimeScope;
};

type FocusTarget =
  | "dateKey"
  | "title"
  | "bible"
  | "devotionalText"
  | "reflectionPrompt"
  | "applicationPrompt"
  | "prayerPrompt";

type DialogState = {
  title: string;
  message: string;
  tone?: "error" | "default";
  focusTarget?: FocusTarget;
  actions?: DialogAction[];
};

export function DailyQuietTimeForm({ mode, initialContent, initialForm, scope }: Props) {
  const router = useRouter();
  const { user } = useAdminAuth();
  const { withGlobalLoading } = useGlobalLoading();
  const [form, setForm] = useState<DailyQuietTimeFormState>(
    initialForm ?? createEmptyFormState()
  );
  const [isSaving, setIsSaving] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [dialog, setDialog] = useState<DialogState | null>(null);
  const isProtectedInitialStatus =
    mode === "edit" &&
    (initialContent?.status === "published" || initialContent?.status === "archived");
  const isLifecycleReadOnly = Boolean(scope && scope.communityStatus !== "active");
  const [isEditModeEnabled, setIsEditModeEnabled] = useState(!isProtectedInitialStatus);

  const dateKeyRef = useRef<HTMLInputElement>(null);
  const titleRef = useRef<HTMLInputElement>(null);
  const bibleSectionRef = useRef<HTMLDivElement>(null);
  const devotionalTextRef = useRef<HTMLTextAreaElement>(null);
  const reflectionPromptRef = useRef<HTMLTextAreaElement>(null);
  const applicationPromptRef = useRef<HTMLTextAreaElement>(null);
  const prayerPromptRef = useRef<HTMLTextAreaElement>(null);

  const publishErrors = useMemo(() => validateDailyQuietTimeForm(form, true), [form]);
  const baselineForm = useMemo(
    () => initialForm ?? createEmptyFormState(),
    [initialForm]
  );
  const hasFormChanges = useMemo(
    () => formSignature(form) !== formSignature(baselineForm),
    [form, baselineForm]
  );
  const isReadOnly = isLifecycleReadOnly || (isProtectedInitialStatus && !isEditModeEnabled);
  const isDirty = isReadOnly ? false : hasFormChanges;
  const needsFullValidationForSave =
    form.status === "published" || form.status === "archived";
  const saveErrors = useMemo(
    () => validateDailyQuietTimeForm(form, needsFullValidationForSave),
    [form, needsFullValidationForSave]
  );

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await save();
  }

  async function save(statusOverride?: "published" | "archived") {
    if (!user) return;
    if (isReadOnly && !statusOverride) return;

    if (mode === "edit" && !statusOverride && !isDirty) {
      setDialog({
        title: "변경된 내용이 없습니다",
        message: "저장할 변경사항이 없습니다.",
        tone: "default"
      });
      return;
    }

    const errors = validationErrorsForStatus(statusOverride);
    if (errors.length) {
      showValidationDialog(errors[0]);
      return;
    }

    if (statusOverride && isDirty) {
      setDialog({
        title: "저장하지 않은 변경사항이 있습니다",
        message: "현재 변경사항과 함께 상태를 변경할까요?",
        tone: "default",
        actions: [
          {
            label: "취소",
            variant: "secondary",
            onClick: () => setDialog(null)
          },
          {
            label: "계속",
            variant: "primary",
            onClick: () => {
              setDialog(null);
              showStatusConfirmation(statusOverride);
            }
          }
        ]
      });
      return;
    }

    if (statusOverride) {
      showStatusConfirmation(statusOverride);
      return;
    }

    await saveStatusChange();
  }

  async function saveStatusChange(statusOverride?: "published" | "archived") {
    if (!user) return;
    setIsSaving(true);
    setNotice(null);

    try {
      await withGlobalLoading(async () => {
        if (mode === "create") {
          await createDailyQuietTime(
            {
              ...form,
              status: statusOverride ?? form.status
            },
            user.uid,
            scope
          );
          showSuccessDialog("저장되었습니다", "QT 내용이 정상적으로 저장되었습니다.");
          return;
        }

        if (!initialContent) {
          throw new Error("수정할 QT 데이터를 찾지 못했습니다.");
        }

        await updateDailyQuietTime(initialContent, form, user.uid, statusOverride, scope);
        if (statusOverride === "published") {
          showSuccessDialog("게시되었습니다", "이 QT가 사용자에게 공개되었습니다.");
        } else if (statusOverride === "archived") {
          showSuccessDialog("보관되었습니다", "이 QT는 더 이상 사용자에게 공개되지 않습니다.");
        } else {
          showSuccessDialog("저장되었습니다", "QT 내용이 정상적으로 저장되었습니다.");
        }
      }, statusOverride === "published"
        ? "QT를 게시하는 중..."
        : statusOverride === "archived" ? "QT를 보관하는 중..." : "QT를 저장하는 중...");
    } catch (saveError) {
      showSaveErrorDialog(friendlyErrorMessage(saveError));
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <>
    <form className="editor-grid" onSubmit={(event) => void handleSubmit(event)}>
      <section className="editor-panel">
        <div className="section-heading">
          <div>
            <p className="eyebrow">{scope ? scope.communityName : "VerseGarden Global Daily QT"}</p>
            <h1>{mode === "create" ? "새 QT 작성" : "QT 편집"}</h1>
            {scope ? <p className="muted">Community Daily QT · {scope.timezone}</p> : null}
          </div>
          <StatusBadge status={form.status} />
        </div>

        {isLifecycleReadOnly ? (
          <div className="status-note">
            <p>
              현재 공동체는 {scope?.communityStatus} 상태입니다. 기존 QT는 조회할 수 있지만
              수정, 게시, 보관은 제한됩니다.
            </p>
          </div>
        ) : null}

        {isProtectedInitialStatus && !isLifecycleReadOnly ? (
          <div className="status-note">
            <div>
              <StatusBadge status={form.status} />
              <p>{statusDescription(form.status)}</p>
            </div>
            {isEditModeEnabled ? (
              <button
                className="button secondary"
                type="button"
                disabled={isSaving}
                onClick={cancelProtectedEdit}
              >
                수정 취소
              </button>
            ) : (
              <button
                className="button primary"
                type="button"
                disabled={isSaving}
                onClick={() => setIsEditModeEnabled(true)}
              >
                수정하기
              </button>
            )}
          </div>
        ) : null}

        {notice ? <div className="alert success">{notice}</div> : null}

        <div className="form-grid">
          <Field label="날짜" htmlFor="dateKey">
            <input
              ref={dateKeyRef}
              id="dateKey"
              className={`input ${isReadOnly ? "readonly" : ""}`}
              value={form.dateKey}
              disabled={mode === "edit" || isReadOnly}
              placeholder="YYYY-MM-DD"
              onChange={(event) => updateField("dateKey", event.target.value)}
            />
          </Field>

          <Field label="제목" htmlFor="title">
            <input
              ref={titleRef}
              id="title"
              className={`input ${isReadOnly ? "readonly" : ""}`}
              value={form.title}
              disabled={isReadOnly}
              placeholder="QT 제목"
              onChange={(event) => updateField("title", event.target.value)}
            />
          </Field>
        </div>

        <div ref={bibleSectionRef}>
          <BibleVerseSelector
            selectedStartVerseId={form.startVerseId}
            selectedEndVerseId={form.endVerseId}
            selectedReference={form.reference}
            selectedVerses={form.verseLines}
            disabled={isReadOnly}
            onSelectRange={(range) => {
              setForm((current) => ({
                ...current,
                verseId: range.startVerseId,
                startVerseId: range.startVerseId,
                endVerseId: range.endVerseId,
                reference: range.reference,
                verseText: range.verses.map((verse) => verse.text).join("\n"),
                verseLines: range.verses.map((verse) => ({
                  verse: verse.verse,
                  text: verse.text
                })),
                questions: []
              }));
            }}
          />
        </div>

        <Field label="묵상 글" htmlFor="devotionalText">
          <textarea
            ref={devotionalTextRef}
            id="devotionalText"
            className={`textarea tall ${isReadOnly ? "readonly" : ""}`}
            value={form.devotionalText}
            disabled={isReadOnly}
            placeholder="말씀을 이해하고 묵상하도록 돕는 짧은 글을 입력하세요."
            onChange={(event) => updateField("devotionalText", event.target.value)}
          />
        </Field>

        <div className="form-grid">
          <Field label="묵상 질문" htmlFor="reflectionPrompt">
            <textarea
              ref={reflectionPromptRef}
              id="reflectionPrompt"
              className={`textarea ${isReadOnly ? "readonly" : ""}`}
              value={form.reflectionPrompt}
              disabled={isReadOnly}
              placeholder="예: 오늘 말씀에서 가장 마음에 남는 것은 무엇인가요?"
              onChange={(event) => updateField("reflectionPrompt", event.target.value)}
            />
          </Field>
          <Field label="적용 질문" htmlFor="applicationPrompt">
            <textarea
              ref={applicationPromptRef}
              id="applicationPrompt"
              className={`textarea ${isReadOnly ? "readonly" : ""}`}
              value={form.applicationPrompt}
              disabled={isReadOnly}
              placeholder="예: 오늘 내가 순종으로 실천할 작은 행동은 무엇인가요?"
              onChange={(event) => updateField("applicationPrompt", event.target.value)}
            />
          </Field>
        </div>

        <Field label="기도 질문" htmlFor="prayerPrompt">
          <textarea
            ref={prayerPromptRef}
            id="prayerPrompt"
            className={`textarea ${isReadOnly ? "readonly" : ""}`}
            value={form.prayerPrompt}
            disabled={isReadOnly}
            placeholder="예: 말씀대로 살아가도록 짧게 기도해보세요."
            onChange={(event) => updateField("prayerPrompt", event.target.value)}
          />
        </Field>

        <div className="editor-actions">
          {!isReadOnly ? (
            <button className="button primary" type="submit" disabled={isSaving}>
              {isSaving
                ? "저장 중"
                : isProtectedInitialStatus
                  ? "변경사항 저장"
                  : "저장"}
            </button>
          ) : null}
          {!isLifecycleReadOnly ? (
            <button
              className="button secondary"
              type="button"
              disabled={isSaving}
              onClick={() => void save("published")}
            >
              Publish
            </button>
          ) : null}
          {mode === "edit" && !isLifecycleReadOnly ? (
            <button
              className="button secondary"
              type="button"
              disabled={isSaving}
              onClick={() => void save("archived")}
            >
              Archive
            </button>
          ) : null}
        </div>
      </section>

      <aside className="preview-panel">
        <p className="eyebrow">{scope ? `${scope.communityName} Preview` : "Preview"}</p>
        <h2>{form.title || "QT 제목"}</h2>

        <div className="preview-section">
          <span>오늘의 말씀</span>
          <strong>{form.reference || "말씀 reference"}</strong>
          {form.verseLines.length ? (
            <div className="verse-line-list">
              {form.verseLines.map((verse) => (
                <p key={`preview-${form.reference}-${verse.verse}`}>
                  <span>{verse.verse}</span>
                  {verse.text}
                </p>
              ))}
            </div>
          ) : (
            <p>말씀을 선택하면 본문 미리보기가 표시됩니다.</p>
          )}
        </div>

        <div className="preview-section">
          <span>말씀을 묵상해요</span>
          <p>{form.devotionalText || "묵상 글을 입력하세요."}</p>
          <strong>{form.reflectionPrompt || "묵상 질문"}</strong>
        </div>

        <div className="preview-section">
          <span>오늘 나에게</span>
          <strong>{form.applicationPrompt || "적용 질문"}</strong>
        </div>

        <div className="preview-section">
          <span>기도로 마무리해요</span>
          <strong>{form.prayerPrompt || "기도 안내"}</strong>
        </div>
      </aside>
    </form>
    <FormDialog
      open={dialog !== null}
      title={dialog?.title ?? ""}
      message={dialog?.message ?? ""}
      tone={dialog?.tone ?? "error"}
      actions={dialog?.actions}
      onClose={closeDialog}
    />
    </>
  );

  function updateField(field: keyof DailyQuietTimeFormState, value: string) {
    setForm((current) => ({
      ...current,
      [field]: value
    }));
  }

  function showValidationDialog(message: string) {
    setNotice(null);
    setDialog({
      title: "입력 내용을 확인해주세요",
      message,
      focusTarget: focusTargetForMessage(message)
    });
  }

  function showSaveErrorDialog(message: string) {
    const isDuplicate = message.includes("이미 존재");
    const isPermissionDenied = message.includes("관리자 권한");
    setDialog({
      title: isPermissionDenied ? "권한을 확인해주세요" : "QT를 저장할 수 없습니다",
      message: isPermissionDenied
        ? "관리자 권한이 없어 요청을 완료하지 못했습니다."
        : message,
      focusTarget: isDuplicate ? "dateKey" : undefined
    });
  }

  function showStatusConfirmation(statusOverride: "published" | "archived") {
    const isPublish = statusOverride === "published";
    setDialog({
      title: isPublish ? "QT를 게시할까요?" : "QT를 보관할까요?",
      message: isPublish
        ? "게시하면 오늘의 QT가 VerseGarden 사용자에게 공개됩니다."
        : "보관하면 이 QT는 더 이상 사용자에게 공개되지 않습니다.\n기존 사용자 QT 기록은 유지됩니다.",
      tone: "default",
      actions: [
        {
          label: "취소",
          variant: "secondary",
          disabled: isSaving,
          onClick: () => setDialog(null)
        },
        {
          label: isPublish ? "게시하기" : "보관하기",
          variant: isPublish ? "primary" : "destructive",
          disabled: isSaving,
          onClick: () => {
            setDialog(null);
            void saveStatusChange(statusOverride);
          }
        }
      ]
    });
  }

  function showSuccessDialog(title: string, message: string) {
    setNotice(null);
    setDialog({
      title,
      message,
      tone: "default",
      actions: [
        {
          label: "QT 목록으로",
          variant: "primary",
          onClick: () => {
            setDialog(null);
            router.push(scope ? `/admin/community/${scope.communityId}/qt` : "/admin/qt");
            router.refresh();
          }
        }
      ]
    });
  }

  function cancelProtectedEdit() {
    if (!isDirty) {
      resetProtectedEdit();
      return;
    }

    setDialog({
      title: "수정을 취소할까요?",
      message: "저장하지 않은 변경사항이 사라집니다.",
      tone: "default",
      actions: [
        {
          label: "계속 수정",
          variant: "secondary",
          onClick: () => setDialog(null)
        },
        {
          label: "수정 취소",
          variant: "destructive",
          onClick: () => {
            setDialog(null);
            resetProtectedEdit();
          }
        }
      ]
    });
  }

  function resetProtectedEdit() {
    setForm(baselineForm);
    setIsEditModeEnabled(false);
    setNotice(null);
  }

  function closeDialog() {
    const focusTarget = dialog?.focusTarget;
    setDialog(null);
    window.requestAnimationFrame(() => focusInvalidField(focusTarget));
  }

  function focusInvalidField(target?: FocusTarget) {
    if (!target) return;

    if (target === "bible") {
      bibleSectionRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
      const searchInput = bibleSectionRef.current?.querySelector<HTMLInputElement>("#bible-search");
      searchInput?.focus();
      return;
    }

    const targetRef = refForTarget(target);
    targetRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
    targetRef.current?.focus();
  }

  function refForTarget(
    target: Exclude<FocusTarget, "bible">
  ): RefObject<HTMLInputElement | HTMLTextAreaElement | null> {
    switch (target) {
      case "dateKey":
        return dateKeyRef;
      case "title":
        return titleRef;
      case "devotionalText":
        return devotionalTextRef;
      case "reflectionPrompt":
        return reflectionPromptRef;
      case "applicationPrompt":
        return applicationPromptRef;
      case "prayerPrompt":
        return prayerPromptRef;
    }
  }

  function focusTargetForMessage(message: string): FocusTarget | undefined {
    if (message.includes("날짜")) return "dateKey";
    if (message.includes("제목")) return "title";
    if (message.includes("성경 본문") || message.includes("본문 범위")) return "bible";
    if (message.includes("묵상 글")) return "devotionalText";
    if (message.includes("묵상 질문")) return "reflectionPrompt";
    if (message.includes("적용 질문")) return "applicationPrompt";
    if (message.includes("기도")) return "prayerPrompt";
    return undefined;
  }

  function validationErrorsForStatus(statusOverride?: "published" | "archived") {
    if (statusOverride === "published" || statusOverride === "archived") {
      return publishErrors;
    }
    return saveErrors;
  }
}

function formSignature(form: DailyQuietTimeFormState): string {
  return JSON.stringify({
    title: form.title.trim(),
    verseId: form.verseId,
    startVerseId: form.startVerseId,
    endVerseId: form.endVerseId,
    reference: form.reference.trim(),
    devotionalText: form.devotionalText.trim(),
    reflectionPrompt: form.reflectionPrompt.trim(),
    applicationPrompt: form.applicationPrompt.trim(),
    prayerPrompt: form.prayerPrompt.trim(),
    questions: form.questions
  });
}

function statusDescription(status: DailyQuietTime["status"]) {
  switch (status) {
    case "published":
      return "현재 사용자에게 공개 중인 QT입니다.";
    case "archived":
      return "보관된 QT입니다. 수정하려면 먼저 수정 모드로 전환하세요.";
    case "draft":
      return "아직 공개되지 않은 Draft입니다.";
  }
}

function Field({
  label,
  htmlFor,
  children
}: {
  label: string;
  htmlFor: string;
  children: React.ReactNode;
}) {
  return (
    <div className="field-block">
      <label htmlFor={htmlFor}>{label}</label>
      {children}
    </div>
  );
}
