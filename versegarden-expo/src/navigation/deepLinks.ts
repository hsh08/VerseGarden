export const deepLinkRoutes = {
  verse: (verseId: string) => `/verse/${verseId}`,
  write: (verseId: string) => `/write/${verseId}`,
  todayVerse: "/verse/today",
  favoriteVerse: "/verse/favorite",
  profile: "/profile",
} as const;
