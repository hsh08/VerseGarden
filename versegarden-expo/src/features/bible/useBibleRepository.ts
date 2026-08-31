import { useEffect, useState } from "react";

import { loadBibleRepository, type BibleRepository } from "./bibleRepository";

type BibleRepositoryState = {
  repository: BibleRepository | null;
  error: boolean;
};

export function useBibleRepository(): BibleRepositoryState {
  const [state, setState] = useState<BibleRepositoryState>({ repository: null, error: false });

  useEffect(() => {
    let active = true;
    void loadBibleRepository().then(
      (repository) => { if (active) setState({ repository, error: false }); },
      () => { if (active) setState({ repository: null, error: true }); },
    );
    return () => { active = false; };
  }, []);

  return state;
}
