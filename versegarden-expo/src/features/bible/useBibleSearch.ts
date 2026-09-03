import { useEffect, useRef, useState } from "react";

import type { BibleRepository } from "./bibleRepository";
import type { BibleSearchResult } from "./bibleTypes";

const emptyResult: BibleSearchResult = { verses: [], hasMoreResults: false };
const debounceMilliseconds = 250;

export function useBibleSearch(repository: BibleRepository | null, query: string, limit: number): BibleSearchResult & { isSearching: boolean } {
  const [state, setState] = useState({ query: "", result: emptyResult, isSearching: false });
  const requestID = useRef(0);
  const hasLoggedFirstSearch = useRef(false);
  const queryValue = query.trim();
  const hasActiveQuery = Boolean(queryValue && repository);

  useEffect(() => {
    requestID.current += 1;
    const currentRequestID = requestID.current;
    if (!queryValue || !repository) return undefined;

    const startSearchState = setTimeout(() => {
      if (requestID.current === currentRequestID) setState({ query: queryValue, result: emptyResult, isSearching: true });
    }, 0);
    let scheduled: ReturnType<typeof setTimeout> | undefined;
    const timeout = setTimeout(() => {
      scheduled = setTimeout(() => {
        const searchStartedAt = Date.now();
        const isFirstSearch = !hasLoggedFirstSearch.current;
        if (__DEV__ && isFirstSearch) console.info("[Search Cold] query received", { queryLength: queryValue.length });
        void repository.search(queryValue, limit).then((nextResult) => {
          if (requestID.current !== currentRequestID) return;
          hasLoggedFirstSearch.current = true;
          if (__DEV__ && isFirstSearch) console.info("[Search Cold] first results rendered", { elapsedMilliseconds: Date.now() - searchStartedAt, resultCount: nextResult.verses.length });
          setState({ query: queryValue, result: nextResult, isSearching: false });
        }, () => {
          if (requestID.current !== currentRequestID) return;
          setState({ query: queryValue, result: emptyResult, isSearching: false });
        });
      }, 0);
    }, debounceMilliseconds);

    return () => {
      clearTimeout(startSearchState);
      clearTimeout(timeout);
      if (scheduled) clearTimeout(scheduled);
    };
  }, [limit, queryValue, repository]);

  if (!hasActiveQuery || state.query !== queryValue) return { ...emptyResult, isSearching: hasActiveQuery };
  return { ...state.result, isSearching: state.isSearching };
}
