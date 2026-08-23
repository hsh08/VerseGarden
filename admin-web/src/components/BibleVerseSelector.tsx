"use client";

import { useMemo, useState } from "react";
import {
  BibleVerse,
  getVerseRange,
  isValidSameChapterRange,
  referenceForRange,
  searchBibleVerses,
  versesInSameChapter
} from "@/lib/bible";

type Props = {
  selectedStartVerseId: string;
  selectedEndVerseId: string;
  selectedReference: string;
  selectedVerses: Array<{ verse: number; text: string }>;
  disabled?: boolean;
  onSelectRange: (range: {
    startVerseId: string;
    endVerseId: string;
    reference: string;
    verses: BibleVerse[];
  }) => void;
};

export function BibleVerseSelector({
  selectedStartVerseId,
  selectedEndVerseId,
  selectedReference,
  selectedVerses,
  disabled = false,
  onSelectRange
}: Props) {
  const [query, setQuery] = useState("");
  const results = useMemo(() => searchBibleVerses(query), [query]);
  const chapterVerses = useMemo(
    () => versesInSameChapter(selectedStartVerseId),
    [selectedStartVerseId]
  );

  const selectedRangeIsValid =
    selectedStartVerseId && selectedEndVerseId
      ? isValidSameChapterRange(selectedStartVerseId, selectedEndVerseId)
      : false;

  function selectStartVerse(verse: BibleVerse) {
    onSelectRange({
      startVerseId: verse.id,
      endVerseId: verse.id,
      reference: verse.referenceText,
      verses: [verse]
    });
    setQuery("");
  }

  function selectEndVerse(verse: BibleVerse) {
    const rangeVerses = getVerseRange(selectedStartVerseId, verse.id);
    onSelectRange({
      startVerseId: selectedStartVerseId,
      endVerseId: verse.id,
      reference: referenceForRange(selectedStartVerseId, verse.id),
      verses: rangeVerses
    });
  }

  return (
    <div className="field-block">
      <label htmlFor="bible-search">성경 본문 범위</label>
      <input
        id="bible-search"
        className="input"
        value={query}
        disabled={disabled}
        placeholder="예: 이사야 40:27, 로마서 8:31"
        onChange={(event) => setQuery(event.target.value)}
      />

      {selectedReference ? (
        <div className="selected-verse">
          <div className="selected-range-header">
            <span>선택된 본문</span>
            <strong>{selectedReference}</strong>
          </div>
          <div className="verse-line-list compact">
            {selectedVerses.map((verse) => (
              <p key={`${selectedReference}-${verse.verse}`}>
                <span>{verse.verse}</span>
                {verse.text}
              </p>
            ))}
          </div>
        </div>
      ) : (
        <div className="empty-inline">QT에 사용할 시작 절을 검색해서 선택하세요.</div>
      )}

      {selectedStartVerseId && chapterVerses.length ? (
        <div className="range-picker">
          <div>
            <p className="range-picker-title">끝 절 선택</p>
            <p className="muted small">
              같은 장 안에서만 범위를 선택합니다. 너무 긴 본문은 Preview에서 확인하세요.
            </p>
          </div>
          <div className="chapter-verse-grid">
            {chapterVerses.map((verse) => {
              const isStart = verse.id === selectedStartVerseId;
              const isEnd = verse.id === selectedEndVerseId;
              const isInvalidEndVerse = !isValidSameChapterRange(selectedStartVerseId, verse.id);
              return (
                <button
                  type="button"
                  key={verse.id}
                  className={`chapter-verse-button ${isStart ? "start" : ""} ${isEnd ? "end" : ""}`}
                  disabled={disabled || isInvalidEndVerse}
                  onClick={() => selectEndVerse(verse)}
                >
                  {verse.verse}
                </button>
              );
            })}
          </div>
          {!selectedRangeIsValid ? (
            <div className="alert error">시작 절보다 뒤에 있는 끝 절을 선택해주세요.</div>
          ) : null}
        </div>
      ) : null}

      {results.length > 0 ? (
        <div className="verse-results">
          {results.map((verse) => (
            <button
              type="button"
              key={verse.id}
              className="verse-result"
              disabled={disabled}
              onClick={() => selectStartVerse(verse)}
            >
              <span>{verse.referenceText}</span>
              <p>{verse.text}</p>
            </button>
          ))}
        </div>
      ) : query.trim() ? (
        <div className="empty-inline">검색 결과가 없습니다.</div>
      ) : null}
    </div>
  );
}
