export type PrayerRecord = {
  id: string;
  localId: string;
  ownerUserId: string;
  templateLocalId?: string;
  templateRemoteId?: string;
  sourceType: "userPrayer" | "defaultPrayer" | "freeformPrayer";
  titleSnapshot: string;
  originalText: string;
  userText: string;
  date: Date;
  completedAt: Date;
  createdAt: Date;
  updatedAt: Date;
};
