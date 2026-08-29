"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState
} from "react";

const DISPLAY_DELAY_MS = 180;
const MINIMUM_VISIBLE_MS = 240;
const DEFAULT_MESSAGE = "처리 중...";

type GlobalLoadingContextValue = {
  withGlobalLoading: <T>(action: () => Promise<T>, message?: string) => Promise<T>;
};

const GlobalLoadingContext = createContext<GlobalLoadingContextValue | null>(null);

export function GlobalLoadingProvider({ children }: { children: React.ReactNode }) {
  const activeOperations = useRef(new Map<number, string>());
  const nextOperationId = useRef(0);
  const displayTimer = useRef<number | null>(null);
  const hideTimer = useRef<number | null>(null);
  const visibleSince = useRef<number | null>(null);
  const isVisibleRef = useRef(false);
  const [isVisible, setIsVisible] = useState(false);
  const [message, setMessage] = useState(DEFAULT_MESSAGE);

  const clearTimer = useCallback((timer: React.MutableRefObject<number | null>) => {
    if (timer.current !== null) {
      window.clearTimeout(timer.current);
      timer.current = null;
    }
  }, []);

  const latestMessage = useCallback(() => {
    const messages = Array.from(activeOperations.current.values());
    return messages.at(-1) ?? DEFAULT_MESSAGE;
  }, []);

  const beginLoading = useCallback((nextMessage = DEFAULT_MESSAGE) => {
    const operationId = ++nextOperationId.current;
    activeOperations.current.set(operationId, nextMessage);
    setMessage(nextMessage);
    clearTimer(hideTimer);

    if (!isVisibleRef.current && displayTimer.current === null) {
      displayTimer.current = window.setTimeout(() => {
        displayTimer.current = null;
        if (activeOperations.current.size > 0) {
          visibleSince.current = Date.now();
          setMessage(latestMessage());
          isVisibleRef.current = true;
          setIsVisible(true);
        }
      }, DISPLAY_DELAY_MS);
    }

    let hasFinished = false;
    return () => {
      if (hasFinished) return;
      hasFinished = true;
      activeOperations.current.delete(operationId);
      setMessage(latestMessage());

      if (activeOperations.current.size > 0) return;

      clearTimer(displayTimer);
      if (!isVisibleRef.current) return;

      const elapsed = visibleSince.current ? Date.now() - visibleSince.current : MINIMUM_VISIBLE_MS;
      const remaining = Math.max(0, MINIMUM_VISIBLE_MS - elapsed);
      hideTimer.current = window.setTimeout(() => {
        hideTimer.current = null;
        visibleSince.current = null;
        isVisibleRef.current = false;
        setIsVisible(false);
      }, remaining);
    };
  }, [clearTimer, latestMessage]);

  const withGlobalLoading = useCallback(async <T,>(action: () => Promise<T>, nextMessage?: string) => {
    const endLoading = beginLoading(nextMessage);
    try {
      return await action();
    } finally {
      endLoading();
    }
  }, [beginLoading]);

  useEffect(() => () => {
    clearTimer(displayTimer);
    clearTimer(hideTimer);
  }, [clearTimer]);

  const value = useMemo(() => ({ withGlobalLoading }), [withGlobalLoading]);
  const inertProps = isVisible ? { inert: true } : {};

  return (
    <GlobalLoadingContext.Provider value={value}>
      <div className="global-loading-content" aria-busy={isVisible} {...inertProps}>
        {children}
      </div>
      {isVisible ? <GlobalLoadingOverlay message={message} /> : null}
    </GlobalLoadingContext.Provider>
  );
}

export function useGlobalLoading() {
  const context = useContext(GlobalLoadingContext);
  if (!context) {
    throw new Error("useGlobalLoading must be used within GlobalLoadingProvider.");
  }
  return context;
}

function GlobalLoadingOverlay({ message }: { message: string }) {
  const overlayRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    overlayRef.current?.focus();
  }, []);

  return (
    <div
      ref={overlayRef}
      className="global-loading-overlay"
      role="status"
      aria-live="polite"
      aria-label={message}
      tabIndex={-1}
    >
      <div className="global-loading-indicator">
        <span className="global-loading-spinner" aria-hidden="true" />
        <span>{message}</span>
      </div>
    </div>
  );
}
