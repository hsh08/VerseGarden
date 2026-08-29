import {
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  where
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import type {
  Community,
  CommunityFormValues,
  CommunityInviteSummary,
  CommunityMembership,
  CommunityStatus
} from "@/types/community";

const COMMUNITIES_COLLECTION = "communities";
const INVITES_COLLECTION = "communityInvites";

export async function listCommunities(): Promise<Community[]> {
  const snapshot = await getDocs(
    query(collection(db, COMMUNITIES_COLLECTION), orderBy("createdAt", "desc"))
  );
  return snapshot.docs.map((item) => ({
    id: item.id,
    ...item.data()
  })) as Community[];
}

export async function getCommunity(communityId: string): Promise<Community | null> {
  const snapshot = await getDoc(doc(db, COMMUNITIES_COLLECTION, communityId));
  if (!snapshot.exists()) return null;

  return { id: snapshot.id, ...snapshot.data() } as Community;
}

export async function createCommunity(
  values: CommunityFormValues,
  adminUid: string
): Promise<string> {
  const normalized = validateCommunityValues(values);
  const reference = await addDoc(collection(db, COMMUNITIES_COLLECTION), {
    ...normalized,
    status: "active" satisfies CommunityStatus,
    memberCount: 0,
    createdBy: adminUid,
    updatedBy: adminUid,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  });
  return reference.id;
}

export async function updateCommunityMetadata(
  communityId: string,
  values: CommunityFormValues,
  adminUid: string
): Promise<void> {
  const normalized = validateCommunityValues(values);
  await updateDoc(doc(db, COMMUNITIES_COLLECTION, communityId), {
    ...normalized,
    updatedBy: adminUid,
    updatedAt: serverTimestamp()
  });
}

export async function updateCommunityStatus(
  communityId: string,
  status: CommunityStatus,
  adminUid: string
): Promise<void> {
  await updateDoc(doc(db, COMMUNITIES_COLLECTION, communityId), {
    status,
    ...(status !== "active" ? { inviteEnabled: false } : {}),
    updatedBy: adminUid,
    updatedAt: serverTimestamp()
  });
}

export async function listCommunityMembers(
  communityId: string
): Promise<CommunityMembership[]> {
  const snapshot = await getDocs(
    query(
      collection(db, COMMUNITIES_COLLECTION, communityId, "members"),
      orderBy("joinedAt", "desc")
    )
  );
  return snapshot.docs.map((item) => item.data() as CommunityMembership);
}

export async function listCommunityInvites(
  communityId: string
): Promise<CommunityInviteSummary[]> {
  const snapshot = await getDocs(
    query(collection(db, INVITES_COLLECTION), where("communityId", "==", communityId))
  );
  return snapshot.docs
    .map((item) => ({ id: item.id, ...item.data() }) as CommunityInviteSummary)
    .sort((left, right) => right.createdAt.toMillis() - left.createdAt.toMillis());
}

function validateCommunityValues(values: CommunityFormValues): CommunityFormValues {
  const name = values.name.trim();
  const timezone = values.timezone.trim();
  if (!name) throw new Error("공동체 이름을 입력해주세요.");
  if (!timezone) throw new Error("시간대를 입력해주세요.");

  return {
    name,
    description: values.description.trim(),
    timezone,
    inviteEnabled: values.inviteEnabled
  };
}
