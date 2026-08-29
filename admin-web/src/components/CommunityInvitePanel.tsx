"use client";

import { useCallback, useMemo, useState } from "react";
import { CommunityStatusBadge } from "@/components/CommunityStatusBadge";
import { FormDialog } from "@/components/FormDialog";
import { useGlobalLoading } from "@/components/GlobalLoadingProvider";
import {
  createCommunityInvite,
  regenerateCommunityInvite,
  revokeCommunityInvite
} from "@/lib/communityInvites";
import { formatDateTime } from "@/lib/date";
import type {
  Community,
  CommunityInviteSummary,
  GeneratedCommunityInvite
} from "@/types/community";

type Confirmation = { kind: "revoke" | "regenerate"; inviteId: string } | null;

type Props = {
  community: Community;
  initialInvites: CommunityInviteSummary[];
  reloadInvites: () => Promise<CommunityInviteSummary[]>;
};

export function CommunityInvitePanel({ community, initialInvites, reloadInvites }: Props) {
  const { withGlobalLoading } = useGlobalLoading();
  const [invites, setInvites] = useState(initialInvites);
  const [generated, setGenerated] = useState<GeneratedCommunityInvite | null>(null);
  const [copyError, setCopyError] = useState<string | null>(null);
  const [confirmation, setConfirmation] = useState<Confirmation>(null);
  const [isMutating, setIsMutating] = useState(false);
  const [dialog, setDialog] = useState<{ title: string; message: string; tone?: "error" } | null>(null);

  const activeInvite = useMemo(
    () => invites.find((invite) => invite.status === "active") ?? null,
    [invites]
  );
  const canCreate = community.status === "active" && community.inviteEnabled !== false;

  const refresh = useCallback(async () => {
    setInvites(await reloadInvites());
  }, [reloadInvites]);

  async function handleCreate() {
    setIsMutating(true);
    try {
      await withGlobalLoading(async () => {
        const result = await createCommunityInvite(community.id);
        setCopyError(null);
        setGenerated(result);
        await refresh();
      }, "초대 링크를 생성하는 중...");
    } catch (error) {
      setDialog({
        title: "초대 코드를 만들 수 없습니다",
        message: error instanceof Error ? error.message : "초대 요청을 처리하지 못했습니다.",
        tone: "error"
      });
    } finally {
      setIsMutating(false);
    }
  }

  async function handleConfirmedAction() {
    if (!confirmation) return;
    const action = confirmation;
    setConfirmation(null);
    setIsMutating(true);
    try {
      await withGlobalLoading(async () => {
        if (action.kind === "revoke") {
          await revokeCommunityInvite(action.inviteId);
          await refresh();
          setDialog({ title: "초대가 폐기되었습니다", message: "이 코드는 더 이상 사용할 수 없습니다." });
        } else {
          const result = await regenerateCommunityInvite(action.inviteId);
          setCopyError(null);
          setGenerated(result);
          await refresh();
        }
      }, action.kind === "revoke" ? "초대를 취소하는 중..." : "초대 링크를 다시 만드는 중...");
    } catch (error) {
      setDialog({
        title: "초대 요청을 처리할 수 없습니다",
        message: error instanceof Error ? error.message : "초대 요청을 처리하지 못했습니다.",
        tone: "error"
      });
    } finally {
      setIsMutating(false);
    }
  }

  async function copyGeneratedCode() {
    if (!generated) return;
    try {
      await navigator.clipboard.writeText(generated.code);
      setDialog({ title: "초대 코드를 복사했습니다", message: "안전한 방법으로 초대할 분에게 전달해주세요." });
      setGenerated(null);
    } catch {
      setCopyError("자동 복사에 실패했습니다. 위 코드를 직접 선택해 복사해주세요.");
    }
  }

  return (
    <div className="page-stack compact-stack">
      <div className="section-heading compact-heading">
        <div>
          <h2>초대 관리</h2>
          <p className="muted">초대 코드는 생성 직후 한 번만 확인할 수 있습니다.</p>
        </div>
        {!activeInvite ? (
          <button
            className="button primary"
            type="button"
            disabled={!canCreate || isMutating}
            onClick={() => void handleCreate()}
          >
            {isMutating ? "생성 중..." : "초대 코드 생성"}
          </button>
        ) : null}
      </div>

      {!canCreate ? (
        <div className="status-note">
          <p>활성 상태이며 초대가 허용된 공동체에서만 새 초대 코드를 만들 수 있습니다.</p>
        </div>
      ) : null}

      {activeInvite ? (
        <div className="invite-current-card">
          <div>
            <span className="small muted">현재 활성 초대</span>
            <CommunityStatusBadge status={activeInvite.status} />
          </div>
          <div className="invite-actions">
            <button
              className="button secondary"
              type="button"
              disabled={isMutating || !canCreate}
              onClick={() => setConfirmation({ kind: "regenerate", inviteId: activeInvite.id })}
            >
              재생성
            </button>
            <button
              className="button destructive"
              type="button"
              disabled={isMutating}
              onClick={() => setConfirmation({ kind: "revoke", inviteId: activeInvite.id })}
            >
              폐기
            </button>
          </div>
        </div>
      ) : (
        <div className="empty-state">활성화된 초대 코드가 없습니다.</div>
      )}

      {invites.length ? (
        <div className="table-card flat-card">
          <table>
            <thead>
              <tr>
                <th>Status</th>
                <th>Label</th>
                <th>Created At</th>
                <th>Expires At</th>
                <th>Uses</th>
                <th>Last Used</th>
              </tr>
            </thead>
            <tbody>
              {invites.map((invite) => (
                <tr key={invite.id}>
                  <td><CommunityStatusBadge status={invite.status} /></td>
                  <td>{invite.label || "—"}</td>
                  <td>{formatDateTime(invite.createdAt)}</td>
                  <td>{formatDateTime(invite.expiresAt)}</td>
                  <td>{invite.maxUses ? `${invite.useCount} / ${invite.maxUses}` : invite.useCount}</td>
                  <td>{formatDateTime(invite.lastUsedAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : null}

      <FormDialog
        open={Boolean(generated)}
        title="초대 코드가 생성되었습니다"
        message={generated ? `${generated.code}\n\n이 코드는 지금만 확인할 수 있습니다.${copyError ? `\n\n${copyError}` : ""}` : ""}
        onClose={() => {
          setGenerated(null);
          setCopyError(null);
        }}
        actions={[
          {
            label: "닫기",
            variant: "secondary",
            onClick: () => {
              setGenerated(null);
              setCopyError(null);
            }
          },
          { label: "복사", variant: "primary", onClick: () => void copyGeneratedCode() }
        ]}
      />

      <FormDialog
        open={Boolean(confirmation)}
        title={confirmation?.kind === "revoke" ? "초대를 폐기할까요?" : "새 초대 코드로 바꿀까요?"}
        message={
          confirmation?.kind === "revoke"
            ? "폐기하면 현재 초대 코드는 더 이상 사용할 수 없습니다."
            : "기존 코드는 즉시 폐기되고 새 코드가 한 번만 표시됩니다."
        }
        onClose={() => setConfirmation(null)}
        actions={[
          { label: "취소", variant: "secondary", onClick: () => setConfirmation(null) },
          {
            label: confirmation?.kind === "revoke" ? "폐기하기" : "재생성하기",
            variant: confirmation?.kind === "revoke" ? "destructive" : "primary",
            disabled: isMutating,
            onClick: () => void handleConfirmedAction()
          }
        ]}
      />

      <FormDialog
        open={Boolean(dialog)}
        title={dialog?.title ?? ""}
        message={dialog?.message ?? ""}
        tone={dialog?.tone ?? "default"}
        onClose={() => setDialog(null)}
      />
    </div>
  );
}
