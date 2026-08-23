from __future__ import annotations

import json
import sqlite3
from pathlib import Path


BOOKS = {
    1: "창세기",
    2: "출애굽기",
    3: "레위기",
    4: "민수기",
    5: "신명기",
    6: "여호수아",
    7: "사사기",
    8: "룻기",
    9: "사무엘상",
    10: "사무엘하",
    11: "열왕기상",
    12: "열왕기하",
    13: "역대상",
    14: "역대하",
    15: "에스라",
    16: "느헤미야",
    17: "에스더",
    18: "욥기",
    19: "시편",
    20: "잠언",
    21: "전도서",
    22: "아가",
    23: "이사야",
    24: "예레미야",
    25: "예레미야애가",
    26: "에스겔",
    27: "다니엘",
    28: "호세아",
    29: "요엘",
    30: "아모스",
    31: "오바댜",
    32: "요나",
    33: "미가",
    34: "나훔",
    35: "하박국",
    36: "스바냐",
    37: "학개",
    38: "스가랴",
    39: "말라기",
    40: "마태복음",
    41: "마가복음",
    42: "누가복음",
    43: "요한복음",
    44: "사도행전",
    45: "로마서",
    46: "고린도전서",
    47: "고린도후서",
    48: "갈라디아서",
    49: "에베소서",
    50: "빌립보서",
    51: "골로새서",
    52: "데살로니가전서",
    53: "데살로니가후서",
    54: "디모데전서",
    55: "디모데후서",
    56: "디도서",
    57: "빌레몬서",
    58: "히브리서",
    59: "야고보서",
    60: "베드로전서",
    61: "베드로후서",
    62: "요한일서",
    63: "요한이서",
    64: "요한삼서",
    65: "유다서",
    66: "요한계시록",
}


def testament_for_book(book_number: int) -> str:
    return "old" if 1 <= book_number <= 39 else "new"


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    sqlite_path = Path("/Users/hansanghyeog/Desktop/Paul Avery HolyBible용/개역한글판_korHRV")
    output_path = repo_root / "VerseGarden" / "Data" / "bible_krv_full.json"

    connection = sqlite3.connect(sqlite_path)
    connection.row_factory = sqlite3.Row

    try:
        rows = connection.execute(
            """
            SELECT book, chapter, verse, content
            FROM bible
            WHERE chapter > 0
              AND verse > 0
              AND content IS NOT NULL
              AND TRIM(content) != ''
              AND TRIM(content) != '(없음)'
            ORDER BY book, chapter, verse
            """
        ).fetchall()
    finally:
        connection.close()

    verses = []
    for row in rows:
        book_number = int(row["book"])
        book_name = BOOKS.get(book_number)
        if book_name is None:
            continue

        verses.append(
            {
                "book": book_name,
                "chapter": int(row["chapter"]),
                "verse": int(row["verse"]),
                "testament": testament_for_book(book_number),
                "text": row["content"],
            }
        )

    output_path.write_text(
        json.dumps(verses, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"written_records={len(verses)}")

    samples = [
        ("창세기", 1, 1),
        ("시편", 23, 1),
        ("요한복음", 3, 16),
    ]
    for book, chapter, verse in samples:
        match = next(
            (
                item
                for item in verses
                if item["book"] == book
                and item["chapter"] == chapter
                and item["verse"] == verse
            ),
            None,
        )
        print(json.dumps(match, ensure_ascii=False))


if __name__ == "__main__":
    main()
