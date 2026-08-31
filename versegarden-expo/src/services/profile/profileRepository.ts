import type { User } from "firebase/auth";
import { doc, getDoc, serverTimestamp, setDoc } from "firebase/firestore";

import { dateFromFirestore, normalizedOptionalString, type UserProfile, type UserProfileDocument } from "@/features/profile/UserProfile";
import { getFirebaseServices } from "@/services/firebase";

function profileDocument(uid: string) {
  const services = getFirebaseServices();
  if (!services) throw new Error("Firebase configuration is unavailable.");
  return doc(services.firestore, "users", uid);
}

function decodeProfile(id: string, data: UserProfileDocument, user: User): UserProfile {
  const createdAt = dateFromFirestore(data.createdAt, new Date());
  return {
    id,
    email: typeof data.email === "string" ? data.email : user.email ?? "",
    nickname: typeof data.nickname === "string" ? data.nickname.trim() : "",
    onboardingCompleted: data.onboardingCompleted === true,
    favoriteVerse: typeof data.favoriteVerse === "string" ? data.favoriteVerse.trim() : "",
    favoriteVerseId: normalizedOptionalString(data.favoriteVerseId),
    selectedWritingPlanId: normalizedOptionalString(data.selectedWritingPlanId),
    selectedTopics: Array.isArray(data.selectedTopics) ? data.selectedTopics.filter((item): item is string => typeof item === "string") : [],
    createdAt,
    updatedAt: dateFromFirestore(data.updatedAt, createdAt),
  };
}

async function fetchExistingProfile(user: User): Promise<UserProfile | null> {
  const snapshot = await getDoc(profileDocument(user.uid));
  return snapshot.exists() ? decodeProfile(snapshot.id, snapshot.data() as UserProfileDocument, user) : null;
}

export const profileRepository = {
  async ensureProfile(user: User): Promise<UserProfile> {
    const existing = await fetchExistingProfile(user);
    if (existing) return existing;

    await setDoc(profileDocument(user.uid), {
      uid: user.uid,
      email: user.email ?? "",
      displayName: user.displayName ?? "",
      nickname: "",
      onboardingCompleted: false,
      favoriteVerse: "",
      favoriteVerseId: "",
      selectedWritingPlanId: "",
      selectedTopics: [],
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }, { merge: true });

    const created = await fetchExistingProfile(user);
    if (!created) throw new Error("Profile creation did not return a document.");
    return created;
  },

  async completeOnboarding(user: User, selectedTopics: string[]): Promise<UserProfile> {
    const topics = [...new Set(selectedTopics.map((topic) => topic.trim()).filter(Boolean))].sort();
    await setDoc(profileDocument(user.uid), {
      uid: user.uid,
      email: user.email ?? "",
      displayName: user.displayName ?? "",
      onboardingCompleted: true,
      favoriteVerse: "",
      selectedTopics: topics,
      updatedAt: serverTimestamp(),
    }, { merge: true });

    const profile = await fetchExistingProfile(user);
    if (!profile) throw new Error("Profile update did not return a document.");
    return profile;
  },

  async updateSelectedWritingPlanId(user: User, planId: string | null): Promise<UserProfile> {
    await setDoc(profileDocument(user.uid), {
      selectedWritingPlanId: planId?.trim() || "",
      updatedAt: serverTimestamp(),
    }, { merge: true });

    const profile = await fetchExistingProfile(user);
    if (!profile) throw new Error("Profile update did not return a document.");
    return profile;
  },
};
