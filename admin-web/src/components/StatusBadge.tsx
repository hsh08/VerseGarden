import type { DailyQuietTimeStatus } from "@/types/dailyQuietTime";

export function StatusBadge({ status }: { status: DailyQuietTimeStatus }) {
  return <span className={`status-badge ${status}`}>{statusLabel(status)}</span>;
}

export function statusLabel(status: DailyQuietTimeStatus) {
  switch (status) {
    case "draft":
      return "Draft";
    case "published":
      return "Published";
    case "archived":
      return "Archived";
  }
}
