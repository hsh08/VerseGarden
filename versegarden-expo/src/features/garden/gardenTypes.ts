export type GardenActivityType = "verseRead" | "verseLiked" | "scriptureCopy" | "prayer" | "qtCompleted";

export type GardenActivity = {
  id: string;
  type: GardenActivityType;
  title: string;
  verseId?: string;
  reference?: string;
  sourceId?: string;
  createdAt: Date;
};

export type GardenDaySummary = {
  dateKey: string;
  verseLikedCount: number;
  scriptureCopyCount: number;
  prayerCount: number;
  qtCompletedCount: number;
  totalGrowthActivityCount: number;
  hasGrowthActivity: boolean;
};

export type GardenStats = {
  currentStreak: number;
  totalGrowthActivityCount: number;
  today: GardenDaySummary;
  summariesByDateKey: Readonly<Record<string, GardenDaySummary>>;
  recentActivities: readonly GardenActivity[];
};

export const gardenActivityLabels: Record<GardenActivityType, string> = {
  verseRead: "말씀 읽음",
  verseLiked: "말씀 저장",
  scriptureCopy: "필사 완료",
  prayer: "기도 기록",
  qtCompleted: "QT 완료",
};

export function countsTowardGardenGrowth(type: GardenActivityType): boolean {
  return type !== "verseRead";
}
