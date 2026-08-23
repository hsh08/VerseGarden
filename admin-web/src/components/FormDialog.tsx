"use client";

import { useEffect, useRef } from "react";

export type DialogAction = {
  label: string;
  onClick: () => void;
  variant?: "primary" | "secondary" | "destructive";
  disabled?: boolean;
};

type Props = {
  open: boolean;
  title: string;
  message: string;
  tone?: "error" | "default";
  actions?: DialogAction[];
  onClose: () => void;
};

export function FormDialog({
  open,
  title,
  message,
  tone = "default",
  actions,
  onClose
}: Props) {
  const primaryActionRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (!open) return;

    primaryActionRef.current?.focus();

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        onClose();
      }
    }

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [open, onClose]);

  if (!open) return null;

  const resolvedActions =
    actions && actions.length
      ? actions
      : [
          {
            label: "확인",
            onClick: onClose,
            variant: "primary" as const
          }
        ];
  const hasPrimaryAction = resolvedActions.some((action) => action.variant === "primary");

  return (
    <div className="dialog-backdrop" role="presentation">
      <div
        className={`dialog-card ${tone}`}
        role="dialog"
        aria-modal="true"
        aria-labelledby="form-dialog-title"
        aria-describedby="form-dialog-message"
      >
        <div className="dialog-accent" aria-hidden="true" />
        <div className="dialog-copy">
          <h2 id="form-dialog-title">{title}</h2>
          <p id="form-dialog-message">{message}</p>
        </div>
        <div className="dialog-actions">
          {resolvedActions.map((action, index) => (
            <button
              key={action.label}
              ref={
                action.variant === "primary" ||
                (!hasPrimaryAction && index === resolvedActions.length - 1)
                  ? primaryActionRef
                  : undefined
              }
              className={`button ${action.variant ?? "secondary"}`}
              type="button"
              disabled={action.disabled}
              onClick={action.onClick}
            >
              {action.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
