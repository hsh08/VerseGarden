"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { CommunityForm } from "@/components/CommunityForm";
import { FormDialog } from "@/components/FormDialog";
import { useGlobalLoading } from "@/components/GlobalLoadingProvider";
import { createCommunity } from "@/lib/communities";
import { useAdminAuth } from "@/lib/auth";
import type { CommunityFormValues } from "@/types/community";

const initialValues: CommunityFormValues = {
  name: "",
  description: "",
  timezone: "Asia/Seoul",
  inviteEnabled: true
};

export default function NewCommunityPage() {
  const router = useRouter();
  const { user } = useAdminAuth();
  const { withGlobalLoading } = useGlobalLoading();
  const [values, setValues] = useState(initialValues);
  const [isSaving, setIsSaving] = useState(false);
  const [dialog, setDialog] = useState<{ title: string; message: string; communityId?: string } | null>(null);

  async function handleCreate() {
    if (!user) return;
    setIsSaving(true);
    try {
      await withGlobalLoading(async () => {
        const communityId = await createCommunity(values, user.uid);
        setDialog({
          title: "공동체가 생성되었습니다",
          message: "공동체 상세 화면에서 초대와 운영 상태를 관리할 수 있습니다.",
          communityId
        });
      }, "공동체를 생성하는 중...");
    } catch (error) {
      setDialog({
        title: "공동체를 생성할 수 없습니다",
        message: error instanceof Error ? error.message : "입력 내용을 확인해주세요."
      });
    } finally {
      setIsSaving(false);
    }
  }

  function closeDialog() {
    const communityId = dialog?.communityId;
    setDialog(null);
    if (communityId) router.push(`/admin/communities/${communityId}`);
  }

  return (
    <div className="page-stack community-editor-width">
      <div className="page-header">
        <div>
          <p className="eyebrow">Communities</p>
          <h1>새 공동체</h1>
          <p className="muted">공동체 이름과 기본 운영 정보를 입력합니다.</p>
        </div>
        <Link className="button secondary" href="/admin/communities">목록으로</Link>
      </div>

      <section className="editor-panel">
        <CommunityForm values={values} onChange={setValues} disabled={isSaving} />
        <div className="editor-actions">
          <Link className="button secondary" href="/admin/communities">취소</Link>
          <button
            className="button primary"
            type="button"
            disabled={isSaving}
            onClick={() => void handleCreate()}
          >
            {isSaving ? "생성 중..." : "공동체 생성"}
          </button>
        </div>
      </section>

      <FormDialog
        open={Boolean(dialog)}
        title={dialog?.title ?? ""}
        message={dialog?.message ?? ""}
        tone={dialog?.communityId ? "default" : "error"}
        onClose={closeDialog}
      />
    </div>
  );
}
