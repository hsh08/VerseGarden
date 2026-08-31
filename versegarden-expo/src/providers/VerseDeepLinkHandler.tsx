import { useEffect, useRef } from "react";
import * as Linking from "expo-linking";
import { useRouter } from "expo-router";

import { useAuthSession } from "./AuthSessionProvider";

function targetFromURL(url: string | null): { type: "verse" | "write"; verseID: string } | null {
  if (!url) return null;
  const parsed = Linking.parse(url);
  if (parsed.scheme !== "versegarden" || (parsed.hostname !== "verse" && parsed.hostname !== "write")) return null;
  const value = parsed.path?.replace(/^\/+|\/+$/g, "");
  if (!value) return null;
  try {
    return { type: parsed.hostname, verseID: decodeURIComponent(value) };
  } catch {
    return null;
  }
}

export function VerseDeepLinkHandler() {
  const url = Linking.useURL();
  const router = useRouter();
  const { phase } = useAuthSession();
  const pendingTarget = useRef<{ type: "verse" | "write"; verseID: string } | null>(null);

  useEffect(() => {
    const target = targetFromURL(url);
    if (target) pendingTarget.current = target;
  }, [url]);

  useEffect(() => {
    if (phase !== "ready" || !pendingTarget.current) return;
    const target = pendingTarget.current;
    pendingTarget.current = null;
    router.push({ pathname: target.type === "verse" ? "/verse/[verseId]" : "/write/[verseId]", params: { verseId: target.verseID } });
  }, [phase, router]);

  return null;
}
