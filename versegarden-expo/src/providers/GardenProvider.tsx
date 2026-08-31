import type { PropsWithChildren } from "react";
import { createContext, useContext, useMemo } from "react";

import { gardenActivitiesFromSources, summarizeGardenActivities } from "@/features/garden/gardenLogic";
import type { GardenActivity, GardenStats } from "@/features/garden/gardenTypes";

import { useAuthSession } from "./AuthSessionProvider";
import { usePersonalVerse } from "./PersonalVerseProvider";
import { useQuietPrayer } from "./QuietPrayerProvider";

type GardenContextValue = {
  activities: readonly GardenActivity[];
  stats: GardenStats;
};

const emptyStats: GardenStats = { currentStreak: 0, totalGrowthActivityCount: 0, today: { dateKey: "", verseLikedCount: 0, scriptureCopyCount: 0, prayerCount: 0, qtCompletedCount: 0, totalGrowthActivityCount: 0, hasGrowthActivity: false }, summariesByDateKey: {}, recentActivities: [] };
const GardenContext = createContext<GardenContextValue>({ activities: [], stats: emptyStats });

export function GardenProvider({ children }: PropsWithChildren) {
  const { phase, user } = useAuthSession();
  const { likes, records } = usePersonalVerse();
  const { prayerRecords, qtRecords } = useQuietPrayer();
  const value = useMemo<GardenContextValue>(() => {
    if (phase !== "ready" || !user) return { activities: [], stats: emptyStats };
    const activities = gardenActivitiesFromSources({ likes, writingRecords: records, prayerRecords, qtRecords });
    return { activities, stats: summarizeGardenActivities(activities) };
  }, [likes, phase, prayerRecords, qtRecords, records, user]);
  return <GardenContext.Provider value={value}>{children}</GardenContext.Provider>;
}

export function useGarden(): GardenContextValue {
  return useContext(GardenContext);
}
